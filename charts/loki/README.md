# loki

Helm chart for Grafana Loki supporting monolithic, simple scalable, and microservices modes.

## Source Code

* <https://github.com/grafana/loki>
* <https://grafana.com/oss/loki/>
* <https://grafana.com/docs/loki/latest/>

## Requirements

The Following are installed via subchart

| Repository | Name |
|------------|------|
| https://charts.min.io/ | minio(minio) |
| https://grafana.github.io/helm-charts | rollout_operator(rollout-operator) |

Find more information in the Loki Helm Chart [documentation](https://grafana.com/docs/loki/latest/setup/install/helm/).

## Installing the Chart

### OCI Registry

OCI registries are preferred in Helm as they implement unified storage, distribution, and improved security.

```console
helm install RELEASE-NAME oci://ghcr.io/grafana-community/helm-charts/loki
```

### HTTP Registry

```console
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo update
helm install RELEASE-NAME grafana-community/loki
```

## Uninstalling the Chart

To remove all of the Kubernetes objects associated with the Helm chart release:

```console
helm delete RELEASE-NAME
```

## Changelog

See the [changelog](https://grafana-community.github.io/helm-charts/changelog/?chart=loki).

---

## Upgrading

### From 17.x to 18.0.0

Dashboards, recording rules, and alert rules are now generated from [loki-mixin](https://github.com/grafana/loki/tree/main/production/loki-mixin) rather than maintained as static files. This fixes dashboard queries in Distributed deployment mode and aligns the chart with the upstream Loki observability stack.

#### `cluster` label repurposed; new `app_instance` label

The metric label that identifies the Loki Helm release has changed from `cluster` to `app_instance`. The `cluster` label is no longer added by default — it is now an optional label for multi-cluster environments, controlled by `monitoring.dashboards.multiCluster.enabled`. When enabled, its value comes from `monitoring.dashboards.multiCluster.clusterName` and represents the Kubernetes cluster, not the Helm release.

Actions required:
- Update any alerting rules, dashboards, or downstream recording rules that filter on `cluster=~"<release-name>"` to use `app_instance=~"<release-name>"` instead.
- Existing Grafana dashboard URLs that encode the `cluster` variable in the URL will need to be updated.
- If you run Loki across multiple Kubernetes clusters, enable `monitoring.dashboards.multiCluster.enabled` and set `monitoring.dashboards.multiCluster.clusterName` to restore the `cluster` label with a per-cluster value.

**To restore the old `cluster` label behavior (not recommended), you can set `monitoring.appInstanceLabelName` to `cluster`. However, this is not recommended as it may cause confusion in multi-cluster environments and does not align with upstream conventions.**

#### `clusterLabelOverride` and `monitoring.serviceMonitor.clusterLabel` removed

The top-level `clusterLabelOverride` value and `monitoring.serviceMonitor.clusterLabel` have been removed. Use `monitoring.appInstanceLabel` instead, which accepts Helm template syntax and defaults to `{{ include "loki.fullname" . }}`.

#### Recording rule names changed

All recording rule `record:` names now use `app_instance`-prefixed conventions from loki-mixin (e.g. `job:loki_request_duration_seconds:99quantile` → `app_instance_job:loki_request_duration_seconds:99quantile`). If you reference these in custom alerts or dashboards, update your queries.

#### Alerts separated from rules

Alert rules have been split into a new `monitoring.alerts` section, separate from `monitoring.rules` (which now only controls recording rules). Users who had `monitoring.rules.alerting: true` must switch to `monitoring.alerts.enabled: true`.

The old `monitoring.rules.configs` block (with per-alert `enabled`, `for`, `lookbackPeriod`, `threshold`, `severity`) has been removed. Alerts are now always generated from the loki-mixin templates and can be individually disabled or customised:

```yaml
monitoring:
  alerts:
    enabled: true
    disabled: {}    # disable specific alerts: { LokiRequestErrors: true }
    overrides: {}   # override per-alert for/severity: { LokiRequestErrors: { for: 5m, severity: warning } }
    keepFiringFor: ""
```

Note: `lookbackPeriod` and `threshold` are not carried forward as they did not generalize to all PromQL alert expressions.

#### Per-section namespace values consolidated

`monitoring.dashboards.namespace` and `monitoring.rules.namespace` have been removed in favour of a single `monitoring.namespace` value that applies to all monitoring resources (ServiceMonitor, PrometheusRule, ConfigMap dashboards).

#### `monitoring.rules.additionalGroups` replaced

`monitoring.rules.additionalGroups` has been replaced by `monitoring.additionalPrometheusRules`, which uses a dict structure and supports both recording rules and alerts:

```yaml
monitoring:
  additionalPrometheusRules:
    my-custom-rules:          # becomes a separate PrometheusRule resource
      groups:
        - name: my-rules
          rules:
            - alert: MyAlert
              expr: 'up{job="loki"} == 0'
```

#### Dashboard architecture changed

Dashboards are now generated from loki-mixin into individual ConfigMap resources (one per dashboard) instead of a single ConfigMap containing all dashboards. The static JSON source files under `src/dashboards/` have been removed.

New dashboard configuration options:
- `monitoring.dashboards.defaultDashboardsTimezone` (default: `utc`)
- `monitoring.dashboards.defaultDashboardsEditable` (default: `true`)
- `monitoring.dashboards.defaultDashboardsInterval` (default: `1m`)
- `monitoring.dashboards.grafanaOperator` — optional deployment via Grafana Operator CRD instead of ConfigMaps

### From 16.x to 17.0.0 ([#366](https://github.com/grafana-community/helm-charts/pull/366))

The built-in MinIO subchart is now **officially deprecated**. Enabling `minio.enabled=true` now fails chart rendering by default.

Actions required:
1. Configure a dedicated external object storage backend instead of the built-in MinIO dependency
   (for example: AWS S3, GCS, or Azure Blob). Potential self-hosted S3-compatible options include
   RustFS and Garage; validate production suitability for your environment before adoption.
2. Deploy a transition release that keeps old MinIO data readable but writes new data to the external store.
3. Keep both stores configured until old data in MinIO has aged out according to retention.
4. Remove the MinIO-related config only after retention has fully elapsed.

Recommended migration values flow:

Before (legacy state using built-in MinIO):

```yaml
minio:
  enabled: true

loki:
  schemaConfig:
    configs:
      - from: "2024-01-01"
        store: tsdb
        object_store: s3
        schema: v13
        index:
          prefix: index_
          period: 24h
```

Transition release (temporary dual-store period):

```yaml
# Temporary escape hatch while migrating
ignoreMinioDeprecation: true
minio:
  enabled: true

loki:
  # Use structuredConfig so you can configure named stores explicitly
  structuredConfig:
    storage_config:
      named_stores:
        aws:
          minio:
            endpoint: '{{ include "loki.minio" $ }}'
            bucketnames: chunks
            secret_access_key: '{{ $.Values.minio.rootPassword }}'
            access_key_id: '{{ $.Values.minio.rootUser }}'
            s3forcepathstyle: true
            insecure: true
          s3-loki-chunks:
            endpoint: 's3.example.com'
            bucketnames: chunks
            access_key_id: '<s3-access-key>'
            secret_access_key: '<s3-secret-key>'
            s3forcepathstyle: true
            insecure: true
    schema_config:
      configs:
        # Keep old data in MinIO readable
        - from: "2024-01-01"
          store: tsdb
          object_store: minio
          schema: v13
          index:
            prefix: index_
            period: 24h
        # Write new data to external S3
        - from: "2026-05-01" # Adjust this date as needed based on your retention period. Should be in the near future
          store: tsdb
          object_store: s3-loki-chunks
          schema: v13
          index:
            prefix: index_
            period: 24h
```

Final release (after retention has elapsed):

The chart still requires `loki.storage.bucketNames` for helper-generated storage sections such as `common.storage` and ruler storage.

```yaml
loki:
  storage:
    bucketNames:
      chunks: chunks
      ruler: ruler
  structuredConfig:
    storage_config:
      named_stores:
        aws:
          s3-loki-chunks:
            endpoint: 's3.example.com'
            bucketnames: chunks
            access_key_id: '<s3-access-key>'
            secret_access_key: '<s3-secret-key>'
            s3forcepathstyle: true
            insecure: true
    schema_config:
      configs:
        - from: "2026-05-01"
          store: tsdb
          object_store: s3-loki-chunks
          schema: v13
          index:
            prefix: index_
            period: 24h
```

Reference docs:
- <https://grafana.com/docs/loki/latest/operations/storage/schema/>
- <https://grafana.com/docs/loki/latest/configure/storage/>
- Potential self-hosted S3-compatible options:
  - RustFS: <https://docs.rustfs.com/installation/docker/>
  - Garage: <https://garagehq.deuxfleurs.fr/documentation/quick-start/>

### From 15.x to 16.0.0 ([#499](https://github.com/grafana-community/helm-charts/pull/499))

The `loki-canary` workload no longer uses the shared Loki pod template. This change isolates canary rendering from Loki component configuration after users reported that shared settings were unintentionally inherited by canary and could break canary startup.

What changed:
- `loki-canary` no longer inherits metadata from `loki.*` values such as `loki.annotations`, `loki.serviceAnnotations`, and `loki.serviceLabels`.
- Canary pod annotations are now sourced only from `lokiCanary.podAnnotations`.
- Canary pod API token mount behavior is now controlled explicitly by `lokiCanary.automountServiceAccountToken`.

Actions required:
- Move canary-specific metadata from `loki.*` keys to `lokiCanary.*` keys.
- If you previously relied on inherited settings, set the canary values explicitly.

Before:

```yaml
loki:
  annotations:
    team: observability
  serviceAnnotations:
    prometheus.io/scrape: "true"
  serviceLabels:
    app: loki
```

After:

```yaml
lokiCanary:
  annotations:
    team: observability
  podAnnotations:
    team: observability
  service:
    annotations:
      prometheus.io/scrape: "true"
    labels:
      app: loki-canary
  automountServiceAccountToken: false
```

### From 14.x to 15.0.0 ([#413](https://github.com/grafana-community/helm-charts/pull/413))

Support for Cilium-specific network policies has been removed from this chart.

Actions required:
- Remove `networkPolicy.flavor` from your values file. The chart now renders Kubernetes `NetworkPolicy` resources only.
- Remove `networkPolicy.egressWorld.enabled` and `networkPolicy.egressKubeApiserver.enabled` from your values file.
- If you relied on Cilium-only behavior, manage those `CiliumNetworkPolicy` rules outside this chart (for example with separate manifests managed by your GitOps workflow).

Before:

```yaml
networkPolicy:
  enabled: true
  flavor: cilium
  egressWorld:
    enabled: true
  egressKubeApiserver:
    enabled: true
```

After:

```yaml
networkPolicy:
  enabled: true
```

### From 13.x to 14.0.0 ([#479](https://github.com/grafana-community/helm-charts/pull/479))

The dot-based registry heuristic has been removed. Previously, if the `repository` value contained a dot (`.`) in its first path segment, the chart assumed it already included a registry and silently skipped prepending `global.imageRegistry` or the service-level `registry`. This caused configured registries to be ignored for image references like `mirror.gcr.io/grafana/loki` or `foo.com/loki-fips`.

**This is now the expected behavior**: when a registry is configured (via `global.imageRegistry` or a component's `image.registry`), it is always prepended unconditionally.

Actions required:
- If you stored a fully-qualified image reference in `repository` (e.g. `repository: private.registry.com/grafana/loki`) and relied on the dot-heuristic to prevent double-prefixing, split the value into separate `registry` and `repository` fields:

Before:

```yaml
loki:
  image:
    repository: private.registry.com/grafana/loki
```

After:

```yaml
loki:
  image:
    registry: private.registry.com
    repository: grafana/loki
```

Users who only set `repository` to a plain path (e.g. `grafana/loki`) or who use `global.imageRegistry` / `image.registry` correctly are unaffected.

### From 12.x to 13.0.0 ([#258](https://github.com/grafana-community/helm-charts/pull/258))

The persistence configuration for ephemeral volumes has been flattened.

Actions required:
- Replace `persistence.ephemeralDataVolume.enabled: true` with `persistence.enabled: true` and `persistence.type: ephemeral`.
- Move any fields under `persistence.ephemeralDataVolume` (`accessModes`, `size`, `storageClass`, `volumeAttributesClassName`, `selector`, `annotations`, `labels`) directly under `persistence`.

Before:

```yaml
<component>:
  persistence:
    ephemeralDataVolume:
      enabled: true
      accessModes:
        - ReadWriteOnce
      size: 10Gi
      storageClass: null
```

After:

```yaml
<component>:
  persistence:
    enabled: true
    type: ephemeral
    accessModes:
      - ReadWriteOnce
    size: 10Gi
    storageClass: null
```


### From 11.x to 12.0.0 ([#258](https://github.com/grafana-community/helm-charts/pull/258))

The `deploymentMode` default value has been changed to `Monolithic`. `SingleBinary` has been renamed to `Monolithic`. 
The old naming `SingleBinary` is still supported. `SimpleScalable` is still supported but will be removed in Loki 4.0.0.

Actions required:
- If you are using `SimpleScalable` deployment mode, you have to explicitly set `deploymentMode: SimpleScalable` in your values file to avoid breaking changes. Consider migrating to `Monolithic` deployment mode as `SimpleScalable` will be removed in Loki 4.0.0.
- If you are using `SingleBinary` deployment mode, you have to explicitly set `deploymentMode: Monolithic` in your values file to avoid breaking changes.

### From 10.x to 11.0.0 ([#273](https://github.com/grafana-community/helm-charts/pull/273))

The `read.legacyReadTarget` option has been removed. Simple scalable deployments always requires a dedicated backend target.

### From 9.x to 10.0.0 ([#270](https://github.com/grafana-community/helm-charts/pull/270))

The `indexGateway.persistence.inMemory` has been replaced with `indexGateway.persistence.dataVolumeParameters` to establish a more consistent configuration for persistence across all components.

Before:

```yaml
indexGateway:
  persistence:
    inMemory: true
    size: 10Gi
```

After:

```yaml
indexGateway:
  persistence:
    dataVolumeParameters:
      emptyDir:
        medium: Memory
        sizeLimit: 10Gi
```

### From 8.x to 9.0.0 ([#187](https://github.com/grafana-community/helm-charts/pull/187))

The `monitoring.selfMonitoring` component has been removed along with `grafana-agent-operator` subchart dependency.  Additionally, loki-canary tenant authentication has been moved as it was located under selfMonitoring.

Actions required:
- `monitoring.selfMonitoring` has been removed because [Grafana Agent is EOL](https://grafana.com/docs/agent/latest/).  Native support for collection and shipment of logs to Loki is no longer supported in the chart.  [Grafana Alloy](https://grafana.com/docs/alloy/latest/) is the successor to Grafana Agent if you're to re-implement the same functionality.
- `monitoring.serviceMonitor.metricsInstance` has been removed as it implemented a (Grafana Agent) CRD object no longer supported.
- loki-canary authentication is now configured via `lokiCanary.tenant.name` and `lokiCanary.tenant.password`.

### From 7.x to 8.0.0 ([#184](https://github.com/grafana-community/helm-charts/pull/184))

Grafana Enterprise Logs (GEL) / Loki Enterprise support has been removed from this chart. This chart is intended for open-source Loki users only.

If you are a GEL user, do not migrate to this chart. The upstream `grafana/loki` chart remains available for GEL users. Consult your Grafana Labs account team about your migration options. See the [migration announcement](https://github.com/grafana/loki/issues/20705) for details.

### From 6.x to 7.0.0 ([#183](https://github.com/grafana-community/helm-charts/pull/183))

Support for deprecated Kubernetes APIs has been dropped. **Kubernetes 1.25 or later is now required.**

Actions required:

- Remove `rbac.pspEnabled` and `rbac.pspAnnotations` from your values file — PodSecurityPolicy support has been removed (PSP was removed in Kubernetes 1.25).
- Ingress resources now use `networking.k8s.io/v1` only; `v1beta1` is no longer supported.
- PodDisruptionBudget resources now use `policy/v1` only.
