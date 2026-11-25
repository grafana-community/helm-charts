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

## Upgrading

### To 0.14.2

The pod template no longer carries `helm.sh/chart` or `app.kubernetes.io/version`, so a
chart release that changes neither the configuration nor the image no longer restarts the
vulture pod. Both labels remain on the Deployment, ServiceAccount and PodMonitor
themselves. Upgrading to 0.14.2 restarts the pod once.

If you select or group by these labels on the pod (for example `kube_pod_labels` joined on
`label_helm_sh_chart`), use the object-level labels or add what you need through
`podLabels`.

---

## Configuration

Vulture only works with Jaeger gRPC, so make sure 14250 is open on your distributor. You don't need to specify the port in the distributor URL.

Example configuration:
```yaml
tempoAddress:
    push: http://tempo-tempo-distributed-distributor
    query: http://tempo-tempo-distributed-query-frontend:3100
```
