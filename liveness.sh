#!/bin/bash

set -euo pipefail

CONNECTOR_NAME="$(jq -r '.name' $CONNECTOR_CONFIG_PATH)"
URL="http://localhost:8083/connectors/$CONNECTOR_NAME/status"

connect_response=$(curl -s -w "\n%{http_code}\n" -H "Accept:application/json" "$URL")

status_code="$(tail -n1 <<< "$connect_response")"

if [ ! "$status_code" -eq "200" ]; then
  echo "Status $status_code from $URL" >&2
  exit 1
fi

body="$(sed '$ d' <<< "$connect_response")"
connector_state="$(echo "$body" | jq -r '.connector.state')"
connector_task_state="$(echo "$body" | jq -r '.tasks[0].state')"

if [ ! "$connector_state" = "RUNNING" ]; then
  echo "Connector state: $connector_state" >&2
  exit 1
fi

if [ ! "$connector_task_state" = "RUNNING" ]; then
  echo "Connector task state: $connector_task_state" >&2
  exit 1
fi

exit 0
