{{/*
read fullname
*/}}
{{- define "loki.readFullname" -}}
{{ include "loki.fullname" . }}-read
{{- end }}

{{/*
read common labels
*/}}
{{- define "loki.readLabels" -}}
{{ include "loki.labels" . }}
app.kubernetes.io/component: read
{{- end }}

{{/*
read selector labels
*/}}
{{- define "loki.readSelectorLabels" -}}
{{ include "loki.selectorLabels" . }}
app.kubernetes.io/component: read
{{- end }}
