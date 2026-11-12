import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


def log(context=None, **fields):
    if context is not None:
        fields.setdefault("aws_request_id", getattr(context, "aws_request_id", None))
        fields.setdefault("function", getattr(context, "function_name", None))
    logger.info(json.dumps(fields, default=str))
