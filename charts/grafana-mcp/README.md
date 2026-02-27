# grafana-mcp Helm Chart

MCP server for Grafana.

## Source Code

* <https://github.com/grafana/mcp-grafana>

## Requirements

Kubernetes: `^1.25.0-0`

## Installing the Chart

### OCI Registry

OCI registries are preferred in Helm as they implement unified storage, distribution, and improved security.

```console
helm install RELEASE-NAME oci://ghcr.io/grafana-community/helm-charts/grafana-mcp
```

### HTTP Registry

```console
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo update
helm install --set grafana.apiKey=<Grafana_ApiKey> RELEASE-NAME grafana-community/grafana-mcp
```

## Uninstalling the Chart

To remove all of the Kubernetes objects associated with the Helm chart release:

```console
helm delete RELEASE-NAME
```

## Changelog

See the [changelog](https://grafana-community.github.io/helm-charts/changelog/?chart=grafana-mcp).

---

## Upgrading

A major chart version change indicates that there is an incompatible breaking change needing manual actions.

### From Chart versions < 0.1.3
If you are upgrading from a chart version older than 0.1.3, we have changed the image to be pulled from
`grafana/mcp-grafana` instead of `mcp/grafana` and the default tag to be the chart's appVersion instead of `latest`.
