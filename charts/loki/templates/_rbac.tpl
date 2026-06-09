{{/*
RBAC helper
*/}}

{{- define "loki.rbac.sidecar" }}
{{- $target := .target }}
{{- $ctx := .ctx }}
{{- $component := .component }}
{{- with $ctx }}
---
{{- if and .Values.rbac.enabled .Values.sidecar.rules.enabled $component.sidecar }}
apiVersion: rbac.authorization.k8s.io/v1
{{- if .Values.rbac.namespaced }}
kind: Role
{{- else }}
kind: ClusterRole
{{- end }}
metadata:
  name: {{ template "loki.resourceName" (dict "ctx" . "component" $target) }}
  labels:
    {{- include "loki.labels" . | nindent 4 }}
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["configmaps", "secrets"]
  verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
{{- if .Values.rbac.namespaced }}
kind: RoleBinding
{{- else }}
kind: ClusterRoleBinding
{{- end }}
metadata:
  name: {{ template "loki.resourceName" (dict "ctx" . "component" $target) }}
  labels:
    {{- include "loki.labels" . | nindent 4 }}
subjects:
  - kind: ServiceAccount
    name: {{ include "loki.serviceAccountName" (dict "ctx" . "component" (dict "serviceAccount" ($component.serviceAccount | default dict)) "target" $target ) }}
    namespace: {{ include "loki.namespace" . }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  {{- if .Values.rbac.namespaced }}
  kind: Role
  {{- else }}
  kind: ClusterRole
  {{- end }}
  name: {{ template "loki.resourceName" (dict "ctx" . "component" $target) }}
{{- end }}
{{- end }}
{{- end -}}
