{{/*
Expand the name of the chart.
*/}}
{{- define "api.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name - used for test pod naming
Returns Release.Name-Chart.Name for test resources
*/}}
{{- define "api.fullname" -}}
{{- printf "%s-%s-%s" .Release.Name .Chart.Name .Values.version | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels - for metadata only
These labels provide rich metadata but are NOT used for selection
*/}}
{{- define "api.labels" -}}
helm.sh/chart: {{ include "api.chart" . }}
app.kubernetes.io/name: {{ include "api.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels - for pod selection only
These labels MUST be minimal and immutable (used by Service and Deployment selectors)
Following Kubernetes best practices: app.kubernetes.io/name + app.kubernetes.io/instance + version
The version label is required for canary deployment strategies
*/}}
{{- define "api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "api.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.version }}
{{- end }}

{{/*
Resource-specific naming helpers
These provide explicit, declarative names for each Kubernetes resource type
*/}}

{{/*
Deployment name - uses fullname with no suffix
*/}}
{{- define "api.deployment.name" -}}
{{- include "api.fullname" . | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Service name - uses fullname with -service suffix
*/}}
{{- define "api.service.name" -}}
{{- printf "%s-service" (include "api.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
HPA name - uses fullname with -hpa suffix
*/}}
{{- define "api.hpa.name" -}}
{{- printf "%s-hpa" (include "api.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
VirtualService name - uses fullname with -virtualservice suffix
*/}}
{{- define "api.virtualservice.name" -}}
{{- printf "%s-virtualservice" (include "api.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
ServiceAccount name - uses fullname with -serviceaccount suffix
*/}}
{{- define "api.serviceaccount.name" -}}
{{- printf "%s-serviceaccount" (include "api.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Default node affinity - spreads pods across nodes for hardware resilience
Uses preferredDuringScheduling with weight 100 (high priority)
Matches pods by app.kubernetes.io/name label
*/}}
{{- define "api.nodeAffinity" -}}
- weight: 100
  podAffinityTerm:
    labelSelector:
      matchExpressions:
        - key: app.kubernetes.io/name
          operator: In
          values:
            - {{ include "api.fullname" . }}
    topologyKey: kubernetes.io/hostname
{{- end }}

{{/*
Default zone affinity - spreads pods across availability zones for datacenter resilience
Uses preferredDuringScheduling with weight 50 (lower than node)
Matches pods by app.kubernetes.io/name label
*/}}
{{- define "api.zoneAffinity" -}}
- weight: 50
  podAffinityTerm:
    labelSelector:
      matchExpressions:
        - key: app.kubernetes.io/name
          operator: In
          values:
            - {{ include "api.fullname" . }}
    topologyKey: topology.kubernetes.io/zone
{{- end }}
