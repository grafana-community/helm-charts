# synthetic-monitoring-agent Helm Chart

Grafana's Synthetic Monitoring application. The agent provides probe functionality and executes network checks for monitoring remote targets.

> [!NOTE]
> Grafana Cloud Synthetic Monitoring does not officially support this chart.
> If you are a Grafana Cloud customer and require support, please follow the [recommended installation methods](https://grafana.com/docs/grafana-cloud/testing/synthetic-monitoring/set-up/set-up-private-probes/#deployment-with-kubernetes) listed in the public docs.

## Source Code

* <https://github.com/grafana/synthetic-monitoring-agent>

## Requirements

Kubernetes: `^1.25.0-0`

## Installing the Chart

### OCI Registry

OCI registries are preferred in Helm as they implement unified storage, distribution, and improved security.

```console
helm install RELEASE-NAME oci://ghcr.io/grafana-community/helm-charts/synthetic-monitoring-agent
```

### HTTP Registry

```console
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo update
helm install RELEASE-NAME grafana-community/synthetic-monitoring-agent
```

## Uninstalling the Chart

To remove all of the Kubernetes objects associated with the Helm chart release:

```console
helm delete RELEASE-NAME
```

## Changelog

See the [changelog](https://grafana-community.github.io/helm-charts/changelog/?chart=synthetic-monitoring-agent).
