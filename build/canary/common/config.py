from common.aws import make_client
from common.logging import log


def load_ssm_config(prefix: str, required=None, context=None) -> dict:
    required = set(required or [])
    ssm = make_client("ssm")

    params: dict[str, str] = {}
    paginator = ssm.get_paginator("get_parameters_by_path")
    for page in paginator.paginate(Path=prefix, Recursive=True, WithDecryption=False):
        for p in page.get("Parameters", []):
            params[p["Name"].rsplit("/", 1)[-1]] = p["Value"]

    missing = required - params.keys()
    if missing:
        raise RuntimeError(f"missing SSM parameters under {prefix}: {sorted(missing)}")

    log(context, ssm_prefix=prefix, parameters_loaded=len(params))
    return params
