#!/bin/bash

set -euo pipefail

# Default values
OTEL_ENDPOINT=${OTEL_ENDPOINT:-"https://otel-collector.local.dev"}

# Function to get timestamp in nanoseconds
get_timestamp() {
  # Get current Unix timestamp in seconds
  local seconds=$(date +%s)
  # Convert to nanoseconds and add some random nanoseconds for uniqueness
  echo $((seconds * 1000000000 + RANDOM % 1000000))
}

# Function to send a test trace
send_test_trace() {
  echo "Sending test trace..."
  local timestamp=$(get_timestamp)
  curl -X POST "${OTEL_ENDPOINT}/v1/traces" \
    -H "Content-Type: application/json" \
    -d '{
      "resourceSpans": [{
        "resource": {
          "attributes": [{
            "key": "service.name",
            "value": { "stringValue": "test-service" }
          }]
        },
        "scopeSpans": [{
          "scope": {},
          "spans": [{
            "traceId": "'"$(openssl rand -hex 16)"'",
            "spanId": "'"$(openssl rand -hex 8)"'",
            "name": "test-span",
            "kind": 1,
            "startTimeUnixNano": '"$timestamp"',
            "endTimeUnixNano": '"$((timestamp + 1000000))"',
            "attributes": [{
              "key": "test.attribute",
              "value": { "stringValue": "test-value" }
            }]
          }]
        }]
      }]
    }'
  echo
}

# Function to send a test metric
send_test_metric() {
  echo "Sending test metric..."
  local timestamp=$(get_timestamp)
  curl -X POST "${OTEL_ENDPOINT}/v1/metrics" \
    -H "Content-Type: application/json" \
    -d '{
      "resourceMetrics": [{
        "resource": {
          "attributes": [{
            "key": "service.name",
            "value": { "stringValue": "test-service" }
          }]
        },
        "scopeMetrics": [{
          "scope": {},
          "metrics": [{
            "name": "test.metric",
            "gauge": {
              "dataPoints": [{
                "timeUnixNano": '"$timestamp"',
                "asDouble": 42.0,
                "attributes": [{
                  "key": "test.attribute",
                  "value": { "stringValue": "test-value" }
                }]
              }]
            }
          }]
        }]
      }]
    }'
  echo
}

# Function to send a test log
send_test_log() {
  echo "Sending test log..."
  local timestamp=$(get_timestamp)
  curl -X POST "${OTEL_ENDPOINT}/v1/logs" \
    -H "Content-Type: application/json" \
    -d '{
      "resourceLogs": [{
        "resource": {
          "attributes": [{
            "key": "service.name",
            "value": { "stringValue": "test-service" }
          }]
        },
        "scopeLogs": [{
          "scope": {},
          "logRecords": [{
            "timeUnixNano": '"$timestamp"',
            "severityText": "INFO",
            "body": {
              "stringValue": "This is a test log message"
            },
            "attributes": [{
              "key": "test.attribute",
              "value": { "stringValue": "test-value" }
            }]
          }]
        }]
      }]
    }'
  echo
}

# Main execution
main() {
  echo "Testing OpenTelemetry Collector at ${OTEL_ENDPOINT}"
  echo "=================================================="

  send_test_trace
  send_test_metric
  send_test_log

  echo "Test data sent successfully. Check your collector's debug output and APM server."
}

main "$@"
