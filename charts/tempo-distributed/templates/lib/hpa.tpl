{{/*
HPA helper

Emits an HorizontalPodAutoscaler (autoscaling/v2) when autoscaling.enabled and
autoscaling.hpa.enabled are both true on the component.

Metrics are read from $component.autoscaling.hpa.targetCPUUtilizationPercentage
and $component.autoscaling.hpa.targetMemoryUtilizationPercentage. Neither is
emitted when its value is null/zero.

Params:
  ctx       = root context ($)
  component = component values block (e.g. .Values.compactor)
  target    = component name string (e.g. "compactor")
  kind      = scaleTargetRef kind, default "Deployment"
*/}}
{{- define "tempo.lib.hpa" -}}
{{- $ctx := .ctx -}}
{{- $component := .component -}}
{{- $target := .target -}}
{{- $kind := .kind | default "Deployment" -}}
{{- $hpaEnabled := and (dig "autoscaling" "enabled" false $component) (dig "autoscaling" "hpa" "enabled" false $component) -}}
{{- if $hpaEnabled -}}
{{- with $ctx -}}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "tempo.resourceName" (dict "ctx" . "component" $target) }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "tempo.labels" (dict "ctx" . "component" $target) | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: {{ $kind }}
    name: {{ include "tempo.resourceName" (dict "ctx" . "component" $target) }}
  minReplicas: {{ $component.autoscaling.minReplicas }}
  maxReplicas: {{ $component.autoscaling.maxReplicas }}
  {{- with $component.autoscaling.hpa.behavior }}
  behavior:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  metrics:
  {{- with $component.autoscaling.hpa.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ . }}
  {{- end }}
  {{- with $component.autoscaling.hpa.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ . }}
  {{- end }}
{{- end }}
{{- end }}
{{- end }}
