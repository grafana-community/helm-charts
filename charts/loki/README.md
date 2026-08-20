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

## StatefulSet immutability

Kubernetes forbids in-place updates to most StatefulSet spec fields. A Helm upgrade (or GitOps reconcile) that changes one of those fields fails with:

```text
StatefulSet.apps "..." is invalid: spec: Forbidden: updates to statefulset spec for fields other than
'replicas', 'ordinals', 'template', 'updateStrategy', 'persistentVolumeClaimRetentionPolicy' and 'minReadySeconds' are forbidden
```

This is a Kubernetes API constraint, not a Flux-specific bug. Under Flux `HelmRelease`, Argo CD, or any controller that retries, the same forbidden patch fails on every reconcile.

Treat storage class, PVC size, access modes, volume-claim identity, `podManagementPolicy`, and the generated pod selector / headless `serviceName` as **install-time** decisions unless you follow a documented recreate or migration path.

### Which workloads render StatefulSets

| Deployment mode | Typical StatefulSet components |
| --- | --- |
| Monolithic (`singleBinary`) | `singleBinary` when `singleBinary.kind=StatefulSet` (the default) |
| Simple Scalable | `write`, `backend` (and `read` only if `read.kind=StatefulSet`) |
| Distributed | `ingester`, `indexGateway`, `compactor`, `ruler`, plus `patternIngester` / bloom components when enabled and `kind=StatefulSet` |
| Caches | `resultsCache` / `chunksCache` memcached StatefulSets when those caches are enabled |

Loki component StatefulSets are rendered from `templates/_workload.tpl`. Memcached caches use `templates/memcached/_memcached-statefulset.tpl`.

### Values that map to immutable StatefulSet fields

Paths below are per component (`singleBinary.*`, `write.*`, `backend.*`, `ingester.*`, and so on) unless noted.

| Values | STS field | Live-patchable? | Recreate job covers it? |
| --- | --- | --- | --- |
| `*.persistence.storageClass`, `*.persistence.claims[].storageClass`, zone storageClass overrides | `volumeClaimTemplates[].spec.storageClassName` | No | No |
| `*.persistence.size`, `*.persistence.claims[].size`, cache `persistence.storageSize` | `volumeClaimTemplates[].spec.resources.requests.storage` | No | Yes, if `*.statefulSetRecreateJob.enabled` (Loki components only). Also patches PVCs when `defaults.statefulSetRecreateJob.patchPVC` is true |
| `*.persistence.accessModes`, `claims[].accessModes` | `volumeClaimTemplates[].spec.accessModes` | No | No |
| `*.persistence.selector` | `volumeClaimTemplates[].spec.selector` | No | No |
| `*.persistence.volumeAttributesClassName` and claims equivalent | `volumeClaimTemplates[].spec.volumeAttributesClassName` | No | No |
| `*.persistence.labels`, `claims[].labels`, claim `name` | VCT metadata identity | No | Count/name/size mismatch only; labels and annotations are not compared |
| `*.persistence.annotations`, `claims[].annotations` | VCT annotations | Treat as no | No |
| `*.podManagementPolicy` | `spec.podManagementPolicy` | No | Yes, if the recreate job is enabled |
| `nameOverride`, `fullnameOverride`, `*.fullnameOverride`, Helm release name | `spec.selector` and `spec.serviceName` | No | `serviceName` only; selector changes are not handled |
| Chart-generated selector (`app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/component`, plus zone labels on zone-aware ingesters) | `spec.selector` | No | No |

Some simple-scalable / monolithic components define `*.selectorLabels` in `values.yaml`. Those keys are **not rendered** into `spec.selector` today. Do not use them to change pod selectors.

### Day-2 changes that are safe

Prefer values that only affect `spec.template` or the Kubernetes-allowed StatefulSet fields:

- Image, resources, env, probes, affinity, and extra volumes that are **not** VCT-backed
- Config via ConfigMap/Secret (the pod template changes)
- `replicas` (unless omitted for HPA/KEDA), `strategy` / `updateStrategy`, and `persistence.whenDeleted` / `whenScaled` when auto-delete PVC is enabled

Switching `*.kind` between `StatefulSet` and `Deployment` replaces the workload object; it is not an in-place StatefulSet patch.

### Recreate job (experimental)

Each Loki component StatefulSet can set `*.statefulSetRecreateJob.enabled=true`. On `helm upgrade`, a pre-upgrade Job:

1. Uses cluster `lookup` to compare the live StatefulSet with the newly rendered spec.
2. Deletes the StatefulSet with `kubectl delete statefulset --cascade=orphan` when `podManagementPolicy`, `serviceName`, volume-claim count, claim name, or claim **size** differs.
3. Optionally patches existing PVC storage requests when `defaults.statefulSetRecreateJob.patchPVC` is true (size increases only; the StorageClass must allow volume expansion).

The job does **not** migrate `storageClass`, `accessModes`, VCT selectors, VCT labels/annotations, or `volumeAttributesClassName`.

`lookup` requires a live cluster during `helm upgrade`. `helm template` and dry-run without cluster access will not emit the Job. Flux helm-controller upgrades do talk to the cluster, so the Job can run there; still treat this path as disruptive (orphan delete + recreate).

Memcached cache StatefulSets do not have this Job.

### Migrating volumeClaimTemplates without the recreate job

When you must change an immutable VCT field the recreate job does not cover:

1. Confirm object-storage / backup / WAL retention is sound for that component (filesystem monolithic vs object-storage backends).
2. Pause writes or scale down if the component cannot lose in-flight data.
3. Delete the StatefulSet with `--cascade=orphan` so existing PVCs are retained when intended (`persistence.whenDeleted` / `enableStatefulSetAutoDeletePVC` must not delete them).
4. Recreate the StatefulSet with the new VCT fields and re-attach or migrate data.
5. Resume traffic.

PVC size increases on a StorageClass that supports expansion can use the recreate job instead of this manual sequence.

### GitOps / server-side apply

- Immutable StatefulSet drift fails **every** reconcile, not only a one-shot `helm upgrade`. Suspend the `HelmRelease` / Application until you migrate; do not leave retry spam firing alerts.
- Do not oscillate values that rewrite VCT specs (for example `storageClass: null` vs an explicit class across environments).
- This chart emits `apiVersion: v1` and `kind: PersistentVolumeClaim` on each VCT. Older live objects that lack those fields can fail server-side apply even when values did not change.
- Chart upgrades that change default VCT fields (access modes, labels, default size) can block upgrades for existing releases. Pin the previous values until you migrate.

Related historical Loki chart regressions (grafana/loki): [#9524](https://github.com/grafana/loki/issues/9524) (`podManagementPolicy`), [#19065](https://github.com/grafana/loki/issues/19065) (persistence/`accessModes`), [#12854](https://github.com/grafana/loki/issues/12854) / [#21675](https://github.com/grafana/loki/issues/21675) (PVC size / recreate job). Original request: [grafana/loki#23912](https://github.com/grafana/loki/issues/23912).

---

## Upgrading

### From 17.x to 18.0.0 ([#193](https://github.com/grafana-community/helm-charts/pull/193))

The `.Values.monitoring` block has been refactored and the root `.Values.clusterLabelOverride` field removed and merged into `.Values.monitoring`. Users should not assume backwards compatibility with any prior monitoring configuration — review this section in full before upgrading.

All dashboards, recording rules, and alert rules are now generated from the upstream [loki-mixin](https://github.com/grafana/loki/tree/main/production/loki-mixin) rather than maintained as static files. This ensures dashboard queries work correctly across all deployment modes (Monolithic, SimpleScalable, Distributed) and keeps the chart aligned with the upstream Loki observability stack.

#### `cluster` label repurposed; new `app_instance` label

The metric label that identifies the Loki Helm release has changed from `cluster` to `app_instance`. The `cluster` label is no longer added by default — it is now an optional label for multi-cluster environments, controlled by `monitoring.multiCluster.enabled`. When enabled, its value comes from `monitoring.multiCluster.clusterName` and represents the Kubernetes cluster, not the Helm release.

Actions required:
- Update any alerting rules, dashboards, or downstream recording rules that filter on `cluster=~"<release-name>"` to use `app_instance=~"<release-name>"` instead.
- Existing Grafana dashboard URLs that encode the `cluster` variable in the URL will need to be updated.
- If you run Loki across multiple Kubernetes clusters, enable `monitoring.multiCluster.enabled` and set `monitoring.multiCluster.clusterName` to restore the `cluster` label with a per-cluster value.

#### Alerts separated from rules

Alert rules have been split into a new `monitoring.alerts` section, separate from `monitoring.rules` (which now only controls recording rules). Users who had `monitoring.rules.alerting: true` must switch to `monitoring.alerts.enabled: true`.

The old `monitoring.rules.configs` block (with per-alert `enabled`, `for`, `lookbackPeriod`, `threshold`, `severity`) has been removed. Alerts are now generated from the loki-mixin and can be individually disabled or customised:

```yaml
monitoring:
  alerts:
    enabled: true
    disabled: {}    # disable specific alerts: { LokiRequestErrors: true }
    overrides: {}   # override per-alert for/severity: { LokiRequestErrors: { for: 5m, severity: warning } }
    keepFiringFor: ""
```

Note: `lookbackPeriod` and `threshold` are not carried forward as they did not generalize to all PromQL alert expressions.

#### Removed and renamed values

| Old value | Replacement |
|---|---|
| `ingester.updateStrategy` | `ingester.strategy` |
| `clusterLabelOverride` | `monitoring.appInstanceLabelName` and `monitoring.appInstanceLabelValue` |
| `monitoring.serviceMonitor.clusterLabel` | `monitoring.appInstanceLabelName` and `monitoring.appInstanceLabelValue` |
| `monitoring.dashboards.namespace` | `monitoring.namespace` (applies to all monitoring resources) |
| `monitoring.rules.namespace` | `monitoring.namespace` |
| `monitoring.rules.additionalGroups` | `monitoring.additionalPrometheusRules` (dict structure, supports both recording rules and alerts — see `values.yaml` for examples) |
| `monitoring.dashboards.multiCluster` | `monitoring.multiCluster` (hoisted to monitoring level) |

#### Recording rule names

Recording rule `record:` names now use the `cluster_job:`, `cluster_job_route:`, and `cluster_namespace_job_route:` conventions from the upstream loki-mixin. If you reference recording rule metrics directly in custom alerts or dashboards, update your queries.

#### Multi-cluster configuration

`monitoring.multiCluster` supports two modes:

| Setting | Behavior |
|---|---|
| `enabled: true` + `clusterName: "my-cluster"` | **Basic mode.** The chart adds `cluster` labels to ServiceMonitor relabeling, recording rules, and alerts. Recording rule aggregations include `cluster` in `by()` clauses. Dashboards show the `cluster` variable. |
| `enabled: true` + `clusterName: ""` | **Externally managed mode.** Only dashboards are modified — the `cluster` variable is shown. Recording rules, alerts, and ServiceMonitor are not modified. Use this when an external tool (e.g. Grafana Alloy) handles cluster label injection and PromQL rewriting. |

To restore the old `cluster` label behavior (not recommended), set `monitoring.appInstanceLabelName` to `cluster`. This may cause confusion in multi-cluster environments and does not align with community conventions.

#### Dashboard architecture changed

Dashboards are now generated from loki-mixin into individual ConfigMap resources (one per dashboard) instead of a single ConfigMap containing all dashboards. The static JSON source files under `src/dashboards/` have been removed.

New dashboard configuration options:
- `monitoring.dashboards.defaultDashboardsTimezone` (default: `utc`)
- `monitoring.dashboards.defaultDashboardsEditable` (default: `true`)
- `monitoring.dashboards.defaultDashboardsInterval` (default: `1m`)
- `monitoring.dashboards.grafanaOperator` — optional deployment via Grafana Operator CRD instead of ConfigMaps
- `monitoring.dashboards.grafanaOperator.instanceSelector` — label selector matching your Grafana instance's labels (default: `{}`)

### From 16.x to 17.0.0 ([#366](https://github.com/grafana-community/helm-charts/pull/366))

The built-in MinIO subchart is now **officially deprecated**. Enabling `minio.enabled=true` now fails chart rendering by default.

Actions required:
1. Configure a dedicated external object storage backend instead of the built-in MinIO dependency (for example: AWS S3, GCS, or Azure Blob). Potential self-hosted S3-compatible options include RustFS and Garage; validate production suitability for your environment before adoption.
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
`global.imageRegistry` is intentionally the highest-precedence registry setting and overrides all component-level `image.registry` values.

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
