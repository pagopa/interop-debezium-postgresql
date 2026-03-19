FROM quay.io/debezium/connect:3.4.2.Final@sha256:4949028f3797c35b4ea3b8bbe7960811ca7597ddf27a0b3f2d8d3d33106d09e5

USER root

WORKDIR /kafka/connect
RUN find . -mindepth 1 -maxdepth 1 ! -name 'debezium-connector-postgres' -type d -exec rm -r {} \;

WORKDIR /usr/local/bin
RUN curl -LO https://github.com/jqlang/jq/releases/download/jq-1.8.1/jq-linux-amd64 \
 && curl -sL https://github.com/jqlang/jq/releases/download/jq-1.8.1/sha256sum.txt \
    | grep jq-linux-amd64 | sha256sum -c -
RUN mv jq-linux-amd64 jq && chmod +x jq

WORKDIR /kafka/libs
RUN curl -LO https://github.com/aws/aws-msk-iam-auth/releases/download/v2.3.5/aws-msk-iam-auth-2.3.5-all.jar \
 && curl -sL https://github.com/aws/aws-msk-iam-auth/releases/download/v2.3.5/aws-msk-iam-auth-2.3.5-all.jar.sha256 \
    | sed 's/$/  aws-msk-iam-auth-2.3.5-all.jar/' | sha256sum -c -
RUN chown kafka:kafka ./aws-msk-iam-auth-2.3.5-all.jar && chmod 444 ./aws-msk-iam-auth-2.3.5-all.jar

RUN curl -LO https://github.com/aws-samples/msk-config-providers/releases/download/r0.4.0/msk-config-providers-0.4.0-all.jar
RUN chown kafka:kafka ./msk-config-providers-0.4.0-all.jar && chmod 444 ./msk-config-providers-0.4.0-all.jar

WORKDIR /
COPY ./register-connector.sh .
RUN chown kafka:kafka ./register-connector.sh && chmod 544 ./register-connector.sh
RUN mkdir /etc/debezium && chown kafka:kafka /etc/debezium/

COPY ./wrapper-entrypoint.sh .
RUN chmod 544 ./wrapper-entrypoint.sh

COPY ./liveness.sh .
RUN chmod 544 ./liveness.sh

WORKDIR /kafka
USER kafka

ENTRYPOINT []
CMD ["/bin/bash", "/wrapper-entrypoint.sh"]
