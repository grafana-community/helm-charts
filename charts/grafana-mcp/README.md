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

### From Chart versions < 0.30.0

`automountServiceAccountToken` now defaults to `false` on the pod template, so the Kubernetes
service account token is no longer mounted into the container. The chart already set
`serviceAccount.automountServiceAccountToken: false`, but the pod-level field takes precedence
and was `true`, so the token was mounted regardless of that setting.

grafana-mcp talks to the Grafana HTTP API and does not call the Kubernetes API, so no action is
needed for a normal install. If something in your setup reads the mounted token -- a sidecar, or
a custom image -- set `automountServiceAccountToken: true` to restore the previous behaviour.

### From Chart versions < 0.29.0
The MCP HTTP endpoint is now protected by a bearer token (`MCP_GRAFANA_SERVER_TOKEN`). If `serverAuth.token` and
`serverAuth.tokenSecret.name` are not set, the chart generates a random token and stores it as `server-token` in the
chart-managed Secret. Clients must send `Authorization: Bearer <token>`.

To read the generated token:

```console
kubectl get secret RELEASE-NAME-grafana-mcp -o jsonpath="{.data.server-token}" | base64 --decode ; echo
```

To keep the previous behavior without authentication, set `serverAuth.token: null`:

```yaml
serverAuth:
  token: null
```

If you forward the client's `Authorization` header to Grafana (`env.GRAFANA_FORWARD_HEADERS` contains
`Authorization`), the chart does not generate a token, because mcp-grafana reserves the `Authorization` header for the
caller token and refuses to start when both are set. An explicitly configured `serverAuth.token` or
`serverAuth.tokenSecret.name` is still used. See
[Configure caller authentication](https://github.com/grafana/mcp-grafana/blob/main/docs/sources/configure/command-line-flags.md#configure-caller-authentication).

> [!NOTE]
> With Helm 4, a `null` in an umbrella chart's own `values.yaml` does not override this chart's default, so a token
> is still generated. Set `grafana-mcp.serverAuth.token: null` in a values file passed with `-f` or via
> `--set grafana-mcp.serverAuth.token=null` instead.

### From Chart versions < 0.1.3
If you are upgrading from a chart version older than 0.1.3, we have changed the image to be pulled from
`grafana/mcp-grafana` instead of `mcp/grafana` and the default tag to be the chart's appVersion instead of `latest`.
