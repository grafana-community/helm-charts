{{/*
memcached PDB
Params:
  ctx = . context
  memcacheConfig = cache config
  valuesSection = name of the section in values.yaml
  component = name of the component
valuesSection and component are specified separately because helm prefers camelcase for naming convention and k8s components are named with snake case.
*/}}
{{- define "loki.memcached.pdb" -}}
{{ with $.memcacheConfig }}
{{- $pdbSpec := dict }}
{{- range $key, $value := pick . "maxUnavailable" }}
{{- if not (kindIs "invalid" $value) }}
{{- $_ := set $pdbSpec $key $value }}
{{- end }}
{{- end }}
{{- range $key, $value := omit (.podDisruptionBudget | default dict) "enabled" "labels" "annotations" }}
{{- if not (kindIs "invalid" $value) }}
{{- $_ := set $pdbSpec $key $value }}
{{- end }}
{{- end }}
{{- if and .enabled .podDisruptionBudget.enabled (gt (int .replicas) 1) $pdbSpec -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "loki.resourceName" (dict "ctx" $.ctx "component" $.component "suffix" .suffix) }}
  namespace: {{ include "loki.namespace" $.ctx }}
  {{- with .podDisruptionBudget.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  labels:
    {{- include "loki.selectorLabels" $.ctx | nindent 4 }}
    app.kubernetes.io/component: "memcached-{{ $.component }}{{ include "loki.memcached.suffix" .suffix }}"
    {{- with .podDisruptionBudget.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- toYaml $pdbSpec | nindent 2 }}
  selector:
    matchLabels:
      {{- include "loki.selectorLabels" $.ctx | nindent 6 }}
      app.kubernetes.io/component: "memcached-{{ $.component }}{{ include "loki.memcached.suffix" .suffix }}"
    {{- end }}
{{- end -}}
{{- end -}}
