import os

import boto3
from botocore.config import Config


def endpoint_url():
    return os.environ.get("AWS_ENDPOINT_URL") or None


def aws_region():
    return (
        os.environ.get("AWS_REGION")
        or os.environ.get("AWS_DEFAULT_REGION")
        or "us-east-1"
    )


def make_client(service: str):
    return boto3.client(
        service,
        region_name=aws_region(),
        endpoint_url=endpoint_url(),
        config=Config(retries={"max_attempts": 3, "mode": "standard"}),
    )


def assume_role(role_arn: str, session_name: str) -> dict:
    sts = make_client("sts")
    resp = sts.assume_role(
        RoleArn=role_arn,
        RoleSessionName=session_name,
    )
    return resp["Credentials"]
