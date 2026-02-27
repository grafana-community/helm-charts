# tempo-vulture Helm Chart

Grafana Tempo Vulture - A tool to monitor Tempo performance.

## Source Code

* <https://github.com/grafana/tempo>

## Requirements

Kubernetes: `^1.25.0-0`

## Installing the Chart

### OCI Registry

OCI registries are preferred in Helm as they implement unified storage, distribution, and improved security.

```console
helm install RELEASE-NAME oci://ghcr.io/grafana-community/helm-charts/tempo-vulture
```

### HTTP Registry

```console
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo update
helm install RELEASE-NAME grafana-community/tempo-vulture
```

## Uninstalling the Chart

To remove all of the Kubernetes objects associated with the Helm chart release:

```console
helm delete RELEASE-NAME
```

## Changelog

See the [changelog](https://grafana-community.github.io/helm-charts/changelog/?chart=tempo-vulture).

---

## Configuration

Vulture only works with Jaeger gRPC, so make sure 14250 is open on your distributor. You don't need to specify the port in the distributor URL.

Example configuration:
```yaml
tempoAddress:
    push: http://tempo-tempo-distributed-distributor
    query: http://tempo-tempo-distributed-query-frontend:3100
```
