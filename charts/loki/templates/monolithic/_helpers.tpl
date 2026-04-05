{{/*
monolithic common labels
*/}}
{{- define "loki.monolithicLabels" -}}
{{ include "loki.labels" . }}
app.kubernetes.io/component: single-binary
{{- end }}


{{/* monolithic selector labels */}}
{{- define "loki.monolithicSelectorLabels" -}}
{{ include "loki.selectorLabels" . }}
app.kubernetes.io/component: single-binary
{{- end }}

{{/*
monolithic priority class name
*/}}
{{- define "loki.monolithicPriorityClassName" -}}
{{- $pcn := coalesce .Values.global.priorityClassName .Values.singleBinary.priorityClassName -}}
{{- if $pcn }}
priorityClassName: {{ $pcn }}
{{- end }}
{{- end }}

{{/* monolithic replicas calculation */}}
{{- define "loki.monolithicReplicas" -}}
{{- $replicas := 1 }}
{{- $usingObjectStorage := eq (include "loki.isUsingObjectStorage" .) "true" }}
{{- if and $usingObjectStorage (gt (int .Values.singleBinary.replicas) 1)}}
{{- $replicas = int .Values.singleBinary.replicas -}}
{{- end }}
{{- printf "%d" $replicas }}
{{- end }}

{{/*
monolithic target
*/}}
{{- define "loki.monolithicTarget" -}}
{{- .Values.singleBinary.targetModule -}}{{- if .Values.loki.ui.enabled -}},ui{{- end -}}
{{- end -}}
