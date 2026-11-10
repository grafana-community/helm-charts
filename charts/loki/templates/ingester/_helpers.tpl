{{/*
expects global context
*/}}
{{- define "loki.ingester.replicaCount" -}}
{{- ceil (divf .Values.ingester.replicas 3) -}}
{{- end -}}

{{/*
expects a dict
{
  "replicas": replicas in a zone,
  "ctx": global context
}
*/}}
{{- define "loki.ingester.maxUnavailable" -}}
{{- max 1 (ceil (mulf .replicas (divf (int .ctx.Values.ingester.zoneAwareReplication.maxUnavailablePct) 100))) -}}
{{- end -}}

{{/*
Return rollout-group prefix if it is set
*/}}
{{- define "loki.prefixRolloutGroup" -}}
{{- if .Values.ingester.rolloutGroupPrefix -}}
{{- .Values.ingester.rolloutGroupPrefix -}}-
{{- end -}}
{{- end -}}

{{/*
Return ingester name prefix if required
*/}}
{{- define "loki.prefixIngesterName" -}}
{{- if .Values.ingester.addIngesterNamePrefix -}}
loki-
{{- end -}}
{{- end -}}

{{/*
Return the zone-aware replication values of a rollout zone, e.g. zoneA for zone-a
expects a dict
{
  "rolloutZoneName": rollout zone name,
  "ctx": global context
}
*/}}
{{- define "loki.ingester.zoneValues" -}}
{{- dig (printf "zone%s" (upper (splitList "-" .rolloutZoneName | last))) (dict) .ctx.Values.ingester.zoneAwareReplication | toYaml -}}
{{- end -}}

{{/*
Return true if the rollout zone is labeled for the rollout-operator prepare-downscale webhook
expects a dict
{
  "rolloutZoneName": rollout zone name,
  "ctx": global context
}
*/}}
{{- define "loki.ingester.zonePreparesDownscale" -}}
{{- $zone := include "loki.ingester.zoneValues" . | fromYaml -}}
{{- and (not $zone.noDownscale) ($zone.prepareDownscale | default false) -}}
{{- end -}}

{{/*
Rollout-operator downscale labels for an ingester zone StatefulSet
See https://github.com/grafana/rollout-operator#how-scaling-up-and-down-works
expects a dict
{
  "rolloutZoneName": rollout zone name,
  "ctx": global context
}
*/}}
{{- define "loki.ingester.zoneDownscaleLabels" -}}
{{- $zone := include "loki.ingester.zoneValues" . | fromYaml -}}
{{- if $zone.noDownscale }}
grafana.com/no-downscale: "true"
{{- else if eq (include "loki.ingester.zonePreparesDownscale" .) "true" }}
grafana.com/prepare-downscale: "true"
{{- end }}
{{- end -}}

{{/*
Rollout-operator downscale annotations for an ingester zone StatefulSet.
Without an explicit downscaleLeader, the previous zone leads the downscale when both zones
prepare downscales and the rollout-operator webhooks are enabled.
expects a dict
{
  "rolloutZoneName": rollout zone name,
  "ctx": global context
}
*/}}
{{- define "loki.ingester.zoneDownscaleAnnotations" -}}
{{- $ctx := .ctx -}}
{{- $zone := include "loki.ingester.zoneValues" . | fromYaml -}}
{{- $annotations := dict -}}
{{- if eq (include "loki.ingester.zonePreparesDownscale" .) "true" -}}
{{- $_ := set $annotations "grafana.com/prepare-downscale-http-path" "ingester/prepare_shutdown" -}}
{{- $_ := set $annotations "grafana.com/prepare-downscale-http-port" ($ctx.Values.loki.server.http_listen_port | toString) -}}
{{- with $ctx.Values.ingester.zoneAwareReplication.minTimeBetweenZonesDownscale -}}
{{- $_ := set $annotations "grafana.com/min-time-between-zones-downscale" . -}}
{{- end -}}
{{- end -}}
{{- $downscaleLeader := $zone.downscaleLeader -}}
{{- $zones := list "zone-a" "zone-b" "zone-c" -}}
{{- $zoneIdx := 0 -}}
{{- range $i, $zoneName := $zones -}}
{{- if eq $zoneName $.rolloutZoneName -}}
{{- $zoneIdx = $i -}}
{{- end -}}
{{- end -}}
{{- if and (not $downscaleLeader) (gt $zoneIdx 0) (dig "enabled" false $ctx.Values.rollout_operator) (dig "webhooks" "enabled" false $ctx.Values.rollout_operator) (eq (include "loki.ingester.zonePreparesDownscale" .) "true") -}}
{{- $previousZone := index $zones (sub $zoneIdx 1) -}}
{{- if eq (include "loki.ingester.zonePreparesDownscale" (dict "ctx" $ctx "rolloutZoneName" $previousZone)) "true" -}}
{{- $downscaleLeader = include "loki.workloadResourceName" (dict "ctx" $ctx "component" "ingester" "componentValues" $ctx.Values.ingester "rolloutZoneName" $previousZone) -}}
{{- end -}}
{{- end -}}
{{- with $downscaleLeader -}}
{{- $_ := set $annotations "grafana.com/rollout-downscale-leader" (tpl . $ctx) -}}
{{- end -}}
{{- $annotations | toYaml -}}
{{- end -}}
