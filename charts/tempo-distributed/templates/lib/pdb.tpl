{{/*
Tempo common PodDisruptionBudget definition
Params:
  ctx = . context
  component = name of the component
*/}}
{{- define "tempo.lib.podDisruptionBudget" -}}
{{- $componentSection := include "tempo.componentSectionFromName" . }}
{{ with (index $.ctx.Values $componentSection) }}
{{- if .podDisruptionBudget -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "tempo.resourceName" (dict "ctx" $.ctx "component" $.component) }}
  labels:
    {{- include "tempo.labels" (dict "ctx" $.ctx "component" $.component) | nindent 4 }}
  namespace: {{ $.ctx.Release.Namespace | quote }}
spec:
  selector:
    matchLabels:
      {{- include "tempo.selectorLabels" (dict "ctx" $.ctx "component" $.component) | nindent 6 }}
{{ toYaml .podDisruptionBudget | indent 2 }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
PodDisruptionBudget helper

Emits a PDB only when podDisruptionBudget.enabled is true AND the effective
minimum replica count is greater than 1 (from static replicas, HPA minReplicas,
or KEDA minReplicas). This avoids creating a PDB that can never be satisfied
on single-replica or default deployments.

Legacy $component.maxUnavailable field is honoured for back-compatibility.
New-style settings live under $component.podDisruptionBudget.{maxUnavailable,minAvailable,...}.
unhealthyPodEvictionPolicy is handled explicitly to avoid rendering an empty string.

Params:
  ctx        = root context ($)
  component  = component values block (e.g. .Values.compactor)
  target     = component name string (e.g. "compactor")
  memberlist = bool, default false — add app.kubernetes.io/part-of: memberlist to metadata labels
*/}}
{{- define "tempo.lib.pdb" -}}
{{- $ctx := .ctx -}}
{{- $component := .component -}}
{{- $target := .target -}}
{{- $memberlist := kindIs "bool" .memberlist | ternary .memberlist false -}}
{{- $hpaEnabled := and (dig "autoscaling" "enabled" false $component) (dig "autoscaling" "hpa" "enabled" false $component) -}}
{{- $kedaEnabled := and (dig "autoscaling" "enabled" false $component) (dig "autoscaling" "keda" "enabled" false $component) -}}
{{- $replicas := dig "replicas" 1 $component | int -}}
{{- $minReplicas := dig "autoscaling" "minReplicas" 1 $component | int -}}
{{- $pdbEnabled := dig "podDisruptionBudget" "enabled" false $component -}}
{{- if and $pdbEnabled (or
  (and (not $hpaEnabled) (not $kedaEnabled) (gt $replicas 1))
  (and $hpaEnabled (gt $minReplicas 1))
  (and $kedaEnabled (gt $minReplicas 1))
) -}}
{{- with $ctx -}}
{{- $pdb := dict -}}
{{- if hasKey $component "maxUnavailable" -}}
{{- if not (kindIs "invalid" $component.maxUnavailable) -}}
{{- $_ := set $pdb "maxUnavailable" $component.maxUnavailable -}}
{{- end -}}
{{- end -}}
{{- $_ := mergeOverwrite $pdb (omit ($component.podDisruptionBudget | default dict) "enabled" "labels" "annotations" "unhealthyPodEvictionPolicy") -}}
{{- if (omit $pdb "selector") }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "tempo.resourceName" (dict "ctx" . "component" $target) }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "tempo.labels" (dict "ctx" . "component" $target "memberlist" $memberlist) | nindent 4 }}
    {{- with $component.podDisruptionBudget.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $component.podDisruptionBudget.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- toYaml (omit $pdb "selector") | nindent 2 }}
  {{- with $component.podDisruptionBudget.unhealthyPodEvictionPolicy }}
  unhealthyPodEvictionPolicy: {{ . }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "tempo.selectorLabels" (dict "ctx" . "component" $target) | nindent 6 }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
