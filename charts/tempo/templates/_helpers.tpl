{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "tempo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "tempo.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "tempo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "tempo.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "tempo.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "tempo.labels" -}}
helm.sh/chart: {{ include "tempo.chart" . }}
{{ include "tempo.selectorLabels" . }}
{{- if or .Chart.AppVersion .Values.tempo.tag }}
app.kubernetes.io/version: {{ mustRegexReplaceAllLiteral "@sha.*" .Values.tempo.tag "" | default .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.extraLabels }}
{{ toYaml . }}
{{- end }}
{{- with .Values.global.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "tempo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tempo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "tempo.imageRenderer.labels" -}}
helm.sh/chart: {{ include "tempo.chart" . }}
{{ include "tempo.imageRenderer.selectorLabels" . }}
{{- if or .Chart.AppVersion .Values.image.tag }}
app.kubernetes.io/version: {{ mustRegexReplaceAllLiteral "@sha.*" .Values.image.tag "" | default .Chart.AppVersion | quote }}
{{- end }}`
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Ports of the tempo service, as a YAML list. Mirrors the protocol selection of
templates/service.yaml, so a caller can check whether a port is reachable.
*/}}
{{- define "tempo.servicePorts" -}}
{{- if (eq .Values.service.type "LoadBalancer") }}
{{- $protocol := .Values.service.protocol | default "TCP" }}
{{- if contains "UDP" $protocol }}
{{- include "tempo.udp" . }}
{{- end }}
{{- if contains "TCP" $protocol }}
{{- include "tempo.tcp" . }}
{{- end }}
{{- else }}
{{- include "tempo.udp" . }}
{{- include "tempo.tcp" . }}
{{- end }}
{{- end -}}

{{/*
Return the appropriate apiVersion for Gateway API resources.
*/}}
{{- define "tempo.gatewayApi.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "gateway.networking.k8s.io/v1" }}
{{- print "gateway.networking.k8s.io/v1" }}
{{- else if .Capabilities.APIVersions.Has "gateway.networking.k8s.io/v1beta1" }}
{{- print "gateway.networking.k8s.io/v1beta1" }}
{{- else }}
{{- print "gateway.networking.k8s.io/v1" }}
{{- end }}
{{- end -}}

