# Loki Chart — Key Parameters

This file provides Loki-specific context.

## Deployment Modes

`deploymentMode` is the single most important value in the chart. It controls which component groups render and whether object storage is required.

| Value | Components rendered | Object storage required |
|---|---|---|
| `SingleBinary` | `single-binary/` only | No — filesystem storage is sufficient |
| `SimpleScalable` *(default)* | `read/`, `write/`, `backend/` | Yes |
| `Distributed` | All microservices (distributor, ingester, querier, query-frontend, query-scheduler, compactor, index-gateway, ruler, …) | Yes |
| `SingleBinary<->SimpleScalable` | Both single-binary AND simple scalable | Transition mode — migration path |
| `SimpleScalable<->Distributed` | Both simple scalable AND distributed | Transition mode — migration path |

`validate.yaml` enforces these constraints and will fail rendering if they are violated.

## Deployment Mode Helpers

Three helpers in `templates/_helpers.tpl` gate which components render — understand these before writing tests:

- **`loki.deployment.isSingleBinary`** — true for `SingleBinary` and `SingleBinary<->SimpleScalable`
- **`loki.deployment.isScalable`** — true for `SimpleScalable`, `SingleBinary<->SimpleScalable`, and `SimpleScalable<->Distributed` (requires object storage)
- **`loki.deployment.isDistributed`** — true for `Distributed` and `SimpleScalable<->Distributed` (requires object storage)

When writing tests for a component, always set `deploymentMode` explicitly rather than relying on the default, and provide the minimum storage config required by that mode.

### Minimum values for SimpleScalable tests

```yaml
set:
  deploymentMode: SimpleScalable
  loki.storage.type: s3
  loki.storage.bucketNames.chunks: chunks
  loki.storage.bucketNames.ruler: ruler
  loki.storage.bucketNames.admin: admin
```

### Minimum values for Distributed tests

```yaml
set:
  deploymentMode: Distributed
  loki.storage.type: s3
  loki.storage.bucketNames.chunks: chunks
  loki.storage.bucketNames.ruler: ruler
  loki.storage.bucketNames.admin: admin
```

## Major Component Enable Flags

These flags control entire subsystems independently of `deploymentMode`:

| Value | Default | Controls |
|---|---|---|
| `gateway.enabled` | `true` | nginx API gateway deployment |
| `ruler.enabled` | `false` | Ruler statefulset (log alerting) |
| `chunksCache.enabled` | `false` | Memcached for chunk caching |
| `resultsCache.enabled` | `false` | Memcached for query results |
| `overridesExporter.enabled` | `false` | Overrides exporter deployment |
| `tableManager.enabled` | `false` | Table manager deployment |
| `bloomGateway.enabled` | `false` | Bloom filter gateway |
| `bloomPlanner.enabled` | `false` | Bloom filter planner |
| `bloomBuilder.enabled` | `false` | Bloom filter builder |
| `patternIngester.enabled` | `false` | Pattern ingester statefulset |
| `lokiCanary.enabled` | `false` | Canary daemonset |
| `monitoring.serviceMonitor.enabled` | `false` | ServiceMonitor resource |
| `monitoring.dashboards.enabled` | `false` | Dashboard ConfigMaps |

## Naming Helpers

All resource names flow through helpers in `templates/_helpers.tpl`. The key ones:

- **`loki.fullname`** — base name for most resources (e.g. `RELEASE-NAME-loki`)
- **`loki.resourceName`** — parameterised name with optional component, zone, and suffix
- Per-component helpers (e.g. `loki.distributorFullname`, `loki.ingesterFullname`) — defined in each component's `_helpers-<component>.tpl`

## Template Organization

Templates are organized by component under `templates/<component>/`. Each component directory typically contains:
- The primary workload (`deployment.yaml` or `statefulset-<component>.yaml`)
- `service.yaml`
- `poddisruptionbudget-<component>.yaml`
- `hpa.yaml` (for scalable components)
- `_helpers-<component>.tpl` (component-scoped helpers)

Cross-cutting templates live at the root of `templates/`: RBAC, config, networkpolicy, ingress, monitoring.
