MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# renovate: docker=helmunittest/helm-unittest
HELM_UNITTEST_TAG := 3.19.0-1.0.3

.PHONY: helm-unittest
helm-unittest:
	docker run --rm -v $(MAKEFILE_DIR):/apps helmunittest/helm-unittest:$(HELM_UNITTEST_TAG) --strict --file 'tests/**/*.yaml' charts/*
