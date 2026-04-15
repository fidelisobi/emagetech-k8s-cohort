{{/*
_helpers.tpl — reusable template snippets
==========================================
Helm's "partial" system.  Snippets defined here are called from other
templates with {{ include "student-app.<name>" . }}
*/}}

{{/* Expand the chart name */}}
{{- define "student-app.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Create a default fully qualified app name */}}
{{- define "student-app.fullname" -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Chart label — used in selector labels */}}
{{- define "student-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Common labels applied to every resource */}}
{{- define "student-app.labels" -}}
helm.sh/chart: {{ include "student-app.chart" . }}
app.kubernetes.io/name: {{ include "student-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Selector labels for the API Deployment / Service */}}
{{- define "student-app.api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "student-app.name" . }}-api
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Selector labels for the Frontend Deployment / Service */}}
{{- define "student-app.frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "student-app.name" . }}-frontend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* PostgreSQL hostname — resolves to the bitnami sub-chart Service name */}}
{{- define "student-app.postgresql.host" -}}
{{- printf "%s-postgresql" .Release.Name }}
{{- end }}
