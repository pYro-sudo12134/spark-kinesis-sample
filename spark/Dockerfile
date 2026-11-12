FROM apache/spark:${SPARK_VERSION:-3.5.9-scala2.12-java17-python3-ubuntu}

USER root
ARG BOTO3_VERSION=1.34.0
RUN pip install --no-cache-dir "boto3==${BOTO3_VERSION}"

ENV HOME=/tmp
ENV SPARK_SUBMIT_OPTS="-Divy.cache.dir=/tmp/.ivy2 -Divy.home=/tmp/.ivy2"

USER 185