{{- define "dashboard.labels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/name: dashboard
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}
{{- end }}
