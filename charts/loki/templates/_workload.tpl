{{/*
Workload helper
*/}}

{{- define "loki.component" }}
{{- $target := .target }}
{{- $ctx := .ctx }}
{{- $component := .component }}
{{- $name := .name }}
{{- $headlessName := .headlessName }}
{{- with $ctx }}
{{- if $component.enabled }}
apiVersion: apps/v1
kind: {{ $component.kind }}
metadata:
  name: {{ $name | default (include "loki.resourceName" (dict "ctx" $ctx "component" $target)) }}
  namespace: {{ include "loki.namespace" . }}
  labels:
    {{ include "loki.labels" . }}
    app.kubernetes.io/component: {{ $target }}
    app.kubernetes.io/part-of: memberlist
  {{- with .Values.loki.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
{{- if not (dig "autoscaling" "enabled" false $component) }}
  replicas: {{ $component.replicas }}
{{- end }}
  {{- if eq $component.kind "StatefulSet" }}
  podManagementPolicy: Parallel
  {{- with $component.strategy }}
  updateStrategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  serviceName: {{ $headlessName | default (include "loki.resourceName" (dict "ctx" $ctx "component" $target "suffix" "headless")) }}
  {{- if $component.persistence.enableStatefulSetAutoDeletePVC }}
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: {{ $component.persistence.whenDeleted }}
    whenScaled: {{ $component.persistence.whenScaled }}
  {{- end }}
  {{- else }}
  {{- with $component.strategy }}
  strategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- end }}
  revisionHistoryLimit: {{ .Values.loki.revisionHistoryLimit }}
  selector:
    matchLabels:
      {{- include "loki.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: {{ $target }}
  template:
    {{- include "loki.podTemplate" (dict "target" $target "component" $component "ctx" $ctx) | nindent 4 }}
  {{- if and $component.persistence.enabled (eq $component.persistence.type "pvc") }}
    {{- if and (eq $component.kind "Deployment") (gt (int $component.replicas) 1) }}
      {{- fail "Persistence with PVC is not supported for Deployment with more than 1 replica. Please use StatefulSet or set replicas to 1." }}
    {{- end }}
    {{- if eq $component.kind "StatefulSet" }}
  volumeClaimTemplates:
  {{- $dataClaimExists := false }}
  {{- range $component.persistence.claims }}
    {{- if eq .name "data" }}
      {{- $dataClaimExists = true }}
    {{- end }}
    - apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: {{ .name }}
        {{- with .annotations }}
        annotations:
          {{- . | toYaml | nindent 10 }}
        {{- end }}
        {{- with .labels }}
        labels:
          {{- . | toYaml | nindent 10 }}
        {{- end }}
      spec:
        accessModes:
          {{- toYaml .accessModes | nindent 10 }}
        {{- with .storageClass }}
        storageClassName: {{ if (eq "-" .) }}""{{ else }}{{ . }}{{ end }}
        {{- end }}
        {{- with .volumeAttributesClassName }}
        volumeAttributesClassName: {{ . }}
        {{- end }}
        resources:
          requests:
            storage: {{ .size | quote }}
  {{- end }}
  {{- if (not $dataClaimExists) }}
    - apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: data
        {{- with $component.persistence.annotations }}
        annotations:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with $component.persistence.labels }}
        labels:
          {{- toYaml . | nindent 10 }}
        {{- end }}
      spec:
        {{- with $component.persistence.storageClass }}
        storageClassName: {{ if (eq "-" .) }}""{{ else }}{{ . }}{{ end }}
        {{- end }}
        {{- with $component.persistence.accessModes }}
        accessModes:
          {{- toYaml . | nindent 10 }}
        {{- end }}
        {{- with $component.persistence.volumeAttributesClassName }}
        volumeAttributesClassName: {{ . }}
        {{- end }}
        resources:
          requests:
            storage: {{ $component.persistence.size | quote }}
        {{- with $component.persistence.selector }}
        selector:
          {{- toYaml . | nindent 14 }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}
