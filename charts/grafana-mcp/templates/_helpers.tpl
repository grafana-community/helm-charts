{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "grafana-mcp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "grafana-mcp.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "grafana-mcp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create the name of the service account
*/}}
{{- define "grafana-mcp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "grafana-mcp.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
{{/*
Allow the release namespace to be overridden for multi-namespace deployments in combined charts
*/}}
{{- define "grafana-mcp.namespace" -}}
{{- if .Values.namespaceOverride }}
{{- .Values.namespaceOverride }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "grafana-mcp.labels" -}}
helm.sh/chart: {{ include "grafana-mcp.chart" . }}
{{ include "grafana-mcp.selectorLabels" . }}
{{- if or .Chart.AppVersion .Values.image.tag }}
app.kubernetes.io/version: {{ mustRegexReplaceAllLiteral "@sha.*" .Values.image.tag "" | default .Chart.AppVersion | trunc 63 | trimSuffix "-" | quote }}
{{- end }}
{{- with .Values.extraLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "grafana-mcp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "grafana-mcp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Looks if there's an existing secret and reuse its token. If not it generates
new token and use it.
*/}}
{{- define "grafana-mcp.serverToken" -}}
{{- $secret := (lookup "v1" "Secret" (include "grafana-mcp.namespace" .) (include "grafana-mcp.fullname" .) ) }}
{{- if $secret }}
{{- index $secret "data" "server-token" }}
{{- else }}
{{- (randAlphaNum 40) | b64enc | quote }}
{{- end }}
{{- end }}

{{/*
Formats imagePullSecrets. Input is (dict "root" . "imagePullSecrets" .{specific imagePullSecrets})
*/}}
{{- define "grafana.imagePullSecrets" -}}
{{- $root := .root }}
{{- range (concat .root.Values.global.imagePullSecrets .imagePullSecrets) }}
{{- if eq (typeOf .) "map[string]interface {}" }}
- {{ toYaml (dict "name" (tpl .name $root)) | trim }}
{{- else }}
- name: {{ tpl . $root }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Return the appropriate apiVersion for Gateway API routes.
*/}}
{{- define "grafana-mcp.gatewayApi.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "gateway.networking.k8s.io/v1" }}
{{- print "gateway.networking.k8s.io/v1" }}
{{- else if .Capabilities.APIVersions.Has "gateway.networking.k8s.io/v1beta1" }}
{{- print "gateway.networking.k8s.io/v1beta1" }}
{{- else }}
{{- print "gateway.networking.k8s.io/v1" }}
{{- end }}
{{- end }}

{{/*
Returns "true" if caller authentication (MCP_GRAFANA_SERVER_TOKEN) is enabled.
An explicit token or tokenSecret always enables it. Otherwise a token is generated,
unless serverAuth.token is null or the Authorization header is forwarded to Grafana
via GRAFANA_FORWARD_HEADERS, which mcp-grafana does not allow together with a server token.
*/}}
{{- define "grafana-mcp.serverAuthEnabled" -}}
{{- $forwardsAuthorization := false -}}
{{- range (splitList "," (.Values.env.GRAFANA_FORWARD_HEADERS | default "" | toString)) -}}
{{- if eq (. | trim | lower) "authorization" -}}
{{- $forwardsAuthorization = true -}}
{{- end -}}
{{- end -}}
{{- if or .Values.serverAuth.tokenSecret.name .Values.serverAuth.token -}}
true
{{- else if and (hasKey .Values.serverAuth "token") (not $forwardsAuthorization) -}}
true
{{- end -}}
{{- end }}

{{/*
Comma-separated Host header allowlist for --allowed-hosts. mcp-grafana matches the Host
header exactly, so Service names carry the Service port, which clients include unless it
is 80. The loopback addresses are always listed: they are the upstream default that the
flag replaces, and the liveness probe sends Host: localhost:<port>. Empty for image tags
older than v0.17.1, which do not know the flag.
*/}}
{{- define "grafana-mcp.allowedHosts" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion | toString | trimPrefix "v" -}}
{{- $supported := true -}}
{{- if regexMatch "^[0-9]+\\.[0-9]+\\.[0-9]+" $tag -}}
{{- $supported = semverCompare ">=0.17.1-0" (regexFind "^[0-9]+\\.[0-9]+\\.[0-9]+" $tag) -}}
{{- end -}}
{{- if $supported -}}
{{- $port := toString .Values.service.port -}}
{{- $hosts := list -}}
{{- range list "localhost" "127.0.0.1" "[::1]" -}}
{{- $hosts = append $hosts (printf "%s:%s" . $port) -}}
{{- end -}}
{{- if and .Values.allowedHosts.service .Values.service.enabled -}}
{{- $name := include "grafana-mcp.fullname" . -}}
{{- $ns := include "grafana-mcp.namespace" . -}}
{{- range list $name (printf "%s.%s" $name $ns) (printf "%s.%s.svc" $name $ns) (printf "%s.%s.svc.%s" $name $ns $.Values.clusterDomain) -}}
{{- $hosts = append $hosts (printf "%s:%s" . $port) -}}
{{- if eq $port "80" -}}
{{- $hosts = append $hosts . -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if .Values.allowedHosts.ingress -}}
{{- if .Values.ingress.enabled -}}
{{- range .Values.ingress.hosts -}}
{{- with .host -}}
{{- $hosts = append $hosts (tpl . $) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- range $_, $route := .Values.route -}}
{{- if $route.enabled -}}
{{- range $route.hostnames -}}
{{- $hosts = append $hosts (tpl . $) -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- range .Values.allowedHosts.extra -}}
{{- $hosts = append $hosts . -}}
{{- end -}}
{{- $hosts | uniq | join "," -}}
{{- end -}}
{{- end -}}

{{/*
Port of grafana.url: the explicit port, else 443 for https and 80 otherwise
*/}}
{{- define "grafana-mcp.grafanaPort" -}}
{{- $url := urlParse (.Values.grafana.url | default "") -}}
{{- $port := regexFind ":[0-9]+$" $url.host | trimPrefix ":" -}}
{{- if $port -}}
{{- $port -}}
{{- else if eq $url.scheme "https" -}}
443
{{- else -}}
80
{{- end -}}
{{- end -}}
