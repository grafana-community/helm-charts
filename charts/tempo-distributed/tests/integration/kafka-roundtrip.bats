#!/usr/bin/env bats

TRACE_ID="0af7651916cd43dd8448eb211c80319c"
DISTRIBUTOR="${DISTRIBUTOR_URL:?DISTRIBUTOR_URL env var is required}"
QUERY_FRONTEND="${QUERY_FRONTEND_URL:?QUERY_FRONTEND_URL env var is required}"

TRACE_PAYLOAD='{
  "resourceSpans": [{
    "scopeSpans": [{
      "spans": [{
        "traceId": "0af7651916cd43dd8448eb211c80319c",
        "spanId": "b7ad6b7169203331",
        "name": "kafka-roundtrip",
        "kind": 1,
        "startTimeUnixNano": "1000000000",
        "endTimeUnixNano": "2000000000",
        "status": {}
      }]
    }]
  }]
}'

setup_file() {
	wget -q -O- \
		--header 'Content-Type: application/json' \
		--post-data "${TRACE_PAYLOAD}" \
		"${DISTRIBUTOR}/v1/traces"
}

@test "distributor accepts OTLP/HTTP push" {
	run wget -q -O- \
		--header 'Content-Type: application/json' \
		--post-data "${TRACE_PAYLOAD}" \
		"${DISTRIBUTOR}/v1/traces"
	[ "$status" -eq 0 ]
}

@test "live-store serves trace by ID" {
	local result
	# shellcheck disable=SC2034
	for _ in $(seq 1 60); do
		result=$(wget -q -O- "${QUERY_FRONTEND}/api/traces/${TRACE_ID}" 2>/dev/null || true)
		if echo "${result}" | grep -q "kafka-roundtrip"; then
			return 0
		fi
		sleep 2
	done
	echo "trace ${TRACE_ID} not found after 2 minutes" >&3
	echo "last response: ${result}" >&3
	return 1
}

