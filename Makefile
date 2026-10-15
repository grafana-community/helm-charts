MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# renovate: docker=helmunittest/helm-unittest
HELM_UNITTEST_TAG := 4.2.0-1.1.0

# Chart(s) to target (glob pattern, e.g. HELM_CHART=loki)
HELM_CHART ?= *
# Test file pattern within the chart (e.g. HELM_UNITTEST_FILE='tests/ingester/*_test.yaml')
HELM_UNITTEST_FILE  ?= tests/**/*.yaml

.PHONY: helm-unittest
helm-unittest:
	docker run --rm -v $(MAKEFILE_DIR):/apps helmunittest/helm-unittest:$(HELM_UNITTEST_TAG) --strict --file '$(HELM_UNITTEST_FILE)' charts/$(HELM_CHART)


# Regenerates values.schema.json for every targeted chart whose values.yaml opts in via "# $schema: ./values.schema.json"
.PHONY: helm-schema
helm-schema:
	@found=0; \
	for chart in charts/$(HELM_CHART)/; do \
		if grep -q '^# \$$schema: ./values.schema.json' "$${chart}values.yaml" 2>/dev/null; then \
			found=1; \
			helm schema --config $(MAKEFILE_DIR).github/linters/.schema.yaml -f "$${chart}values.yaml" -o "$${chart}values.schema.json" || exit 1; \
		fi; \
	done; \
	if [ "$$found" -eq 0 ]; then echo "No chart matching '$(HELM_CHART)' has a '# \$$schema: ./values.schema.json' header." >&2; exit 1; fi
