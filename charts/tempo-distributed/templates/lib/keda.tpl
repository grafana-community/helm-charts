{{/*
KEDA ScaledObject helper
*/}}

{{/*
Validate that HPA and KEDA autoscaling are not both enabled for a component.
Params: .component (values object), .name (string for error message)
*/}}
{{- define "tempo.lib.validateAutoscaling" -}}
{{- if and .component.autoscaling.enabled .component.autoscaling.keda.enabled .component.autoscaling.hpa.enabled }}
  {{- fail (printf "Cannot enable both HPA and Keda based autoscaling for %s at the same time." .name) }}
{{- end }}
{{- end -}}

{{- define "tempo.lib.keda" }}
  {{- $target := .target }}
  {{- $kind := .component.kind | default .kind | default "StatefulSet" }}
  {{- $ctx := .ctx }}
  {{- $component := .component }}
  {{- $suffix := .suffix | default "" }}
  {{- with $ctx }}
{{- if and $component.autoscaling.enabled $component.autoscaling.keda.enabled (not (empty (dig "autoscaling" "keda" "triggers" (list) $component)))  }}
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: {{ include "tempo.resourceName" (dict "ctx" . "component" $target "suffix" $suffix) }}
  namespace: {{ .Release.Namespace }}
  {{- with $component.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $component.autoscaling.keda.annotations }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  labels:
    {{- with $component.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- $kedaAutoScaling := $component.autoscaling.keda }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: {{ $kind }}
    name: {{ include "tempo.resourceName" (dict "ctx" . "component" $target "suffix" $suffix) }}
  minReplicaCount: {{ $component.autoscaling.minReplicas }}
  maxReplicaCount: {{ $component.autoscaling.maxReplicas }}
  {{- with $kedaAutoScaling.pollingInterval }}
  pollingInterval: {{ include "tempo.safeInt" (dict "value" . ) }}
  {{- end }}
  {{- with $kedaAutoScaling.cooldownPeriod }}
  cooldownPeriod: {{ include "tempo.safeInt" (dict "value" . ) }}
  {{- end }}
  {{- with $kedaAutoScaling.initialCooldownPeriod }}
  initialCooldownPeriod: {{ include "tempo.safeInt" (dict "value" . ) }}
  {{- end }}
  {{- with $kedaAutoScaling.fallback }}
  fallback:
    {{- with .failureThreshold }}
    failureThreshold: {{ . }}
    {{- end }}
    {{- with .replicas }}
    replicas: {{ . }}
    {{- end }}
    {{- with .behavior }}
    behavior: {{ . }}
    {{- end }}
  {{- end }}
  {{- with $kedaAutoScaling.advanced }}
  advanced:
    {{- with .horizontalPodAutoscalerConfig }}
    horizontalPodAutoscalerConfig:
      {{- with .name }}
      name: {{ . }}
      {{- end }}
      {{- with .behavior }}
      behavior:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    {{- end }}
    {{- with .scalingModifiers }}
    scalingModifiers:
      formula: {{ . | quote }}
      target: {{ . | quote }}
      {{- with .activationTarget }}
      activationTarget: {{ . | quote }}
      {{- end }}
      {{- with .metricType }}
      metricType: {{ . | quote }}
      {{- end }}
    {{- end }}
  {{- end }}
  {{- with $kedaAutoScaling.triggers }}
  triggers:
    {{- $root := $ }}
    {{- range . }}
    - type: {{ .type | quote }}
      {{- with .name }}
      name: {{ . }}
      {{- end }}
      {{- with .useCachedMetrics }}
      useCachedMetrics: {{ . }}
      {{- end }}
      {{- with .metricType }}
      metricType: {{ . | quote }}
      {{- end }}
      {{- with .authenticationRef }}
      authenticationRef:
        name: {{ .name }}
        {{- with .kind }}
        kind: {{ . }}
        {{- end }}
      {{- end }}
      metadata:
        {{- range $key, $value := .metadata }}
        {{ $key }}: {{ tpl $value $root | quote }}
        {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
{{- end -}}
