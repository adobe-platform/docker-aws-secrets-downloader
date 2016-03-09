FROM       alpine:3.3
MAINTAINER AdobePlatform <qa-behance@adobe.com>

ENV     SHELL /bin/bash
WORKDIR "/data"

RUN apk update && \
    apk add \
      bash \
      'python<3.0' \
      'py-pip<8.2.0' \
    && \
    rm -rf /var/cache/apk/*

RUN pip install awscli

ADD download-decrypt-secrets.sh /opt/ethos/download-decrypt-secrets

ENTRYPOINT ["/bin/bash", "/opt/ethos/download-decrypt-secrets"]
CMD []
