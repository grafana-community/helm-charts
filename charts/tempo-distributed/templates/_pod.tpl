{{/*
Shared pod template for all Tempo binary components.

Usage:
  {{ include "tempo.podTemplate" (dict "ctx" $ "component" .Values.distributor "target" "distributor") }}

Parameters:
  ctx            - root context ($)
  component      - component values dict (e.g. .Values.distributor)
  target         - component name string used in args and volume names (e.g. "distributor")
  rolloutZoneName - (optional) zone name string; when non-empty, emits zone-aware pod labels
                    and uses rolloutZone affinity/nodeSelector instead of component values
  rolloutZone    - (optional) precomputed zone dict from ingester.zoneAwareReplicationMap
                    (keys: affinity, nodeSelector, podAnnotations)
  args           - (optional) extra args list prepended before extraArgs concat
                    (used for -ingester.availability-zone=<zone>)
  persistence    - (optional) persistence dict; when provided drives the data volume:
                    enabled=false  → emptyDir (custom spec from dataEmptyDir, else {})
                    enabled=true, inMemory=true → emptyDir medium:Memory with sizeLimit
                    enabled=true, inMemory=false → no inline volume (PVC in volumeClaimTemplates)
  dataVolumeName - (optional) name of the data volume; when empty uses tempo-<target>-store emptyDir
  dataEmptyDir   - (optional) custom emptyDir spec dict for non-persistent data volume
  ports          - (optional) fully custom port list [{name, port}]; replaces standard ports block
*/}}
{{- define "tempo.podTemplate" }}
{{- $target := .target }}
{{- $ctx := .ctx }}
{{- $component := .component }}
{{- $rolloutZoneName := .rolloutZoneName | default "" }}
{{- $rolloutZone := .rolloutZone | default (dict) }}
{{- $extraArgs := .args | default list }}
{{- $persistence := .persistence | default (dict) }}
{{- $dataVolumeName := .dataVolumeName | default "" }}
{{- $dataEmptyDir := .dataEmptyDir | default (dict) }}
{{- $customPorts := .ports | default list }}
{{- with $ctx }}
metadata:
  annotations:
    {{- with (mergeOverwrite (dict) (.Values.defaults.podAnnotations | default (dict)) (.Values.tempo.podAnnotations | default (dict)) ($component.podAnnotations | default (dict)) ($rolloutZone.podAnnotations | default (dict))) }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    checksum/config: {{ include (print .Template.BasePath "/configmap-tempo.yaml") . | sha256sum }}
    {{- if dig "enabled" false $persistence }}
    storage/size: {{ dig "size" "" $persistence | quote }}
    {{- end }}
  labels:
    {{- include "tempo.podLabels" (dict "ctx" . "component" $target "memberlist" true) | nindent 4 }}
    {{- with (mergeOverwrite (dict) (.Values.defaults.podLabels | default (dict)) (.Values.tempo.podLabels | default (dict)) ($component.podLabels | default (dict))) }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- if $rolloutZoneName }}
    name: {{ $target }}-{{ $rolloutZoneName }}
    rollout-group: {{ $target }}
    zone: {{ $rolloutZoneName }}
    {{- end }}
    {{- if .Values.enterprise.legacyLabels }}
    app: {{ include "tempo.name" . }}-{{ $target }}
    {{- if $rolloutZoneName }}
    name: {{ $target }}-{{ $rolloutZoneName }}
    {{- else }}
    name: {{ $target }}
    {{- end }}
    gossip_ring_member: "true"
    target: {{ $target }}
    release: {{ .Release.Name }}
    {{- end }}
spec:
  serviceAccountName: {{ include "tempo.serviceAccountName" . }}
  enableServiceLinks: false
  {{- with (coalesce $component.podSecurityContext .Values.tempo.podSecurityContext .Values.defaults.podSecurityContext) }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (coalesce $component.priorityClassName .Values.defaults.priorityClassName .Values.global.priorityClassName) }}
  priorityClassName: {{ . }}
  {{- end }}
  {{- include "tempo.componentImagePullSecrets" (dict "ctx" . "component" $target) | nindent 2 -}}
  {{- with (coalesce $component.hostAliases .Values.defaults.hostAliases) }}
  hostAliases:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- $dnsOverride := $component.dnsConfigOverides | default dict }}
  {{- if and $dnsOverride.enabled $dnsOverride.dnsConfig }}
  dnsConfig:
    {{- toYaml $dnsOverride.dnsConfig | nindent 4 }}
  {{- end }}
  {{- with $component.initContainers }}
  initContainers:
    {{- if kindIs "slice" . }}
      {{- tpl (toYaml .) $ctx | nindent 4 }}
    {{- else if kindIs "string" . }}
      {{- tpl . $ctx | nindent 4 }}
    {{- end }}
  {{- end }}
  containers:
    - name: {{ $target }}
      image: {{ include "tempo.imageReference" (dict "ctx" . "component" $target) }}
      imagePullPolicy: {{ .Values.tempo.image.pullPolicy }}
      args:
        - -target={{ $target }}
        - -config.file=/conf/tempo.yaml
        {{- with $extraArgs }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- with (concat .Values.global.extraArgs (.Values.defaults.extraArgs | default list) $component.extraArgs) | uniq }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      ports:
        {{- if $customPorts }}
        {{- range $customPorts }}
        - name: {{ .name | quote }}
          containerPort: {{ .port }}
        {{- end }}
        {{- else }}
        - containerPort: {{ include "tempo.memberlistBindPort" . }}
          name: http-memberlist
          protocol: TCP
        - containerPort: 3200
          name: http-metrics
          protocol: TCP
        {{- with $component.extraPorts }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- end }}
      {{- $resolvedResources := coalesce $component.resources .Values.tempo.resources .Values.defaults.resources | default (dict) }}
      {{- include "tempo.componentEnv" (dict "extraEnv" (concat .Values.global.extraEnv (.Values.defaults.extraEnv | default list) $component.extraEnv) "resources" $resolvedResources "factor" .Values.global.goSettings.goMemLimitFactor "gogc" .Values.global.goSettings.gogc) | nindent 6 }}
      {{- with (concat .Values.global.extraEnvFrom (.Values.defaults.extraEnvFrom | default list) $component.extraEnvFrom) | uniq }}
      envFrom:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with (coalesce $component.livenessProbe .Values.tempo.livenessProbe .Values.defaults.livenessProbe) }}
      livenessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with (coalesce $component.readinessProbe .Values.tempo.readinessProbe .Values.defaults.readinessProbe) }}
      readinessProbe:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $resolvedResources }}
      resources:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with (coalesce $component.containerSecurityContext .Values.tempo.securityContext .Values.defaults.containerSecurityContext) }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $component.lifecycle }}
      lifecycle:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      volumeMounts:
        - mountPath: /conf
          name: config
        - mountPath: /runtime-config
          name: runtime-config
        - mountPath: /var/tempo
          name: {{ if $dataVolumeName }}{{ $dataVolumeName }}{{ else }}tempo-{{ $target }}-store{{ end }}
        {{- if .Values.enterprise.enabled }}
        - name: license
          mountPath: /license
        {{- end }}
        {{- with (concat (.Values.defaults.extraVolumeMounts | default list) $component.extraVolumeMounts) | uniq }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    {{- with $component.extraContainers }}
    {{- if kindIs "slice" . }}
      {{- tpl (toYaml .) $ctx | nindent 4 }}
    {{- else if kindIs "string" . }}
      {{- tpl . $ctx | nindent 4 }}
    {{- end }}
    {{- end }}
  terminationGracePeriodSeconds: {{ $component.terminationGracePeriodSeconds }}
  {{- with $component.topologySpreadConstraints }}
  topologySpreadConstraints:
    {{- tpl . $ctx | nindent 4 }}
  {{- end }}
  {{- if $rolloutZoneName }}
  {{- with $rolloutZone.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- else }}
  {{- with $component.affinity }}
  affinity:
    {{- tpl . $ctx | nindent 4 }}
  {{- end }}
  {{- end }}
  {{- if $rolloutZoneName }}
  {{- with $rolloutZone.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- else }}
  {{- with (coalesce $component.nodeSelector .Values.defaults.nodeSelector) }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- end }}
  {{- with (coalesce $component.tolerations .Values.defaults.tolerations) }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  volumes:
    - name: config
      {{- include "tempo.configVolume" . | nindent 6 }}
    - name: runtime-config
      {{- include "tempo.runtimeVolume" . | nindent 6 }}
    {{- if $dataVolumeName }}
    {{- if not (dig "enabled" false $persistence) }}
    - name: {{ $dataVolumeName }}
      {{- if $dataEmptyDir }}
      emptyDir:
        {{- toYaml $dataEmptyDir | nindent 8 }}
      {{- else }}
      emptyDir: {}
      {{- end }}
    {{- else if dig "inMemory" false $persistence }}
    - name: {{ $dataVolumeName }}
      emptyDir:
        medium: Memory
        {{- with dig "size" "" $persistence }}
        sizeLimit: {{ . }}
        {{- end }}
    {{- end }}
    {{- else }}
    - name: tempo-{{ $target }}-store
      emptyDir: {}
    {{- end }}
    {{- if .Values.enterprise.enabled }}
    - name: license
      secret:
        secretName: {{ tpl .Values.license.secretName . }}
    {{- end }}
    {{- with (concat (.Values.global.extraVolumes | default list) (.Values.defaults.extraVolumes | default list) $component.extraVolumes) | uniq }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end }}
{{- end }}
