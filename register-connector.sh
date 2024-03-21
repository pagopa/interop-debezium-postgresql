#!/bin/bash

CONNECTOR_FILE="$1"
URL="http://localhost:8083/connectors/"

echo "Waiting for Kafka Connect startup..."

TIMEOUT_SEC=120
start_time="$(date -u +%s)"

while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' $URL)" != "200" ]]; do
  current_time="$(date -u +%s)"
  elapsed_seconds=$(($current_time-$start_time))

  if [ $elapsed_seconds -gt $TIMEOUT_SEC ]; then
    echo "Timeout while waiting for Kafka Connect startup"
    exit 1
  fi

  sleep 1
done

echo "Registering connector $CONNECTOR_FILE..."

connect_response=$(curl -s -w "\n%{http_code}\n" -X POST -H "Accept:application/json" -H "Content-Type:application/json" -d "@$CONNECTOR_FILE" "$URL")

status_code=$(tail -n1 <<< "$connect_response")
body=$(sed '$ d' <<< "$connect_response")

echo $body

if [ "$status_code" -eq "201" ]; then
  echo "Connector registered successfully"
elif [ "$status_code" -eq "409" ]; then
  echo "Connector already registered."
else
  echo "Error response from Kafka Connect REST API"
  exit 1
fi
