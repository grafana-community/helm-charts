# mimir-distributed

Helm chart for deploying Grafana Mimir in microservices mode.

## Source Code

* <https://github.com/grafana/mimir>
* <https://grafana.com/oss/mimir/>
* <https://grafana.com/docs/mimir/latest/>

## Requirements

Kubernetes: `^1.32.0-0`

The following are installed via subchart:

| Repository | Name | Version |
|------------|------|---------|
| https://charts.min.io/ | minio(minio) | 5.4.0 |
| https://grafana.github.io/helm-charts | grafana-agent-operator(grafana-agent-operator) | 0.5.2 |
| https://grafana.github.io/helm-charts | rollout_operator(rollout-operator) | 0.53.1 |

Find more information in the Grafana Mimir Helm chart [documentation](https://grafana.com/docs/helm-charts/mimir-distributed/latest/).

## Installing the Chart

### OCI Registry

OCI registries are preferred in Helm as they implement unified storage, distribution, and improved security.

```console
helm install RELEASE-NAME oci://ghcr.io/grafana-community/helm-charts/mimir-distributed
```

### HTTP Registry

```console
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo update
helm install RELEASE-NAME grafana-community/mimir-distributed
```

## Uninstalling the Chart

To remove all of the Kubernetes objects associated with the Helm chart release:

```console
helm delete RELEASE-NAME
```

## Changelog

See the [changelog](https://grafana-community.github.io/helm-charts/changelog/?chart=mimir-distributed).

---

## Upgrading
