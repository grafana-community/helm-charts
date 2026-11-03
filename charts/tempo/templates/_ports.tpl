{{/* ~=~=~ Partial Templates of exposed Ports ~=~=~ */}}

{{/*
Port of a receiver endpoint such as "0.0.0.0:4317". Empty when the endpoint is not set,
so a receiver that is removed from tempo.receivers exposes no port.
*/}}
{{- define "tempo.receiverPort" -}}
{{- with . }}{{ regexSplit ":" . -1 | last }}{{ end }}
{{- end -}}

{{/* UDP sockets */}}
{{- define "tempo.udp"}}
{{- $receivers := .Values.tempo.receivers | default dict }}
{{- with include "tempo.receiverPort" (dig "jaeger" "protocols" "thrift_compact" "endpoint" "" $receivers) }}
- name: tempo-jaeger-thrift-compact
  port: {{ . }}
  protocol: UDP
  targetPort: {{ . }}
{{- end }}
{{- with include "tempo.receiverPort" (dig "jaeger" "protocols" "thrift_binary" "endpoint" "" $receivers) }}
- name: tempo-jaeger-thrift-binary
  port: {{ . }}
  protocol: UDP
  targetPort: {{ . }}
{{- end }}
{{- /* end of define */}}
{{- end }}

{{/* TCP sockets */}}
{{- define "tempo.tcp"}}
{{- $receivers := .Values.tempo.receivers | default dict }}
- name: tempo-prom-metrics
  port: 3200
  protocol: TCP
  targetPort: 3200
{{- if .Values.tempoQuery.enabled }}
- name: jaeger-metrics
  port: 16687
  protocol: TCP
  targetPort: 16687
- name: tempo-query-jaeger-ui
  port: {{ .Values.tempoQuery.service.port }}
  targetPort: {{ .Values.tempoQuery.service.port }}
{{- end }}
{{- with include "tempo.receiverPort" (dig "jaeger" "protocols" "thrift_http" "endpoint" "" $receivers) }}
- name: tempo-jaeger-thrift-http
  port: {{ . }}
  protocol: TCP
  targetPort: {{ . }}
{{- end }}
{{- with include "tempo.receiverPort" (dig "jaeger" "protocols" "grpc" "endpoint" "" $receivers) }}
- name: grpc-tempo-jaeger
  port: {{ . }}
  protocol: TCP
  targetPort: {{ . }}
{{- end }}
{{- with include "tempo.receiverPort" (dig "zipkin" "endpoint" "" $receivers) }}
- name: tempo-zipkin
  port: {{ . }}
  protocol: TCP
  targetPort: {{ . }}
{{- end }}
{{- with include "tempo.receiverPort" (dig "otlp" "protocols" "grpc" "endpoint" "" $receivers) }}
- name: grpc-tempo-otlp
  port: {{ . }}
  protocol: TCP
  targetPort: {{ . }}
{{- end }}
{{- with include "tempo.receiverPort" (dig "otlp" "protocols" "http" "endpoint" "" $receivers) }}
- name: tempo-otlp-http
  port: {{ . }}
  protocol: TCP
  targetPort: {{ . }}
{{- end }}
{{- /* end of define */}}
{{- end  }}

{{/* Container ports of the tempo container, derived from the same receiver endpoints */}}
{{- define "tempo.containerPorts" -}}
{{- $receivers := .Values.tempo.receivers | default dict -}}
- containerPort: 3200
  name: prom-metrics
{{- with include "tempo.receiverPort" (dig "jaeger" "protocols" "thrift_compact" "endpoint" "" $receivers) }}
- containerPort: {{ . }}
  name: jaeger-thrift-c
  protocol: UDP
{{- end }}
{{- with include "tempo.receiverPort" (dig "jaeger" "protocols" "thrift_binary" "endpoint" "" $receivers) }}
- containerPort: {{ . }}
  name: jaeger-thrift-b
  protocol: UDP
{{- end }}
{{- with include "tempo.receiverPort" (dig "jaeger" "protocols" "thrift_http" "endpoint" "" $receivers) }}
- containerPort: {{ . }}
  name: jaeger-thrift-h
{{- end }}
{{- with include "tempo.receiverPort" (dig "jaeger" "protocols" "grpc" "endpoint" "" $receivers) }}
- containerPort: {{ . }}
  name: jaeger-grpc
{{- end }}
{{- with include "tempo.receiverPort" (dig "zipkin" "endpoint" "" $receivers) }}
- containerPort: {{ . }}
  name: zipkin
{{- end }}
{{- with include "tempo.receiverPort" (dig "otlp" "protocols" "grpc" "endpoint" "" $receivers) }}
- containerPort: {{ . }}
  name: otlp-grpc
{{- end }}
{{- with include "tempo.receiverPort" (dig "otlp" "protocols" "http" "endpoint" "" $receivers) }}
- containerPort: {{ . }}
  name: otlp-http
{{- end }}
{{- end -}}
