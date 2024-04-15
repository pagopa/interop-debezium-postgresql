#!/bin/bash

set -euo pipefail

CONNECTOR_NAME="$(jq -r '.name' $CONNECTOR_CONFIG_PATH)"
BASE_URL="http://localhost:8083/connectors"
STATUS_URL="$BASE_URL/$CONNECTOR_NAME/status"
CONFIG_URL="$BASE_URL/$CONNECTOR_NAME/config"
CURRENT_IP="$(ip -4 -br addr show eth0 | awk '{print $3}' | sed -E 's/\/[0-9]+//')"

function log_info() {
  local message="$1"
  local ts="$(date +'%Y-%m-%d %H:%M:%S,%3N')"

  echo "${ts} INFO    || [register-connector.sh] ${message}"
}

function log_error() {
  local message="$1"
  local ts="$(date +'%Y-%m-%d %H:%M:%S,%3N')"

  echo "${ts} ERROR    || [register-connector.sh] ${message}" >&2
}


function wait_for_kafka_connect() {
  TIMEOUT_SEC=120
  start_time="$(date -u +%s)"

  while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' $BASE_URL)" != "200" ]]; do
    current_time="$(date -u +%s)"
    elapsed_seconds=$(($current_time-$start_time))

    if [ $elapsed_seconds -gt $TIMEOUT_SEC ]; then
      log_error "Timeout while waiting for Kafka Connect startup"
      exit 1
    fi

    sleep 1
  done
}

function check_connector_worker() {
  connector_status_response="$(curl -s -w "\n%{http_code}\n" -H "Accept:application/json" "$STATUS_URL")"
  connector_status_code="$(tail -n1 <<< "$connector_status_response")"
  connector_status_body="$(sed '$ d' <<< "$connector_status_response")"

  log_info "Connector status: $connector_status_response"

  if [ "$connector_status_code" -eq "200" ]; then
    connector_worker_ip="$(echo "$connector_status_body" | jq -r '.connector.worker_id' | sed -e 's/:.*$//')"

    log_info "Current IP: $CURRENT_IP, assigned worker IP: $connector_worker_ip"

    # this worker will be idle
    if [ ! "$CURRENT_IP" = "$connector_worker_ip" ]; then 
      log_info "The connector task has already been assigned to another worker."
      exit 0
    fi
  fi
}

function upsert_connector() {
  local body_path="$1"

  local upsert_response=$(curl -s -w "\n%{http_code}\n" \
                    -X PUT -H "Accept:application/json" -H "Content-Type:application/json" \
                    -d "@$body_path" "$CONFIG_URL")

  echo "$upsert_response"
}

function register_connector() {
  UNWRAPPED_CONNECTOR_CONFIG_PATH="${CONNECTOR_CONFIG_PATH%.json}-unwrapped.json"
  jq '.config' "$CONNECTOR_CONFIG_PATH" > "$UNWRAPPED_CONNECTOR_CONFIG_PATH"

  local upsert_response="$(upsert_connector "$UNWRAPPED_CONNECTOR_CONFIG_PATH")"
  local upsert_status_code="$(tail -n1 <<< "$upsert_response")"

  REBALANCE_TIMEOUT_SEC=60
  start_time="$(date -u +%s)"

  while [[ "$upsert_status_code" = "409" ]]; do
    log_info "Connector task rebalancing in progress, retrying..."
    sleep 2

    current_time="$(date -u +%s)"
    elapsed_seconds=$(($current_time-$start_time))

    if [ $elapsed_seconds -gt $REBALANCE_TIMEOUT_SEC ]; then
      log_error "Timeout while waiting for connector task rebalance."
      exit 1
    fi

    upsert_response="$(upsert_connector "$UNWRAPPED_CONNECTOR_CONFIG_PATH")"
    upsert_status_code="$(tail -n1 <<< "$upsert_response")"
  done;

  
  if [ "$upsert_status_code" -eq "201" ]; then
    log_info "Connector registered successfully."
  elif [ "$upsert_status_code" -eq "200" ]; then
    log_info "Connector was already registered. Configuration updated."
  else
    log_error "Error response while registering connector:\n${upsert_response}\n"
    exit 1
  fi
}

log_info "Waiting for Kafka Connect startup..."
wait_for_kafka_connect

log_info "Checking connector worker..."
check_connector_worker

log_info "Registering connector $CONNECTOR_CONFIG_PATH..."
register_connector
