# Upgrade guide

## v2.x → v3.0 (Tempo 3.0)

Tempo 3.0 replaces the ingester-based write path with a Kafka-backed architecture.
This is a **breaking change** for microservices-mode deployments.

### Grafana Enterprise Tempo

Enterprise Tempo (GE) is in maintenance mode and is no longer maintained in this
chart. Enterprise templates (`admin-api`, `enterprise-gateway`,
`enterprise-federation-frontend`, `provisioner`, `tokengen`) have been removed. For enterprise deployments, use the
[grafana/helm-charts](https://github.com/grafana/helm-charts) repository.

### Config migration tool

The `tempo-cli migrate config` command converts a Tempo 2.x config file to 3.0
format — it removes the `ingester`, `compactor`, and `metrics_generator_client`
blocks and adds the `ingest:` block:

```bash
tempo-cli migrate config \
  --kafka-address=<KAFKA_BROKER_ADDRESS> \
  --kafka-topic=<KAFKA_TOPIC> \
  old-config.yaml > new-config.yaml
```

Review the output before deploying. For the full list of options see the
[Tempo CLI reference](https://grafana.com/docs/tempo/latest/operations/tempo_cli/#migrate-config-command).

### Architecture changes

| Component | Status in 3.0 |
|-----------|--------------|
| ingester | Removed |
| compactor | Removed (replaced by backend-scheduler + backend-worker) |
| block-builder | **New** — consumes from Kafka, writes blocks to object storage |
| live-store | **New** — consumes from Kafka, serves recent-data queries |
| backend-scheduler | Already in chart, now required |
| backend-worker | Already in chart, now required |
| distributor | Unchanged — now writes to Kafka instead of ingesters |
| querier, query-frontend | Unchanged |

For a detailed explanation of the new architecture see the
[Tempo documentation](https://grafana.com/docs/tempo/latest/introduction/architecture/).

### Prerequisites

- A running **Kafka-compatible broker** reachable from the cluster
  (Apache Kafka, Redpanda, WarpStream, etc.). Kafka is not bundled in this chart.
- Block format **vParquet4 or later** in your existing deployment. If you are on
  an older format, upgrade the block format before migrating.
- Review the upstream
  [Migrate from Tempo 2.x to 3.0](https://grafana.com/docs/tempo/latest/set-up-for-tracing/setup-tempo/upgrade/)
  guide for detailed steps including the parallel-deployment migration path.

### Required values changes

```yaml
# Disable the ingester (removed in Tempo 3.0)
ingester:
  enabled: false

# Enable the new write path
backendScheduler:
  enabled: true

blockBuilder:
  enabled: true
  # replica count must equal your Kafka partition count
  replicas: 3

liveStore:
  enabled: true
  # replica count must equal your Kafka partition count
  replicas: 3

# Point Tempo at your Kafka broker
ingest:
  kafka:
    address: "<kafka-broker>:9092"
    topic: tempo-traces
    auto_create_topic_enabled: true
    auto_create_topic_default_partitions: 3
```

### Migration path

Grafana recommends a **parallel-deployment** migration: run Tempo 2.x and 3.0
side by side pointing at the same object storage, switch traffic, then
decommission 2.x. See the upstream migration guide for detailed steps.

During the parallel period, disable compaction in the 3.0 deployment so only
one compaction system writes to shared storage:

```yaml
overrides:
  defaults:
    compaction:
      compaction_disabled: true
```

Remove this override after the 2.x deployment is decommissioned.

### Block-builder and live-store replica count

Both block-builder and live-store must have exactly **one replica per Kafka
partition**. If you use `ingest.kafka.auto_create_topic_enabled: true`, set
`ingest.kafka.auto_create_topic_default_partitions` to the desired partition
count and set `blockBuilder.replicas` and `liveStore.replicas` to match.

### Legacy overrides format

Tempo 3.0 disables the legacy flat overrides format by default. If your
deployment uses it, add `enable_legacy_overrides: true` to the `overrides`
block temporarily and migrate using
`tempo-cli migrate overrides-config`. See the
[overrides configuration reference](https://grafana.com/docs/tempo/latest/configuration/#overrides).

### dnsConfigOverides removed

The misspelled, per-component `dnsConfigOverides` key (`backendScheduler`,
`backendWorker`) is removed. Use the plain `dnsConfig` key instead, either
per component or chart-wide via `defaults.dnsConfig` / `tempo.dnsConfig`:

```yaml
# Before
backendScheduler:
  dnsConfigOverides:
    enabled: true
    dnsConfig:
      options:
        - name: ndots
          value: "3"

# After
backendScheduler:
  dnsConfig:
    options:
      - name: ndots
        value: "3"
```

### Built-in MinIO subchart removed

The built-in MinIO subchart is gone. The `minio` value is no longer a chart
dependency, and setting `minio.enabled: true` now fails the render with a
message pointing here. Tempo must be configured against an externally managed
S3-compatible object store via `storage.trace.s3`.

If you never used the built-in MinIO (the default was `minio.enabled: false`),
just delete any leftover `minio:` block from your values and upgrade.

#### Keeping your existing built-in MinIO running

If you relied on `minio.enabled: true`, a plain `helm upgrade` would garbage
collect the MinIO `Deployment`, `Service`, `Secret`, and **`PersistentVolumeClaim`**,
because they are no longer part of the rendered release; that destroys your trace
data along with them.

To upgrade without losing the running MinIO, detach those objects from the Helm
release first, the same idea as `kubectl delete --cascade=orphan`. Annotate them
with `helm.sh/resource-policy: keep` *before* upgrading. Helm then skips deleting
anything carrying that annotation when it disappears from the manifest, leaving
MinIO running as a now-unmanaged deployment with its PVC and data intact.

```bash
# RELEASE and NAMESPACE are your existing tempo-distributed install.
for kind in deployment service secret pvc serviceaccount; do
  kubectl -n "$NAMESPACE" annotate "$kind" \
    -l app=minio,release="$RELEASE" \
    helm.sh/resource-policy=keep --overwrite
done
```

Verify the annotation landed on every MinIO object (especially the PVC) before
proceeding:

```bash
kubectl -n "$NAMESPACE" get deploy,svc,secret,pvc,sa -l app=minio,release="$RELEASE" \
  -o jsonpath='{range .items[*]}{.kind}/{.metadata.name}: {.metadata.annotations.helm\.sh/resource-policy}{"\n"}{end}'
```

Then remove the `minio:` block from your values, point Tempo at the surviving
MinIO Service, and upgrade:

```yaml
storage:
  trace:
    backend: s3
    s3:
      bucket: tempo-traces
      # Service kept from the old subchart, e.g. <release>-minio.<namespace>.svc:9000
      endpoint: <release>-minio.<namespace>.svc.cluster.local:9000
      access_key: <key>
      secret_key: <secret>
      insecure: true   # drop once TLS is configured
```

The orphaned MinIO is no longer upgraded or reconfigured by this chart. Migrate
to a dedicated MinIO release (`helm install minio minio/minio`) or another
S3-compatible store when convenient; the data lives in the retained PVC and can
be re-mounted or copied out with `mc mirror`.

#### Migrating to a fresh external store instead

If you would rather start clean on external storage, deploy MinIO (or any
S3-compatible store) separately and configure `storage.trace.s3` as above. Old
blocks in the previous bucket can be backfilled with `mc mirror` or
`tempo-cli` if you need to retain history.

### Removed config fields

The following fields are no longer emitted in `tempo.yaml`:

- `ingester.*`
- `ingester_client.*`
- `compactor.*` (when `backendScheduler.enabled: true`)
- `metrics_generator_client.*`

Remove any corresponding overrides from your values files.
