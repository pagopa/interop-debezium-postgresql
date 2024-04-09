#!/bin/bash

set -euo pipefail

CONNECTOR_NAME="$(jq -r '.name' $CONNECTOR_CONFIG_PATH)"
BASE_URL="http://localhost:8083/connectors"
STATUS_URL="$BASE_URL/$CONNECTOR_NAME/status"
CURRENT_IP="$(ip -4 -br addr show eth0 | awk '{print $3}' | sed -E 's/\/[0-9]+//')"

function check_kafka_connect() {
  connect_base_response=$(curl -s -w "\n%{http_code}\n" -H "Accept:application/json" "$BASE_URL")
  base_status_code="$(tail -n1 <<< "$connect_base_response")"

  if [ ! "$base_status_code" -eq "200" ]; then
    echo "Status $status_code from Kafka Connect" >&2
    exit 1
  fi
}

function check_connector_worker() {
  connector_status_response="$(curl -s -w "\n%{http_code}\n" -H "Accept:application/json" "$STATUS_URL")"
  connector_status_code="$(tail -n1 <<< "$connector_status_response")"
  connector_status_body="$(sed '$ d' <<< "$connector_status_response")"
  connector_worker_ip="$(echo "$connector_status_body" | jq -r '.connector.worker_id')"

  if [ ! "$connector_status_code" -eq "200" ]; then
    echo "Error while checking connector status:\n${connector_status_body}\n" >&2
    exit 1
  fi

  # this worker is idle
  [ ! "$CURRENT_IP" = "$connector_worker_ip" ] && exit 0
}

function check_connector_state() {
  connector_state="$(echo "$connector_status_body" | jq -r '.connector.state')"
  connector_task_state="$(echo "$connector_status_body" | jq -r '.tasks[0].state')"


  if [ ! "$connector_status_code" -eq "200" ]; then
    echo "Status $connector_status_code from $STATUS_URL" >&2
    exit 1
  fi

  if [ ! "$connector_state" = "RUNNING" ]; then
    echo "Connector state: $connector_state" >&2
    exit 1
  fi

  if [ ! "$connector_task_state" = "RUNNING" ]; then
    echo "Connector task state: $connector_task_state" >&2
    exit 1
  fi
}

check_kafka_connect
check_connector_worker
check_connector_state

exit 0
