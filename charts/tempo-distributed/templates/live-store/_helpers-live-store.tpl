{{/*
Rollout zones for the live-store.

Returns a map keyed by zone name. The key "" is used when zone-aware replication
is disabled and renders the single flat StatefulSet.

Each zone runs a full set of live-stores. A live-store derives its Kafka
partition from the numeric suffix of its pod name, and its Kafka consumer group
defaults to its own pod name because the chart leaves ingest.kafka.consumer_group
unset. Every zone therefore consumes all partitions independently and each
partition ends up with one owner per zone. Therefore the replica count of a zone
is liveStore.replicas, not a share of it.

Params:
  ctx = root context ($)
*/}}
{{- define "live-store.zoneAwareReplicationMap" -}}
{{- $ctx := .ctx -}}
{{- $zonesMap := dict -}}
{{- $liveStore := .ctx.Values.liveStore -}}
{{- $zoneAware := $liveStore.zoneAwareReplication | default dict -}}
{{- $replicas := $liveStore.replicas | int -}}
{{- if $zoneAware.enabled -}}
{{- $zones := $zoneAware.zones | default list -}}
{{- if lt (len $zones) 2 -}}
{{- fail "liveStore.zoneAwareReplication.zones must define at least 2 zones. A partition needs an owner in more than one zone before the read path can survive the loss of a zone." -}}
{{- end -}}
{{- $zoneNames := list -}}
{{- range $zones -}}
{{- if not .name -}}
{{- fail "every entry of liveStore.zoneAwareReplication.zones must set a name." -}}
{{- end -}}
{{- if not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" (.name | toString)) -}}
{{- fail (printf "liveStore.zoneAwareReplication zone name %q is not a DNS label. A zone name becomes both a StatefulSet name suffix and the value of the zone label, so it must hold lowercase letters, digits and dashes only, and start and end with a letter or a digit." .name) -}}
{{- end -}}
{{- $zoneNames = append $zoneNames .name -}}
{{- end -}}
{{- if ne (len ($zoneNames | uniq)) (len $zoneNames) -}}
{{- fail "liveStore.zoneAwareReplication.zones must have unique names." -}}
{{- end -}}
{{- $baseAffinity := dict -}}
{{- with $liveStore.affinity -}}
{{- if kindIs "string" . -}}
{{- $baseAffinity = tpl . $ctx | fromYaml -}}
{{- else -}}
{{- $baseAffinity = . -}}
{{- end -}}
{{- end -}}
{{- $baseNodeSelector := coalesce $liveStore.nodeSelector $ctx.Values.defaults.nodeSelector | default dict -}}
{{- range $zone := $zones -}}
{{- $antiAffinity := include "live-store.zoneAntiAffinity" (dict "ctx" $ctx "rolloutZoneName" $zone.name "topologyKey" $zoneAware.topologyKey) | fromYaml -}}
{{- $affinity := mergeOverwrite (deepCopy $baseAffinity) (deepCopy ($zone.extraAffinity | default dict)) $antiAffinity -}}
{{- $_ := set $zonesMap $zone.name (dict
      "affinity" $affinity
      "nodeSelector" (mergeOverwrite (deepCopy $baseNodeSelector) ($zone.nodeSelector | default dict))
      "annotations" ($zone.annotations | default dict)
      "podAnnotations" ($zone.podAnnotations | default dict)
      "replicas" $replicas
    ) -}}
{{- end -}}
{{- else -}}
{{- $_ := set $zonesMap "" (dict "replicas" $replicas) -}}
{{- end -}}
{{- $zonesMap | toYaml -}}
{{- end -}}

{{/*
Anti-affinity that keeps the live-stores of one zone away from the nodes, racks
or availability zones that already run another zone. The selector is scoped to
this release, so two tempo releases in one namespace do not push each other
apart. Renders an empty dict when no topologyKey is set.

Params:
  ctx             = root context ($)
  rolloutZoneName = name of the rollout zone
  topologyKey     = topology key of the failure domain
*/}}
{{- define "live-store.zoneAntiAffinity" -}}
{{- if .topologyKey -}}
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
              - {{ include "tempo.name" .ctx }}
          - key: app.kubernetes.io/instance
            operator: In
            values:
              - {{ .ctx.Release.Name }}
          - key: rollout-group
            operator: In
            values:
              - live-store
          - key: zone
            operator: NotIn
            values:
              - {{ .rolloutZoneName }}
      topologyKey: {{ .topologyKey | quote }}
{{- else -}}
{}
{{- end -}}
{{- end -}}
