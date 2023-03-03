{{-/* Template out all the built in settings to yaml in prep for merging with user specified plugin config. */
{{- define "spire-server.config-plugins-template" }}
{{ $namespace := .Release.Namespace }}
DataStore:
  sql:
    plugin_data:
      database_type: sqlite3
      connection_string: /run/spire/data/datastore.sqlite3
NodeAttestor:
  k8s_psat:
    plugin_data:
      clusters:
        {{ .Values.clusterName | quote }}:
          "service_account_allow_list":
          - "{{ .Release.Namespace }}:{{ .Release.Name }}-agent"
KeyManager:
  disk:
    plugin_data:
      keys_path: /run/spire/data/keys.json
Notifier:
  k8sbundle:
    plugin_data:
      namespace: "{{ .Release.Namespace }}"
      config_map: {{ .Values.bundleConfigMap | quote }}
{{- with .Values.upstreamAuthority.disk }}
{{- if eq (.enabled | toString) "true" }}
UpstreamAuthority:
  disk:
    plugin_data:
      cert_file_path": "/run/spire/upstream_ca/tls.crt"
      key_file_path": "/run/spire/upstream_ca/tls.key"
      {{- if ne .secret.data.bundle "" }}
      bundle_file_path: "/run/spire/upstream_ca/bundle.crt"
      {{- end }}
{{- end }}
{{- end }}

{{- with .Values.upstreamAuthority.certManager }}
{{- if eq (.enabled | toString) "true" }}
UpstreamAuthority:
  cert-manager:
    plugin_data:
      issuer_name: {{ .issuer_name | quote }}
      issuer_kind: {{ .issuer_kind | quote }}
      issuer_group: {{ .issuer_group | quote }}
      namespace: {{ default $namespace .namespace | quote }}
      {{- if ne .kube_config_file "" }}
      kube_config_file: {{ .kube_config_file | quote }}
      {{- end }}
{{- end }}
{{- end }}

{{- end }}

{{-/* Template out the config file while reformatting the merged plugin config into way spire expects. */
{{- define "spire-server.config-main-template" }}
{{- $pluginsStruct := tpl (include "spire-server.config-plugins-template" . ) . | fromYaml }}
{{- $pluginsMerged := $pluginsStruct | mustMerge .Values.plugins }}

{{/* Section to validate user provided values are still sane for deployment */
{{- if gt (len $pluginsMerged.DataStore) 1 }}
{{- fail "You can only have one DataStore configured" }}
{{- end }}

server:
  bind_address: 0.0.0.0
  bind_port: "8081"
  {{- .Values.config | toYaml | nindent 2 }}
plugins:
  {{- range $type, $v := $pluginsMerged }}
  {{ $type }}:
    {{- range $name, $v2 := $v }}
    - {{ $name }}: {{ $v2 | toYaml | nindent 8 }}
    {{- end }}
  {{- end }}
health_checks:
  listener_enabled: true
  bind_address: 0.0.0.0
  bind_port: "8080"
  live_path: /live
  ready_path: /ready
{{- if (dig "telemetry" "prometheus" "enabled" .Values.telemetry.prometheus.enabled .Values.global) }}
telemetry:
- Prometheus:
  - host: 0.0.0.0
    port: 9988
{{- end }}
{{- end }}
