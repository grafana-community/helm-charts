{{/*
Workload helper

Emits a Deployment or StatefulSet for a standard Tempo component. The pod
template is delegated to tempo.podTemplate.

For Deployments: renders minReadySeconds and the rolling-update strategy from
$component.strategy. Replicas are suppressed when autoscaling.enabled is true.

For StatefulSets: renders the governing service name, podManagementPolicy: Parallel,
and updateStrategy from $component.statefulStrategy.

Params:
  ctx        = root context ($)
  component  = component values block (e.g. .Values.compactor)
  target     = component name string (e.g. "compactor")
  kind       = "Deployment" (default) or "StatefulSet"
  memberlist = bool, default false — add app.kubernetes.io/part-of: memberlist
*/}}
{{- define "tempo.lib.workload" -}}
{{- $ctx := .ctx -}}
{{- $component := .component -}}
{{- $target := .target -}}
{{- $kind := .kind | default "Deployment" -}}
{{- $memberlist := kindIs "bool" .memberlist | ternary .memberlist false -}}
{{- with $ctx -}}
apiVersion: apps/v1
kind: {{ $kind }}
metadata:
  name: {{ include "tempo.resourceName" (dict "ctx" . "component" $target) }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "tempo.labels" (dict "ctx" . "component" $target "memberlist" $memberlist) | nindent 4 }}
    {{- with $component.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $component.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if eq $kind "Deployment" }}
  minReadySeconds: {{ $component.minReadySeconds }}
  {{- end }}
  {{- if not (dig "autoscaling" "enabled" false $component) }}
  replicas: {{ $component.replicas }}
  {{- end }}
  revisionHistoryLimit: {{ .Values.tempo.revisionHistoryLimit }}
  selector:
    matchLabels:
      {{- include "tempo.selectorLabels" (dict "ctx" . "component" $target) | nindent 6 }}
  {{- if eq $kind "StatefulSet" }}
  podManagementPolicy: Parallel
  serviceName: {{ include "tempo.governingServiceName" (dict "ctx" $ctx "component" $target) }}
  {{- with $component.statefulStrategy }}
  updateStrategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- else }}
  {{- with $component.strategy }}
  strategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- end }}
  template:
    {{- include "tempo.podTemplate" (dict "ctx" . "component" $component "target" $target) | nindent 4 }}
{{- end }}
{{- end }}
