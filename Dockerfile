FROM       ubuntu:14.04
MAINTAINER AdobePlatform <qa-behance@adobe.com>

ENV     SHELL /bin/bash
WORKDIR "/data"

RUN apt-get install jq -y
RUN apt-get install curl python2.7 -y

ADD https://bootstrap.pypa.io/get-pip.py /get-pip.py
RUN sudo python2.7 /get-pip.py

RUN sudo pip install awscli

ADD download-decrypt-secrets /opt/ethos/download-decrypt-secrets

ENTRYPOINT ["/bin/bash", "/opt/ethos/download-decrypt-secrets"]
CMD []
