{{- define "dashboard.labels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/name: dashboard
app.kubernetes.io/version: {{ .Values.imageTag }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}
{{- end }}

{{- define "dashboard.testLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/name: dashboard-tests
app.kubernetes.io/version: {{ .Values.imageTag }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}
{{- end }}
