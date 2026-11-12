# Sample project on using Kinesis with Spark

Демонстрация прогона данных от Kinesis к Spark.

## Ключевые решения

### Canary-гейт

Перед публикацией Spark ищет событие `event_type = "canary"` с `emitted_at`
не старше `CANARY_LOOKBACK_MINUTES` (по умолчанию 10 мин). Нет — RuntimeError,
ничего не пишется. Защита от «тихого» устаревания данных: лучше не опубликовать,
чем опубликовать устаревшее.

### Идемпотентность silver-слоя

Firehose даёт at-least-once, джоба может ретраиться. Поэтому:

- дедупликация по бизнес-ключу `(partition_key, emitted_at)` перед записью;
- вставляем только новое, существующее не трогаем, файлы не перезаписываем;
- перезапуск джобы не меняет состояние silver'а.

### Наблюдаемость отказов

Неудачные записи Firehose не теряются молча: `errors/` - Lambda - метрика 
alarm - SNS - SQS. Отказ доставки виден оператору.

### Parquet как экспорт, а не второй источник правды

Parquet-слой пересобирается из Iceberg по затронутым dt. Это гарантирует,
что Iceberg и Parquet не разъезжаются: Parquet - снимок silver'а на момент
экспорта. Перезапуск джобы даёт тот же результат.

```mermaid
sequenceDiagram
    autonumber
    participant SRC as Producer<br/>(canary)
    participant STR as Kinesis<br/>(stream)
    participant DL as Firehose<br/>(delivery)
    participant LAK as S3<br/>(lake)
    participant RD as Spark<br/>(reader)
    participant PG as Postgres<br/>(catalog)
    participant TBL as Iceberg<br/>(table)
    participant CNT as error-counter<br/>(Lambda)
    participant CW as CloudWatch<br/>(metric + alarm)
    participant SNS as SNS<br/>(topic)
    participant SQS as SQS<br/>(queue)

    Note over SRC,STR: record in flight
    SRC->>STR: PutRecord(JSON, pk="canary")

    Note over STR,DL: buffered ~60s
    STR->>DL: record batch
    alt accepted
        DL->>LAK: PutObject events/YYYY/MM/DD/HH/…
    else rejected
        DL->>LAK: PutObject errors/…
        Note right of LAK: rejection is observable,<br/>not silent
        LAK->>CNT: S3 ObjectCreated (errors/)
        CNT->>CW: PutMetricData ErrorObjectCreated
        CW->>SNS: ALARM (>= 1 in period)
        SNS->>SQS: SendMessage (raw)
        Note right of SQS: operator/test reads<br/>receive-message
    end

    Note over RD,LAK: consumption
    RD->>LAK: list + GET events/
    LAK-->>RD: NDJSON lines
    RD->>RD: from_json + filter canary<br/>+ to_timestamp gate
    alt fresh canary present
        RD->>LAK: write curated/dt=…/part-*.parquet
        RD->>PG: read/write Iceberg catalog<br/>(db.table -> metadata path)
        RD->>LAK: write Iceberg data + metadata
        LAK-->>PG: (catalog points at s3a://…/warehouse/…)
        RD->>TBL: append (after DELETE dt)
        RD-->>SRC: exit 0
    else none
        RD-->>SRC: RuntimeError CANARY MISSING
    end
```

| Компонент | Роль |
|---|---|
| **Kinesis** | буфер входящих записей |
| **Firehose** | батчит ~60 с, пишет в `events/` или `errors/` |
| **Lambda `canary`** | EventBridge шлёт «живое» событие — маркер работоспособности |
| **Lambda `error-counter`** | реагирует на `S3 ObjectCreated` в `errors/`, публикует метрику |
| **CloudWatch, SNS, SQS** | алерт об отказах доходит до оператора |
| **Spark job** | читает `events/`, проверяет canary, пишет в Iceberg + Parquet |
| **Postgres** | JDBC-каталог Iceberg |
| **SSM / STS / KMS / IAM** | конфигурация, assume-role, шифрование, права |