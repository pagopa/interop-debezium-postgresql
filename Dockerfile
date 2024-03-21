FROM debezium/connect:2.5.2.Final@sha256:a46a977aa49f01e4da88b77122f870557d844e4f1b408979dd319ae6ea9ac35f

USER root

WORKDIR /kafka/connect
RUN find . -mindepth 1 -maxdepth 1 ! -name 'debezium-connector-postgres' -type d -exec rm -r {} \;

WORKDIR /usr/local/bin
RUN curl -LO https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64
RUN mv jq-linux-amd64 jq && chmod +x jq

WORKDIR /kafka/libs
RUN curl -LO https://github.com/aws/aws-msk-iam-auth/releases/download/v2.0.3/aws-msk-iam-auth-2.0.3-all.jar
RUN chown kafka:kafka ./aws-msk-iam-auth-2.0.3-all.jar && chmod 444 ./aws-msk-iam-auth-2.0.3-all.jar

RUN curl -LO https://github.com/aws-samples/msk-config-providers/releases/download/r0.2.0/msk-config-providers-0.2.0-all.jar
RUN chown kafka:kafka ./msk-config-providers-0.2.0-all.jar && chmod 444 ./msk-config-providers-0.2.0-all.jar

WORKDIR /opt/ssl/
RUN cp /usr/lib/jvm/java-11-openjdk-11.0.20.0.8-1.fc37.x86_64/lib/security/cacerts ./kafka.client.truststore.jks
RUN chown kafka:kafka ./kafka.client.truststore.jks && chmod 400 ./kafka.client.truststore.jks

WORKDIR /
COPY ./register-connector.sh .
RUN chown kafka:kafka ./register-connector.sh && chmod 544 ./register-connector.sh

COPY ./wrapper-entrypoint.sh .
RUN chmod 544 ./wrapper-entrypoint.sh

COPY ./liveness.sh .
RUN chmod 544 ./liveness.sh

WORKDIR /kafka
USER kafka

ENTRYPOINT []
CMD ["/bin/bash", "/wrapper-entrypoint.sh"]
