import os
from datetime import datetime, timezone

from common.aws import make_client
from common.config import load_ssm_config
from common.logging import log

SSM_PREFIX = os.environ["SSM_PREFIX"]

_CONFIG = None


def _config(context):
    global _CONFIG
    if _CONFIG is None:
        _CONFIG = load_ssm_config(
            SSM_PREFIX,
            required={"metric_namespace", "error_metric_name"},
            context=context,
        )
    return _CONFIG


def handler(event, context):
    records = event.get("Records", [])
    if not records:
        log(context, skipped="no records", event_keys=list(event.keys()))
        return {"published": 0}

    cfg = _config(context)
    namespace = cfg["metric_namespace"]
    metric_name = cfg["error_metric_name"]
    count = len(records)

    make_client("cloudwatch").put_metric_data(
        Namespace=namespace,
        MetricData=[
            {
                "MetricName": metric_name,
                "Value": float(count),
                "Unit": "Count",
                "Timestamp": datetime.now(timezone.utc),
            }
        ],
    )

    keys = [r.get("s3", {}).get("object", {}).get("key", "") for r in records]
    log(context, published=count, metric=metric_name, namespace=namespace, keys=keys)
    return {"published": count}
