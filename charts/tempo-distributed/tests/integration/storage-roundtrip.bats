#!/usr/bin/env bats

TRACE_ID="1af7651916cd43dd8448eb211c80319d"
DISTRIBUTOR="${DISTRIBUTOR_URL:?DISTRIBUTOR_URL env var is required}"
QUERY_FRONTEND="${QUERY_FRONTEND_URL:?QUERY_FRONTEND_URL env var is required}"

TRACE_PAYLOAD='{
  "resourceSpans": [{
    "scopeSpans": [{
      "spans": [{
        "traceId": "1af7651916cd43dd8448eb211c80319d",
        "spanId": "c7ad6b7169203331",
        "name": "storage-roundtrip",
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

@test "query-frontend returns trace by ID" {
	local result
	# shellcheck disable=SC2034
	for _ in $(seq 1 30); do
		result=$(wget -q -O- "${QUERY_FRONTEND}/api/traces/${TRACE_ID}" 2>/dev/null || true)
		if echo "${result}" | grep -q "storage-roundtrip"; then
			return 0
		fi
		sleep 2
	done
	echo "trace ${TRACE_ID} not found after 60 seconds" >&3
	echo "last response: ${result}" >&3
	return 1
}