#!/bin/bash

cat << EOT >> /kafka/config/log4j.properties
log4j.appender.stdout.filter.1=org.apache.log4j.varia.StringMatchFilter
log4j.appender.stdout.filter.1.StringToMatch=GET /connectors
log4j.appender.stdout.filter.1.AcceptOnMatch=false
EOT

/register-connector.sh $CONNECTOR_CONFIG_PATH &

/docker-entrypoint.sh start
