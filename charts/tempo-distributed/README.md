# tempo-distributed Helm Chart

Grafana Tempo in MicroService mode

## Source Code

* <https://github.com/grafana/tempo>

## Requirements

Kubernetes: `^1.25.0-0`

| Repository | Name | Version |
|------------|------|---------|
| https://grafana.github.io/helm-charts | grafana-agent-operator | 0.5.2 |
| https://grafana.github.io/helm-charts | rollout_operator | 0.43.0 |

## Installing the Chart

### OCI Registry

OCI registries are preferred in Helm as they implement unified storage, distribution, and improved security.

```console
helm install RELEASE-NAME oci://ghcr.io/grafana-community/helm-charts/tempo-distributed
```

### HTTP Registry

```console
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo update
helm install RELEASE-NAME grafana-community/tempo-distributed
```

## Uninstalling the Chart

To remove all of the Kubernetes objects associated with the Helm chart release:

```console
helm delete RELEASE-NAME
```

## Changelog

See the [changelog](https://grafana-community.github.io/helm-charts/changelog/?chart=tempo-distributed).

---

## Upgrading

A major chart version change indicates that there is an incompatible breaking change needing manual actions.

### MinIO subchart removed

The built-in MinIO subchart has been removed in chart v3.0.0. `minio` is no longer a chart
dependency, and setting `minio.enabled: true` fails the render. Tempo must point at an
externally managed S3-compatible object store via `storage.trace.s3`:

```yaml
storage:
  trace:
    backend: s3
    s3:
      bucket: tempo-traces
      endpoint: minio.minio-namespace.svc.cluster.local:9000
      access_key: <access-key>
      secret_key: <secret-key>
      insecure: true  # remove if TLS is configured
```

If you previously used the built-in subchart, do **not** run a plain `helm upgrade`: it
would garbage collect the MinIO Deployment, Service, Secret, and PVC and destroy your trace
data. Detach those objects from the release first (annotate them with
`helm.sh/resource-policy: keep`, the Helm equivalent of `kubectl delete --cascade=orphan`),
then repoint `storage.trace.s3` at the surviving MinIO Service. See [`UPGRADE.md`](./UPGRADE.md)
for the full procedure.

### From Chart versions < 2.17.10

Version 2.17.10 change the memcached Services and Statefulsets spec.
These changes cannot be done by patching the resources, causing an existing installation not to be upgradable without manual interaction.

An upgrade will fail with a message like:
```
Error: UPGRADE FAILED: Service "tempo-memcached" is invalid: spec.clusterIPs[0]: Invalid value: ["None"]: may not change once set && StatefulSet.apps "tempo-memcached" is invalid: spec: Forbidden: updates to statefulset spec for fields other than 'replicas', 'ordinals', 'template', 'updateStrategy', 'revisionHistoryLimit', 'persistentVolumeClaimRetentionPolicy' and 'minReadySeconds' are forbidden
````

There are basically two options:

#### Option 1
Uninstall the old release and re-install the new one.

#### Option 2
Delete the affected Services and Statefulsets, and re-install the new ones.

```
kubectl -n <namespace> delete service --selector 'app.kubernetes.io/instance=<instance-name>,app.kubernetes.io/component in (memcached,memcached-bloom,memcached-parquet-footer,memcached-frontend-search)'
```

Perform a non-cascading deletion of the Statefulsets which will keep the pods running:

```
kubectl -n <namespace> delete statefulset --selector 'app.kubernetes.io/instance=<instance-name>,app.kubernetes.io/component in (memcached,memcached-bloom,memcached-parquet-footer,memcached-frontend-search)' --cascade=orphan
```

Perform a regular Helm upgrade on the existing release. The new Statefulsets will pick up the existing pods and perform a rolling upgrade.

### From Chart versions < 3.0.0

Tempo 3.0 replaces the ingester-based write path with a Kafka-backed architecture. This is a breaking change for microservices-mode deployments.

See [UPGRADE.md](UPGRADE.md) for the full migration guide, including the parallel-deployment path, Kafka configuration, and the `tempo-cli migrate config` command.

### From Chart versions < 2.0.0

The minimum required Kubernetes version is now 1.25. All references to deprecated APIs have been removed.

### From Chart versions < 1.48.1

Please be aware that we've updated the Tempo version to 2.9, which includes some breaking changes
We recommend reviewing the [release notes](https://github.com/grafana/tempo/releases/tag/v2.9.0) before upgrading.

### From Chart versions < 1.41.2

Please be aware that we've updated the Tempo version to 2.8, which includes some breaking changes
We recommend reviewing the [release notes](https://github.com/grafana/tempo/releases/tag/v2.8.0) before upgrading.

### From Chart versions < 1.41.0

* Breaking Change *
In order to be consistent with other projects and documentations, the default port has been changed from 3100 to 3200.

### From Chart versions < 1.33.0

* Breaking Change *
In order to reduce confusion, the overrides configurations have been renamed as below.

`global_overrides` =>  `overrides` (this is where the defaults for every tenant is set)
`overrides` => `per_tenant_overrides` (this is where configurations for specific tenants can be set)

### From Chart versions < 1.31.0

Tempo serverless was deprecated in [tempo 2.7 release](https://github.com/grafana/tempo/releases/tag/v2.7.0),
Config options related to serverless are being removed from helm chart, and this might be a breaking change if you were using tempo serverless.

These config optioons are removed in [tempo#4599](https://github.com/grafana/tempo/pull/4599) and will not work from next release of tempo.

### From Chart versions < 1.28.2

Please be aware that we've updated the Tempo version to 2.7, which includes some breaking changes
We recommend reviewing the [release notes](https://grafana.com/docs/tempo/latest/release-notes/v2-7/) before upgrading.

### From Chart versions < 1.23.0

A default affinity has been defined in this version for the compactor following the standard used in other components.

### From Chart versions < 1.21.0

Upgrading to chart 1.21.0 will set the memberlist cluster_label config option. During rollout your cluster will temporarily be split into two memberlist clusters until all components are rolled out.
This will interrupt reads and writes. This config option is set to prevent cross talk between Tempo and other memberlist clusters.

### From Chart versions < 1.18.0

Please be aware that we've updated the minor version to Tempo 2.6, which includes breaking changes.
We recommend reviewing the [release notes](https://github.com/grafana/tempo/releases/tag/v2.6.0/) before upgrading.

### From Chart versions < 1.15.2

Switch to new overrides format, see https://grafana.com/docs/tempo/latest/configuration/#overrides.

### From Chart versions < 1.13.0

EXPERIMENTAL: Zone Aware Replication has been added to the ingester statefulset.
Attention, the calculation of the pods per AZ is as follows ```(.values.ingester.replicas + numberOfZones -1)/numberOfZones```

### From Chart versions < 1.6.0

The metrics generator component in the chart has been disabled by default, but the configuration for the processors was not empty, resulting error sin the distributor log.  Here we align the default metrics generator config settings to both disable the generator and remove processors.  Users who wish to keep the their processors enabled, will need to update their values.

### From Chart versions < 1.5.0

Please be aware that we've updated the minor version to Tempo 2.2, which includes breaking changes.
We recommend reviewing the [release notes](https://github.com/grafana/tempo/releases/tag/v2.2.0) before upgrading.

### From Chart versions < 1.3.0

Please be aware that we've updated the minor version to Tempo 2.1, which includes breaking changes.
We recommend reviewing the [release notes](https://github.com/grafana/tempo/releases/tag/v2.1.0/) before upgrading.

### From Chart versions < 1.0.0

Please note that we've incremented the major version when upgrading to Tempo 2.0. There were a large number of
changes in this release (breaking and otherwise). It is encouraged to review the [release notes](https://grafana.com/docs/tempo/latest/release-notes/v2-0/)
and [1.5 -> 2.0 upgrade guide](https://grafana.com/docs/tempo/latest/setup/upgrade/) before upgrading.

### From chart version < 0.27.0

Version 0.27.0:

Many changes have been introduced, including some breaking changes.

The [PR](https://github.com/grafana/helm-charts/pull/1759) includes additional details.

* **BREAKING CHANGE** centralize selector label handling -- users who wish to keep old values should still be able to use the `nameOverride` and `fullNameOverride` top level keys in their values.

* **BREAKING CHANGE** serviceMonitor has been nested under metaMonitoring -- metamonitoring can be used scrape services as well as install the operator with the following values.  Note also that the port names have changed from `http` to `http-metrics`.
```yaml
metaMonitoring:
  serviceMonitor:
    enabled: true
  grafanaAgent:
    enabled: true
    installOperator: true
```
* allow configuration to be stored in a secret.  See the documentation for `useExternalConfig` and `configStorageType` in the values file for more details.

### From chart version < 0.26.0

Version 0.26.0

* Moves metricsGenerator.config.storage_remote_write to metricsGenerator.config.storage.remote_write
* Moves metricsGenerator.config.service_graphs_max_items to metricsGenerator.config.processor.service_graphs.max_items

### From chart version < 0.23.0

Version 0.23.0:

* Adds /var/tempo emptyDir mount for querier, queryfrontend, distributor and compactor. Previously, /var/tempo was directory inside container.

* Sets queryFrontend.query.enabled to false. tempo-query is only required for grafana version <7.5 for compatibility with jaeger-ui. Please also note that tempo-query is incompatible with securityContext readOnlyRootFilesystem set to true.

* Sets stricter default securityContext:
```yaml
tempo:
  securityContext:
    capabilities:
      drop:
        - ALL
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    allowPrivilegeEscalation: false
  podSecurityContext:
    fsGroup: 1000
```
If you had ingester persistence enabled, you might need to manually change ownership of files in your PV if your CSI doesn't support fsGroup

### From Chart version >= 0.22.0
Align Istio gRPC named port syntax. For example,

- otlp-grpc               -> grpc-otlp
- distributor-otlp-grpc   -> grpc-distributor-otlp
- jaeger-grpc             -> grpc-jaeger
- distributor-jaeger-grpc -> grpc-distributor-jaeger

In case you need to rollback, please search the right hand side pattern and replace with left hand side pattern.

### From Chart version < 0.20.0
The image's attributes must be set under the `image` key for the Memcached service.
```yaml
memcached:
  image:
    registry: docker.io
    repository: memcached
    tag: "1.5.17-alpine"
    pullPolicy: "IfNotPresent"
```

### From Chart version < 0.18.0
Trace ingestion must now be enabled with the `enabled` key:
```yaml
traces:
  otlp:
    grpc:
      enabled: true
    http:
      enabled: true
  zipkin:
    enabled: true
  jaeger:
    thriftHttp:
      enabled: true
  opencensus:
    enabled: true
```

### From Chart versions < 0.9.0

This release the component label was shortened to be more aligned with the Loki-distributed chart and the [mixin](https://github.com/grafana/tempo/tree/master/operations/tempo-mixin) dashboards.

Due to the label changes, an existing installation cannot be upgraded without manual interaction. There are basically two options:

Option 1
Uninstall the old release and re-install the new one. There will be no data loss, as the collectors/agents can cache for a short period.

Option 2
Add new selector labels to the existing pods. This option will make your pods also temporarily unavailable, option 1 is faster:

```
kubectl label pod -n <namespace> -l app.kubernetes.io/component=<release-name>-tempo-distributed-<component>,app.kubernetes.io/instance=<instance-name> app.kubernetes.io/component=<component> --overwrite
```

Perform a non-cascading deletion of the Deployments and Statefulsets which will keep the pods running:

```
kubectl delete <deployment/statefulset> -n <namespace> -l app.kubernetes.io/component=<release-name>-tempo-distributed-<component>,app.kubernetes.io/instance=<instance-name> --cascade=false
```

Perform a regular Helm upgrade on the existing release. The new Deployment/Statefulset will pick up the existing pods and perform a rolling upgrade.

### From Chart versions < 0.8.0

By default all tracing protocols are disabled and you need to specify which protocols to enable for ingestion.

For example to enable Jaeger gRPC thrift http and zipkin protocols:
```yaml
traces:
  jaeger:
    grpc: true
    thriftHttp: true
  zipkin: true
```

The distributor service is now called {{tempo.fullname}}-distributor. That could impact your ingestion towards this service.

### From Chart Versions < 0.7.0

The memcached default args are removed and should be provided manually. The settings for the `memcached.exporter` moved to `memcachedExporter`

## Components

The chart supports the components shown in the following table.
Distributor, querier, and query-frontend are always installed.
The other components are optional and must be explicitly enabled.

| Component | Optional | Notes |
| --- | --- | --- |
| distributor | no | Writes spans to Kafka in Tempo 3.0 |
| querier | no | |
| query-frontend | no | |
| backend-scheduler | yes (`backendScheduler.enabled`) | Required for compaction and retention |
| backend-worker | yes (enabled with backend-scheduler) | Executes compaction jobs |
| block-builder | yes (`blockBuilder.enabled`) | Consumes from Kafka, writes blocks to object storage |
| live-store | yes (`liveStore.enabled`) | Consumes from Kafka, serves recent-data queries |
| metrics-generator | yes | |
| memcached | yes | |
| memcached-exporter | yes | |
| gateway | yes | |
| rollout-operator | yes | |

## [Configuration](https://grafana.com/docs/tempo/latest/configuration/)

This chart configures Tempo in microservices mode.

Refer to the [Get started with Grafana Tempo using the Helm chart](https://grafana.com/docs/helm-charts/tempo-distributed/next/get-started-helm-charts/) documentation for more details.

**NOTE:**
In its default configuration, the chart uses `local` filesystem as storage.
The reason for this is that the chart can be validated and installed in a CI pipeline.
However, this setup is not fully functional.
The recommendation is to use object storage, such as S3, GCS, MinIO, etc., or one of the other options documented at https://grafana.com/docs/tempo/latest/configuration/#storage.

Alternatively, in order to quickly test Tempo using the filestore, the [single binary chart](https://github.com/grafana-community/helm-charts/tree/main/charts/tempo) can be used.

### Overriding configuration variables with structuredConfig

tempo.structuredConfig variable can be used to alter individual values in the configuration and it's structured YAML instead of text. It takes precedence over all other variable adjustments inside tempo.yaml config file, ie s3 storage settings.

Example:

```yaml
tempo:
  structuredConfig:
    query_frontend:
      search:
        max_duration: 12h0m0s
```

### Activate metrics generator

Metrics-generator is disabled by default and can be activated by configuring the following values:

```yaml
metricsGenerator:
  enabled: true
  config:
    storage:
      remote_write:
      - url: http://cortex/api/v1/push
        send_exemplars: true
    #   headers:
    #     x-scope-orgid: operations
# Global overrides
global_overrides:
  defaults:
    metrics_generator:
      processors:
        - service-graphs
        - span-metrics
```

----

### Directory and File Locations

* Volumes are mounted to `/var/tempo`. The various directories Tempo needs should be configured as subdirectories (e. g. `/var/tempo/wal`, `/var/tempo/traces`). Tempo will create the directories automatically.
* The config file is mounted to `/conf/tempo-query.yaml` and passed as CLI arg.

### Example configuration using S3 for storage

```yaml
storage:
  trace:
    backend: s3
    s3:
      access_key: tempo
      bucket: <your-s3-bucket>
      endpoint: s3.amazonaws.com
      secret_key: <your-secret>
    wal:
      path: /var/tempo/wal

ingest:
  kafka:
    address: <kafka-broker>:9092
    topic: tempo-traces

blockBuilder:
  enabled: true
  replicas: 3  # must equal Kafka partition count

liveStore:
  enabled: true
  replicas: 3  # must equal Kafka partition count

backendScheduler:
  enabled: true

traces:
  otlp:
    http:
      enabled: true
    grpc:
      enabled: true
```

### Kafka SASL Authentication

Tempo 3.0 requires Kafka for the write path. The chart supports secure authentication using SASL.

> **Security Best Practice**: Use file-based credentials (mounted from Secrets) whenever possible to keep credentials out of the rendered configuration. File paths are supported for OAUTHBEARER and AWS_MSK_IAM mechanisms.

#### SCRAM-SHA-512 Authentication (Recommended for Most Deployments)

SCRAM-SHA-512 provides strong authentication with salted challenge-response.

> **Note**: SCRAM mechanisms require direct credentials in the configuration. Use `configStorageType: Secret` to store the entire `tempo.yaml` in a Kubernetes Secret instead of a ConfigMap.

**Step 1: Configure SCRAM with Secret storage**

```yaml
# Store tempo.yaml in a Secret (not ConfigMap)
configStorageType: Secret

ingest:
  kafka:
    address: kafka.kafka.svc.cluster.local:9092
    topic: tempo-spans
    sasl:
      mechanism: SCRAM-SHA-512
      username: tempo-production-user
      password: your-secure-password
    tls:
      enabled: true
      caPath: /etc/kafka/tls/ca.crt

# Mount TLS CA certificate in all Kafka-accessing components
distributor:
  extraVolumes:
    - name: kafka-tls-ca
      secret:
        secretName: kafka-tls-ca
        defaultMode: 0400
  extraVolumeMounts:
    - name: kafka-tls-ca
      mountPath: /etc/kafka/tls
      readOnly: true

blockBuilder:
  enabled: true
  replicas: 3
  extraVolumes:
    - name: kafka-tls-ca
      secret:
        secretName: kafka-tls-ca
        defaultMode: 0400
  extraVolumeMounts:
    - name: kafka-tls-ca
      mountPath: /etc/kafka/tls
      readOnly: true

liveStore:
  enabled: true
  replicas: 3
  extraVolumes:
    - name: kafka-tls-ca
      secret:
        secretName: kafka-tls-ca
        defaultMode: 0400
  extraVolumeMounts:
    - name: kafka-tls-ca
      mountPath: /etc/kafka/tls
      readOnly: true

backendScheduler:
  enabled: true
```

**Step 2: Verify the setup**

```bash
# Verify tempo.yaml is stored in a Secret (not ConfigMap)
kubectl get secret tempo-config -n tempo -o yaml

# Check Kafka connection in logs
kubectl logs -n tempo tempo-block-builder-0 | grep -i kafka
```

**Security notes**:
- ✅ Credentials stored in Kubernetes Secret (encrypted at rest if cluster encryption enabled)
- ✅ TLS encrypts credentials in transit
- ✅ RBAC can restrict Secret access
- ⚠️ Credential rotation requires Helm upgrade and pod restart

#### OAUTHBEARER Authentication

OAuth 2.0 bearer token authentication for Kafka. **Use file-based credentials** to keep tokens out of the configuration and enable rotation without Helm upgrades.

**Step 1: Create a Secret with your OAuth token**

```bash
# Create token.json file
cat > token.json <<EOF
{
  "token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_at": "2026-12-31T23:59:59Z"
}
EOF

kubectl create secret generic kafka-oauth-token \
  --from-file=token.json=token.json \
  --namespace tempo

# Clean up local file
rm token.json
```

**Step 2: Configure Helm values with file path**

```yaml
ingest:
  kafka:
    address: kafka.kafka.svc.cluster.local:9092
    topic: tempo-spans
    sasl:
      mechanism: OAUTHBEARER
      oauthbearer:
        # Use file path (recommended) - token is read from mounted Secret
        filePath: /etc/kafka/oauth/token.json
        zid: "tempo-service"  # Optional authorization ID
    tls:
      enabled: true

# Mount OAuth token in all Kafka-accessing components
distributor:
  extraVolumes:
    - name: kafka-oauth-token
      secret:
        secretName: kafka-oauth-token
        defaultMode: 0400
  extraVolumeMounts:
    - name: kafka-oauth-token
      mountPath: /etc/kafka/oauth
      readOnly: true

blockBuilder:
  enabled: true
  replicas: 3
  extraVolumes:
    - name: kafka-oauth-token
      secret:
        secretName: kafka-oauth-token
        defaultMode: 0400
  extraVolumeMounts:
    - name: kafka-oauth-token
      mountPath: /etc/kafka/oauth
      readOnly: true

liveStore:
  enabled: true
  replicas: 3
  extraVolumes:
    - name: kafka-oauth-token
      secret:
        secretName: kafka-oauth-token
        defaultMode: 0400
  extraVolumeMounts:
    - name: kafka-oauth-token
      mountPath: /etc/kafka/oauth
      readOnly: true
```

**Step 3: Verify the setup**

```bash
# Check that token file is mounted correctly
kubectl exec -n tempo tempo-block-builder-0 -- ls -la /etc/kafka/oauth/
# Should show: token.json (mode 0400)

# Verify tempo.yaml references file path (not actual token)
kubectl exec -n tempo tempo-block-builder-0 -- grep oauthbearer /conf/tempo.yaml
# Should show:
#   sasl_mechanism: OAUTHBEARER
#   sasl_oauthbearer_file_path: /etc/kafka/oauth/token.json

# Check Kafka connection in logs
kubectl logs -n tempo tempo-block-builder-0 | grep -i kafka
```

**Token rotation**:

```bash
# Update the Secret with a new token
kubectl create secret generic kafka-oauth-token \
  --from-file=token.json=new-token.json \
  --namespace tempo \
  --dry-run=client -o yaml | kubectl apply -f -

# Tempo will read the new token on next authentication (no restart needed)
```

**Security benefits**:
- ✅ Token stored in Kubernetes Secret (not in tempo.yaml)
- ✅ Token file re-read on each authentication
- ✅ Supports token rotation without Helm upgrade or pod restart
- ✅ Token never appears in rendered configuration

#### AWS MSK IAM Authentication

For AWS MSK (Managed Streaming for Kafka) with IAM authentication. **Three methods are supported, in order of security preference:**

##### Method 1: IRSA (IAM Roles for Service Accounts) - Most Secure ✅

No credentials needed - uses AWS IAM roles attached to Kubernetes service accounts.

```yaml
# Enable IRSA on the service account
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/tempo-kafka-role

ingest:
  kafka:
    address: b-1.msk-cluster.kafka.us-east-1.amazonaws.com:9098
    topic: tempo-spans
    sasl:
      mechanism: AWS_MSK_IAM
      mskIam:
        # No credentials needed - uses IRSA
        userAgent: "tempo-distributed"

# No extraVolumes needed - credentials from IRSA
```

**Security benefits**:
- ✅ No credentials to manage or rotate
- ✅ IAM policies control access
- ✅ Credentials automatically rotated by AWS
- ✅ Audit trail via CloudTrail

##### Method 2: File-Based Credentials - Recommended if IRSA Not Available ✅

Use a file to store AWS credentials. This allows rotation without Helm upgrades.

**Step 1: Create credentials Secret**

```bash
# Create credentials.json file
cat > credentials.json <<EOF
{
  "AccessKey": "AKIAIOSFODNN7EXAMPLE",
  "SecretKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
  "Region": "us-east-1"
}
EOF

kubectl create secret generic kafka-aws-credentials \
  --from-file=credentials.json=credentials.json \
  --namespace tempo

# Clean up local file
rm credentials.json
```

**Step 2: Configure Helm values with file path**

```yaml
ingest:
  kafka:
    address: b-1.msk-cluster.kafka.us-east-1.amazonaws.com:9098
    topic: tempo-spans
    sasl:
      mechanism: AWS_MSK_IAM
      mskIam:
        # Use file path (recommended) - credentials read from mounted Secret
        filePath: /etc/kafka/aws/credentials.json
        userAgent: "tempo-distributed"

# Mount AWS credentials in all Kafka-accessing components
distributor:
  extraVolumes:
    - name: kafka-aws-credentials
      secret:
        secretName: kafka-aws-credentials
        defaultMode: 0400
  extraVolumeMounts:
    - name: kafka-aws-credentials
      mountPath: /etc/kafka/aws
      readOnly: true

blockBuilder:
  enabled: true
  replicas: 3
  extraVolumes:
    - name: kafka-aws-credentials
      secret:
        secretName: kafka-aws-credentials
        defaultMode: 0400
  extraVolumeMounts:
    - name: kafka-aws-credentials
      mountPath: /etc/kafka/aws
      readOnly: true

liveStore:
  enabled: true
  replicas: 3
  extraVolumes:
    - name: kafka-aws-credentials
      secret:
        secretName: kafka-aws-credentials
        defaultMode: 0400
  extraVolumeMounts:
    - name: kafka-aws-credentials
      mountPath: /etc/kafka/aws
      readOnly: true
```

**Step 3: Verify the setup**

```bash
# Check that credentials file is mounted correctly
kubectl exec -n tempo tempo-block-builder-0 -- ls -la /etc/kafka/aws/
# Should show: credentials.json (mode 0400)

# Verify tempo.yaml references file path (not actual credentials)
kubectl exec -n tempo tempo-block-builder-0 -- grep msk_iam /conf/tempo.yaml
# Should show:
#   sasl_mechanism: AWS_MSK_IAM
#   sasl_msk_iam_file_path: /etc/kafka/aws/credentials.json

# Check Kafka connection in logs
kubectl logs -n tempo tempo-block-builder-0 | grep -i kafka
```

**Credential rotation**:

```bash
# Update the Secret with new credentials
kubectl create secret generic kafka-aws-credentials \
  --from-file=credentials.json=new-credentials.json \
  --namespace tempo \
  --dry-run=client -o yaml | kubectl apply -f -

# Tempo will read the new credentials on next authentication (no restart needed)
```

**Security benefits**:
- ✅ Credentials stored in Kubernetes Secret (not in tempo.yaml)
- ✅ Credentials file re-read on each authentication
- ✅ Supports credential rotation without Helm upgrade or pod restart
- ✅ Credentials never appear in rendered configuration

##### Method 3: Direct Credentials - Not Recommended ⚠️

> **Warning**: This method stores AWS credentials directly in `values.yaml` and renders them into `tempo.yaml`. Use `configStorageType: Secret` if you must use this method, but prefer IRSA or file-based credentials instead.

```yaml
configStorageType: Secret  # Required if using direct credentials

ingest:
  kafka:
    address: b-1.msk-cluster.kafka.us-east-1.amazonaws.com:9098
    sasl:
      mechanism: AWS_MSK_IAM
      mskIam:
        accessKey: "AKIAIOSFODNN7EXAMPLE"
        secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        userAgent: "tempo-distributed"
```

**Drawbacks**:
- ❌ Credentials in `values.yaml` (often committed to Git)
- ❌ Requires Helm upgrade to rotate credentials
- ❌ Credentials rendered into configuration
- ❌ Less secure than IRSA or file-based methods

#### Supported SASL Mechanisms

| Mechanism | Security | Use Case | Credential Method | Rotation |
|-----------|----------|----------|-------------------|----------|
| **SCRAM-SHA-512** | ⭐⭐⭐⭐⭐ | Production (recommended) | Direct + `configStorageType: Secret` | Helm upgrade + restart |
| **SCRAM-SHA-256** | ⭐⭐⭐⭐ | Production (legacy) | Direct + `configStorageType: Secret` | Helm upgrade + restart |
| **OAUTHBEARER** | ⭐⭐⭐⭐⭐ | OAuth 2.0 environments | File path (recommended) | Update Secret (no restart) |
| **AWS_MSK_IAM** | ⭐⭐⭐⭐⭐ | AWS MSK | IRSA (best) or file path | Automatic (IRSA) or update Secret |
| **PLAIN** | ⭐⭐ | Development only (with TLS) | Direct + `configStorageType: Secret` | Helm upgrade + restart |

#### Security Best Practices

1. **Credential Storage Hierarchy** (most to least secure):
   - IRSA (AWS MSK only) - No credentials to manage
   - File paths (OAUTHBEARER, AWS_MSK_IAM) - Credentials in Secret, rotation without restart
   - Direct credentials with `configStorageType: Secret` (SCRAM, PLAIN) - Credentials in Secret, requires restart
   - Direct credentials with `configStorageType: ConfigMap` - ❌ Never use for production

2. **Always enable TLS** (`tls.enabled: true`) to encrypt credentials in transit

3. **Use strong passwords** for SCRAM (minimum 16 characters, random)

4. **Restrict Secret access** with Kubernetes RBAC

5. **Never commit credentials to Git** - use external secret management (e.g., Sealed Secrets, External Secrets Operator, Vault)

6. **Rotate credentials regularly**:
   - IRSA: Automatic rotation by AWS
   - File paths: Update Secret, Tempo reloads automatically
   - Direct credentials: Update values, Helm upgrade, restart pods

#### Troubleshooting

**SCRAM authentication fails**:
```bash
# Check that tempo.yaml is in a Secret
kubectl get secret tempo-config -n tempo

# Verify credentials in tempo.yaml
kubectl get secret tempo-config -n tempo -o jsonpath='{.data.tempo\.yaml}' | base64 -d | grep sasl
```

**OAUTHBEARER/MSK_IAM file not found**:
```bash
# Check volume is mounted
kubectl exec -n tempo tempo-block-builder-0 -- ls -la /etc/kafka/oauth/
kubectl exec -n tempo tempo-block-builder-0 -- ls -la /etc/kafka/aws/

# Check Secret exists
kubectl get secret kafka-oauth-token -n tempo
kubectl get secret kafka-aws-credentials -n tempo

# Verify file path in tempo.yaml
kubectl exec -n tempo tempo-block-builder-0 -- grep file_path /conf/tempo.yaml
```

**IRSA not working**:
```bash
# Check service account annotation
kubectl get sa tempo -n tempo -o yaml | grep eks.amazonaws.com/role-arn

# Check pod has correct service account
kubectl get pod tempo-block-builder-0 -n tempo -o yaml | grep serviceAccountName

# Verify IAM role trust policy allows the service account
aws iam get-role --role-name tempo-kafka-role
```

### Memcached cache configuration

By default, the chart deploys a single shared memcached StatefulSet (`memcached`) used for all cache roles — bloom filters, parquet footer, and frontend search. This is the simplest setup and works well for most deployments.

#### Default: single shared cache

```yaml
memcached:
  enabled: true
```

All cache roles (bloom, parquet footer, frontend search) point at the same `<release>-memcached` service.

#### Separate one cache role

You can deploy a dedicated memcached cluster for a specific role by enabling the corresponding per-role section. The shared `memcached` cluster remains active for the other roles.

For example, to give bloom filters their own cluster while keeping the rest on the shared one:

```yaml
memcachedBloom:
  enabled: true
  replicas: 2
```

Available per-role sections:

| Key | Cache role |
| --- | --- |
| `memcachedBloom` | Bloom filter cache |
| `memcachedParquetFooter` | Parquet footer cache |
| `memcachedFrontendSearch` | Frontend search cache |

#### Fully isolated caches per role

To run a dedicated memcached cluster for every cache role, disable the shared cluster and enable all three per-role clusters:

```yaml
memcached:
  enabled: false

memcachedBloom:
  enabled: true
  replicas: 2

memcachedParquetFooter:
  enabled: true
  replicas: 2

memcachedFrontendSearch:
  enabled: true
  replicas: 2
```

Each role gets its own StatefulSet and Service, and Tempo is configured to use the matching host for every cache type.

### Enabling gRPC Open Telemetry

gRPC for Open Telemetry is disabled by default, simply flip the bool in the `traces` block to turn it on.

If you have enabled the gateway as well, this will let you push traces using the default Open Telemetry API path (`/opentelemetry.proto.collector.trace.v1.TraceService/Export`), on the 4317 port. This port can be overwritten as well in the values.

```yaml
traces:
  otlp:
    http:
      # -- Enable Tempo to ingest Open Telemetry HTTP traces
      enabled: false
      # -- HTTP receiver advanced config
      receiverConfig: {}
    grpc:
      # -- Enable Tempo to ingest Open Telemetry GRPC traces
      enabled: true
      # -- GRPC receiver advanced config
      receiverConfig: {}
      # -- Default OTLP gRPC port
      port: 4317
```
