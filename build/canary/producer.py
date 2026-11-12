import json
import os
import uuid
from datetime import datetime, timezone

from common.aws import make_client
from common.config import load_ssm_config
from common.logging import log

SSM_PREFIX = os.environ["SSM_PREFIX"]

_CONFIG = None


def _config(context):
    global _CONFIG
    if _CONFIG is None:
        _CONFIG = load_ssm_config(SSM_PREFIX, required={"stream_name"}, context=context)
    return _CONFIG


def handler(event, context):
    cfg = _config(context)
    canary_id = str(uuid.uuid4())
    emitted_at = datetime.now(timezone.utc).isoformat()

    record = {
        "event_type": "canary",
        "canary_id": canary_id,
        "emitted_at": emitted_at,
        "partition_key": "canary",
        "payload": {"ping": "pong"},
    }
    make_client("kinesis").put_record(
        StreamName=cfg["stream_name"],
        PartitionKey="canary",
        Data=json.dumps(record).encode("utf-8"),
    )

    log(context, emitted=canary_id, emitted_at=emitted_at, stream=cfg["stream_name"])
    return {"canary_id": canary_id, "emitted_at": emitted_at}
