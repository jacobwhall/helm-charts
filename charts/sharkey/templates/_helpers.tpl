{{/*
Chart full name
*/}}
{{- define "sharkey.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "sharkey.labels" -}}
app.kubernetes.io/name: sharkey
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "sharkey.selectorLabels" -}}
app.kubernetes.io/name: sharkey
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
PostgreSQL host — CNPG creates a -rw service
*/}}
{{- define "sharkey.dbHost" -}}
{{- if .Values.cnpg.enabled -}}
  {{- printf "%s-db-rw" (include "sharkey.fullname" .) -}}
{{- else -}}
  {{- .Values.externalDatabase.host -}}
{{- end -}}
{{- end -}}

{{/*
Valkey host — official valkey-helm chart creates <release>-valkey
*/}}
{{- define "sharkey.valkeyHost" -}}
{{- if .Values.valkey.enabled -}}
  {{- printf "%s-valkey" .Release.Name -}}
{{- else -}}
  {{- .Values.externalValkey.host | default "" -}}
{{- end -}}
{{- end -}}

{{/*
Valkey password — pull from values
*/}}
{{- define "sharkey.valkeyPassword" -}}
{{- if and .Values.valkey.enabled .Values.valkey.auth.enabled -}}
  {{- (index .Values.valkey.auth.aclUsers "default").password | default "" -}}
{{- else -}}
  {{- "" -}}
{{- end -}}
{{- end -}}

{{/*
Meilisearch host
*/}}
{{- define "sharkey.meilisearchHost" -}}
{{- if .Values.meilisearch.enabled -}}
  {{- printf "%s-meilisearch" .Release.Name -}}
{{- else -}}
  {{- .Values.externalMeilisearch.host | default "" -}}
{{- end -}}
{{- end -}}

{{/*
CNPG cluster name
*/}}
{{- define "sharkey.cnpgClusterName" -}}
{{- printf "%s-db" (include "sharkey.fullname" .) -}}
{{- end -}}

{{/*
Barman ObjectStore name for ongoing backups
*/}}
{{- define "sharkey.cnpgBackupStoreName" -}}
{{- default (printf "%s-backup-store" (include "sharkey.fullname" .)) .Values.cnpg.backup.objectStoreName -}}
{{- end -}}

{{/*
Barman ObjectStore name used as the bootstrap recovery source
*/}}
{{- define "sharkey.cnpgRecoverStoreName" -}}
{{- default (printf "%s-recover-store" (include "sharkey.fullname" .)) .Values.cnpg.recover.objectStoreName -}}
{{- end -}}
