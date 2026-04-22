{{/*
backend fullname
*/}}
{{- define "loki.backendFullname" -}}
{{- if .Values.backend.useOldObjectNames -}}
{{ include "loki.name" . }}-backend
{{- else -}}
{{ include "loki.fullname" . }}-backend
{{- end -}}
{{- end }}

{{/*
backend common labels
*/}}
{{- define "loki.backendLabels" -}}
{{ include "loki.labels" . }}
app.kubernetes.io/component: backend
{{- end }}

{{/*
backend selector labels
*/}}
{{- define "loki.backendSelectorLabels" -}}
{{ include "loki.selectorLabels" . }}
app.kubernetes.io/component: backend
{{- end }}

{{/*
backend priority class name
*/}}
{{- define "loki.backendPriorityClassName" -}}
{{- $pcn := coalesce .Values.global.priorityClassName .Values.backend.priorityClassName -}}
{{- if $pcn }}
priorityClassName: {{ $pcn }}
{{- end }}
{{- end }}
