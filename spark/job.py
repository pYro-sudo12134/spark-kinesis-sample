import os
import sys
from datetime import datetime, timedelta, timezone

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

from common.aws import assume_role
from common.config import load_ssm_config
from common.logging import log

SSM_PREFIX = os.environ["SSM_PREFIX"]
ROLE_SESSION_NAME = os.environ.get("ROLE_SESSION_NAME", "spark-job")
CANARY_LOOKBACK_MINUTES = int(os.environ.get("CANARY_LOOKBACK_MINUTES", "10"))
CURATED_PREFIX_OVERRIDE = os.environ.get("CURATED_PREFIX_OVERRIDE", "")

ICEBERG_TABLE = "local.curated"

EMITTED_AT_FMT = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXX"

CURATED_SCHEMA_DDL = """
    event_type    STRING,
    canary_id     STRING,
    emitted_at    STRING,
    partition_key STRING,
    payload       STRUCT<ping: STRING>,
    dt            DATE
"""

DEDUP_KEY = ["partition_key", "emitted_at"]


def _spark_with_s3a(
    creds: dict, region: str, path_style: bool, iceberg_warehouse: str
) -> SparkSession:
    builder = (
        SparkSession.builder.appName("kinesis-firehose-spark")
        .config("spark.hadoop.fs.s3a.access.key", creds["AccessKeyId"])
        .config("spark.hadoop.fs.s3a.secret.key", creds["SecretAccessKey"])
        .config("spark.hadoop.fs.s3a.session.token", creds["SessionToken"])
        .config(
            "spark.hadoop.fs.s3a.aws.credentials.provider",
            "org.apache.hadoop.fs.s3a.TemporaryAWSCredentialsProvider",
        )
        .config("spark.hadoop.fs.s3a.analytics.accelerator.enabled", "false")
        .config("spark.hadoop.fs.s3a.endpoint.region", region)
        .config("spark.hadoop.fs.s3a.path.style.access", str(path_style).lower())
        .config("spark.hadoop.fs.s3a.connection.timeout", "30000")
        .config("spark.hadoop.fs.s3a.connection.establish.timeout", "30000")
        .config("spark.hadoop.fs.s3a.connection.request.timeout", "30000")
        .config("spark.hadoop.fs.s3a.threads.keepalive", "60000")
        .config("spark.hadoop.fs.s3a.retry.limit", "3")
        .config("spark.hadoop.fs.s3a.retry.interval", "1s")
        .config("spark.hadoop.fs.s3a.attempts.maximum", "3")
        .config("spark.sql.adaptive.enabled", "true")
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true")
        .config("spark.sql.shuffle.partitions", "1000")
        .config("spark.sql.adaptive.advisoryPartitionSizeInBytes", "64MB")
        .config("spark.sql.adaptive.coalescePartitions.minPartitionSize", "1MB")
        .config(
            "spark.sql.files.maxPartitionBytes",
            os.environ.get("SPARK_MAX_PARTITION_BYTES", str(128 * 1024 * 1024)),
        )
        .config("spark.driver.memory", os.environ.get("SPARK_DRIVER_MEMORY", "1g"))
        .config(
            "spark.sql.extensions",
            "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions",
        )
        .config("spark.sql.catalog.local", "org.apache.iceberg.spark.SparkCatalog")
        .config("spark.sql.catalog.local.type", "jdbc")
        .config(
            "spark.sql.catalog.local.uri", "jdbc:postgresql://postgres:5432/iceberg"
        )
        .config("spark.sql.catalog.local.jdbc.user", "iceberg")
        .config("spark.sql.catalog.local.jdbc.password", "iceberg")
        .config("spark.sql.catalog.local.warehouse", iceberg_warehouse)
        .config("spark.sql.catalog.local.jdbc.schema-version", "V1")
    )

    endpoint = os.environ.get("AWS_ENDPOINT_URL")
    if endpoint:
        builder = builder.config("spark.hadoop.fs.s3a.endpoint", endpoint)
    return builder.getOrCreate()


def _assert_canary_fresh(df, cutoff: datetime) -> str:
    emitted_ts = F.to_timestamp("emitted_at", EMITTED_AT_FMT)
    cutoff_ts = F.to_timestamp(F.lit(cutoff.isoformat()), EMITTED_AT_FMT)

    recent = df.filter(F.col("event_type") == "canary").filter(
        emitted_ts.isNotNull() & (emitted_ts >= cutoff_ts)
    )

    row = recent.agg(
        F.count(F.lit(1)).alias("n"),
        F.max("emitted_at").alias("latest"),
    ).collect()[0]

    if row["n"] == 0:
        raise RuntimeError(
            f"CANARY MISSING: no canary with emitted_at >= {cutoff.isoformat()} "
            f"(lookback {CANARY_LOOKBACK_MINUTES} min). Refusing to publish."
        )
    return str(row["latest"])


def _ensure_iceberg_table(spark: SparkSession) -> None:
    log(None, phase="iceberg_create_if_not_exists", table=ICEBERG_TABLE)
    spark.sql(f"""
        CREATE TABLE IF NOT EXISTS {ICEBERG_TABLE} (
            {CURATED_SCHEMA_DDL}
        )
        USING iceberg
        PARTITIONED BY (dt)
    """)


def _merge_insert_only(spark: SparkSession, updates_view: str) -> None:
    spark.sql(f"""
        MERGE INTO {ICEBERG_TABLE} t
        USING {updates_view} s
        ON  t.partition_key = s.partition_key
        AND t.emitted_at    = s.emitted_at
        AND t.dt            = s.dt
        WHEN NOT MATCHED THEN INSERT *
    """)


def _export_to_parquet(spark: SparkSession, curated_path: str, touched_dts) -> None:
    if not touched_dts:
        log(None, phase="export_parquet_skip", reason="no touched dt")
        return

    log(None, phase="export_parquet", path=curated_path, dts=list(touched_dts))

    silver = spark.read.table(ICEBERG_TABLE).where(F.col("dt").isin(*touched_dts))
    silver.write.mode("overwrite").partitionBy("dt").parquet(curated_path)

    log(None, phase="export_parquet_done", path=curated_path)


def main() -> int:
    cfg = load_ssm_config(
        SSM_PREFIX,
        required={
            "bucket_name",
            "events_prefix",
            "error_prefix",
            "curated_prefix",
            "spark_role_arn",
            "region",
            "iceberg_warehouse",
        },
        context=None,
    )

    creds = assume_role(cfg["spark_role_arn"], ROLE_SESSION_NAME)
    log(
        None,
        phase="assume_role",
        role_arn=cfg["spark_role_arn"],
        session_name=ROLE_SESSION_NAME,
        expiration=str(creds.get("Expiration")),
    )

    path_style = os.environ.get("SPARK_S3A_PATH_STYLE", "true").lower() == "true"
    spark = _spark_with_s3a(creds, cfg["region"], path_style, cfg["iceberg_warehouse"])

    try:
        bucket = cfg["bucket_name"]
        events_path = f"s3a://{bucket}/{cfg['events_prefix']}"
        curated_prefix = CURATED_PREFIX_OVERRIDE or cfg["curated_prefix"]
        curated_path = f"s3a://{bucket}/{curated_prefix}"

        log(None, phase="read", path=events_path)
        raw = spark.read.option("recursiveFileLookup", "true").text(events_path)

        records = (
            raw.filter(F.col("value").isNotNull() & (F.length("value") > 0))
            .select(
                F.from_json(
                    "value",
                    "event_type string, canary_id string, emitted_at string, "
                    "partition_key string, payload struct<ping:string>",
                ).alias("r")
            )
            .select("r.*")
            .filter(F.col("event_type").isNotNull())
            .cache()
        )

        cutoff = datetime.now(timezone.utc) - timedelta(minutes=CANARY_LOOKBACK_MINUTES)
        latest = _assert_canary_fresh(records, cutoff)
        log(
            None,
            phase="canary_check",
            latest_emitted_at=latest,
            cutoff=cutoff.isoformat(),
        )

        curated = (
            records.filter(F.col("event_type") != "canary")
            .filter(
                F.col("partition_key").isNotNull() & F.col("emitted_at").isNotNull()
            )
            .withColumn("dt", F.to_date(F.to_timestamp("emitted_at", EMITTED_AT_FMT)))
            .filter(F.col("dt").isNotNull())
            .dropDuplicates(DEDUP_KEY)
            .cache()
        )

        n_curated = curated.count()
        log(None, phase="curated_materialized", rows=n_curated)

        if n_curated == 0:
            log(None, phase="noop", reason="no non-canary events in batch")
            curated.unpersist()
            records.unpersist()
            return 0

        _ensure_iceberg_table(spark)

        curated.createOrReplaceTempView("curated_updates")
        log(None, phase="merge_into_iceberg", table=ICEBERG_TABLE)
        _merge_insert_only(spark, "curated_updates")
        log(None, phase="merge_into_iceberg_done", table=ICEBERG_TABLE)

        touched_dts = [
            r["dt"] for r in curated.select("dt").distinct().collect() if r["dt"]
        ]
        _export_to_parquet(spark, curated_path, touched_dts)

        curated.unpersist()
        records.unpersist()

        log(
            None,
            phase="done",
            parquet_path=curated_path,
            iceberg_table=ICEBERG_TABLE,
            rows=n_curated,
            touched_dts=touched_dts,
        )
        return 0
    finally:
        spark.stop()


if __name__ == "__main__":
    sys.exit(main())
