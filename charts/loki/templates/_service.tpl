{{/*
Service helper
*/}}

{{- define "loki.service" }}
{{- $target := .target }}
{{- $ctx := .ctx }}
{{- $component := .component }}
{{- $name := .name }}
{{- $headlessName := .headlessName }}
{{- with $ctx }}
apiVersion: v1
kind: Service
metadata:
  {{- if $name }}
  name: {{ $name }}
  {{- else }}
  name: "{{ include "loki.fullname" . }}-{{ $target }}"
  {{- end }}
  namespace: "{{ include "loki.namespace" . }}"
  labels:
    {{- include "loki.labels" . | nindent 4 }}
    app.kubernetes.io/component: {{ $target | quote }}
    {{- with (mergeOverwrite .Values.defaults.service.labels $component.serviceLabels $component.service.labels) }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- with (mergeOverwrite .Values.loki.serviceAnnotations .Values.defaults.service.annotations $component.serviceAnnotations $component.service.annotations) }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  type: {{ $component.serviceType | default $component.service.type | default "ClusterIP" }}
  publishNotReadyAddresses: true
  ports:
    - name: http-metrics
      port: 3100
      targetPort: http-metrics
      protocol: TCP
    - name: grpc
      port: 9095
      targetPort: grpc
      protocol: TCP
      {{- with $component.appProtocol.grpc | default $component.service.appProtocol.grpc }}
      appProtocol: {{ . }}
      {{- end }}
    - name: grpclb
      port: 9096
      targetPort: grpc
      protocol: TCP
      {{- with $component.appProtocol.grpc | default $component.service.appProtocol.grpc }}
      appProtocol: {{ . }}
      {{- end }}
  selector:
    {{ include "loki.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: {{ $target | quote }}
{{- with (coalesce $component.trafficDistribution $component.service.trafficDistribution .Values.defaults.service.trafficDistribution .Values.loki.service.trafficDistribution) }}
  trafficDistribution: {{ . }}
{{- end }}
---
apiVersion: v1
kind: Service
metadata:
  {{ if $headlessName }}
  name: {{ $headlessName }}
  {{ else }}
  name: "{{ include "loki.fullname" . }}-{{ $target }}-headless"
  {{- end }}
  namespace: {{ include "loki.namespace" . }}
  labels:
    {{- include "loki.labels" . | nindent 4 }}
    app.kubernetes.io/component: {{ $target | quote }}
    prometheus.io/service-monitor: "false"
    variant: headless
    {{- with (mergeOverwrite .Values.defaults.service.labels $component.serviceLabels $component.service.labels) }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- with (mergeOverwrite .Values.loki.serviceAnnotations .Values.defaults.service.annotations $component.serviceAnnotations $component.service.annotations) }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  clusterIP: None
  type: ClusterIP
  publishNotReadyAddresses: true
  ports:
    - name: http-metrics
      port: 3100
      targetPort: http-metrics
      protocol: TCP
    - name: grpc
      port: 9095
      targetPort: grpc
      protocol: TCP
      {{- with $component.appProtocol.grpc | default $component.service.appProtocol.grpc }}
      appProtocol: {{ . }}
      {{- end }}
    - name: grpclb
      port: 9096
      targetPort: grpc
      protocol: TCP
      {{- with $component.appProtocol.grpc | default $component.service.appProtocol.grpc }}
      appProtocol: {{ . }}
      {{- end }}
  selector:
    {{ include "loki.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: {{ $target | quote }}
{{- end }}
{{- end }}
