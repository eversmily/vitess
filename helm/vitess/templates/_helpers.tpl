# Helper templates

#############################
# Format a flag map into a command line,
# as expected by the golang 'flag' package.
# Boolean flags must be given a value, such as "true" or "false".
#############################
{{- define "format-flags" -}}
{{- range $key, $value := . -}}
-{{$key}}={{$value | quote}}
{{end -}}
{{- end -}}

#############################
# Format a list of flag maps into a command line.
#############################
{{- define "format-flags-all" -}}
{{- range . }}{{template "format-flags" .}}{{end -}}
{{- end -}}

#############################
# Clean labels, making sure it starts and ends with [A-Za-z0-9].
# This is especially important for shard names, which can start or end with
# '-' (like -80 or 80-), which would be an invalid kubernetes label.
#############################
{{- define "clean-label" -}}
{{- $replaced_label := . | replace "_" "-"}}
{{- if hasPrefix "-" . -}}
x{{$replaced_label}}
{{- else if hasSuffix "-" . -}}
{{$replaced_label}}x
{{- else -}}
{{$replaced_label}}
{{- end -}}
{{- end -}}

#############################
# injects default vitess environment variables
#############################
{{- define "vitess-env" -}}
- name: VTROOT
  value: "/vt"
- name: VTDATAROOT
  value: "/vtdataroot"
- name: GOBIN
  value: "/vt/bin"
- name: VT_MYSQL_ROOT
  value: "/usr"
- name: PKG_CONFIG_PATH
  value: "/vt/lib"
{{- end -}}

#############################
# inject default pod security
#############################
{{- define "pod-security" -}}
securityContext:
  runAsUser: 1000
  fsGroup: 2000
  runAsNonRoot: true
{{- end -}}

#############################
# support region nodeAffinity if defined
#############################
{{- define "node-affinity" -}}
{{- $region := . -}}
{{ with $region }}
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: "failure-domain.beta.kubernetes.io/region"
        operator: In
        values: [{{ $region | quote }}]
{{- end -}}
{{- end -}}

#############################
# mycnf exec
#############################
{{- define "mycnf-exec" -}}

if [ "$VT_DB_FLAVOR" = "percona" ]; then
  FLAVOR_MYCNF=/vt/config/mycnf/master_mysql56.cnf

elif [ "$VT_DB_FLAVOR" = "mysql" ]; then
  FLAVOR_MYCNF=/vt/config/mycnf/master_mysql56.cnf

elif [ "$VT_DB_FLAVOR" = "maria" ]; then
  FLAVOR_MYCNF=/vt/config/mycnf/master_mariadb.cnf

fi

export EXTRA_MY_CNF="$FLAVOR_MYCNF:/vtdataroot/tabletdata/report-host.cnf:/vt/config/mycnf/rbr.cnf"

{{- end -}}

#############################
#
# all backup helpers below
#
#############################

#############################
# backup flags - expects config.backup
#############################
{{- define "backup-flags" -}}

{{ if .enabled }}
-restore_from_backup
-backup_storage_implementation=$VT_BACKUP_SERVICE

{{ if eq .backup_storage_implementation "gcs" }}
-gcs_backup_storage_bucket=$VT_GCS_BACKUP_STORAGE_BUCKET
-gcs_backup_storage_root=$VT_GCS_BACKUP_STORAGE_ROOT

{{ else if eq .backup_storage_implementation "s3" }}
-s3_backup_aws_region=$VT_S3_BACKUP_AWS_REGION
-s3_backup_storage_bucket=$VT_S3_BACKUP_STORAGE_BUCKET
-s3_backup_storage_root=$VT_S3_BACKUP_STORAGE_ROOT
-s3_backup_server_side_encryption=$VT_S3_BACKUP_SERVER_SIDE_ENCRYPTION
{{ end }}

{{ end }}

{{- end -}}

#############################
# backup env - expects config.backup
#############################
{{- define "backup-env" -}}

{{ if .enabled }}

- name: VT_BACKUP_SERVICE
  valueFrom:
    configMapKeyRef:
      name: vitess-cm
      key: backup.backup_storage_implementation

{{ if eq .backup_storage_implementation "gcs" }}

- name: VT_GCS_BACKUP_STORAGE_BUCKET
  valueFrom:
    configMapKeyRef:
      name: vitess-cm
      key: backup.gcs_backup_storage_bucket
- name: VT_GCS_BACKUP_STORAGE_ROOT
  valueFrom:
    configMapKeyRef:
      name: vitess-cm
      key: backup.gcs_backup_storage_root

{{ else if eq .backup_storage_implementation "s3" }}

- name: VT_S3_BACKUP_AWS_REGION
  valueFrom:
    configMapKeyRef:
      name: vitess-cm
      key: backup.s3_backup_aws_region
- name: VT_S3_BACKUP_STORAGE_BUCKET
  valueFrom:
    configMapKeyRef:
      name: vitess-cm
      key: backup.s3_backup_storage_bucket
- name: VT_S3_BACKUP_STORAGE_ROOT
  valueFrom:
    configMapKeyRef:
      name: vitess-cm
      key: backup.s3_backup_storage_root
- name: VT_S3_BACKUP_SERVER_SIDE_ENCRYPTION
  valueFrom:
    configMapKeyRef:
      name: vitess-cm
      key: backup.s3_backup_server_side_encryption

{{ end }}

{{ end }}

{{- end -}}

#############################
# backup volume - expects config.backup
#############################
{{- define "backup-volume" -}}

{{ if .enabled }}

  {{ if eq .backup_storage_implementation "gcs" }}

    {{ if .gcsSecret }}
- name: backup-creds
  secret:
    secretName: {{ .gcsSecret }}
    {{ end }}

  {{ else if eq .backup_storage_implementation "s3" }}

    {{ if .s3Secret }}
- name: backup-creds
  secret:
    secretName: {{ .s3Secret }}
    {{ end }}

  {{ end }}

{{ end }}

{{- end -}}

#############################
# backup volumeMount - expects config.backup
#############################
{{- define "backup-volumeMount" -}}

{{ if .enabled }}

  {{ if eq .backup_storage_implementation "gcs" }}

    {{ if .gcsSecret }}
- name: backup-creds
  mountPath: /etc/secrets/creds
    {{ end }}

  {{ else if eq .backup_storage_implementation "s3" }}

    {{ if .s3Secret }}
- name: backup-creds
  mountPath: /etc/secrets/creds
    {{ end }}

  {{ end }}

{{ end }}

{{- end -}}

#############################
# backup exec
#############################
{{- define "backup-exec" -}}

{{ if .enabled }}

credsPath=/etc/secrets/creds/$(ls /etc/secrets/creds/ | head -1)

{{ if eq .backup_storage_implementation "gcs" }}
export GOOGLE_APPLICATION_CREDENTIALS=$credsPath
cat $GOOGLE_APPLICATION_CREDENTIALS

{{ else if eq .backup_storage_implementation "s3" }}
export AWS_SHARED_CREDENTIALS_FILE=$credsPath
cat $AWS_SHARED_CREDENTIALS_FILE

{{ end }}

{{ end }}

{{- end -}}