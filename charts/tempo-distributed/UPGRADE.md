# Upgrade guide

## v2.x → v3.0 (Tempo 3.0)

Tempo 3.0 replaces the ingester-based write path with a Kafka-backed architecture.
This is a **breaking change** for microservices-mode deployments.

### Grafana Enterprise Tempo

Enterprise Tempo (GE) is in maintenance mode and is no longer maintained in this
chart. Enterprise templates (`admin-api`, `enterprise-gateway`, `provisioner`,
`tokengen`) have been removed. For enterprise deployments, use the
[grafana/helm-charts](https://github.com/grafana/helm-charts) repository.

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

### Removed config fields

The following fields are no longer emitted in `tempo.yaml`:

- `ingester.*`
- `ingester_client.*`
- `compactor.*` (when `backendScheduler.enabled: true`)
- `metrics_generator_client.*`

Remove any corresponding overrides from your values files.
