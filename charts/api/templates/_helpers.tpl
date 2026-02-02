{{/*
Expand the name of the chart.
Uses Release.Name for resource naming (deployment identity)
*/}}
{{- define "api.name" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name - used for resource naming
Returns Release.Name for clean, simple resource names
*/}}
{{- define "api.fullname" -}}
{{- include "api.name" . }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels - for metadata only
These labels provide rich metadata but are NOT used for selection
*/}}
{{- define "api.labels" -}}
helm.sh/chart: {{ include "api.chart" . }}
app.kubernetes.io/name: {{ .Values.app.name }}
app.kubernetes.io/component: {{ .Values.app.component }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Values.app.partOf }}
app.kubernetes.io/part-of: {{ .Values.app.partOf }}
{{- end }}
{{- end }}

{{/*
Selector labels - for pod selection only
These labels MUST be minimal and immutable (used by Service and Deployment selectors)
Following Kubernetes best practices: app.kubernetes.io/name + app.kubernetes.io/component + instance + version
The version label is required for canary deployment strategies
*/}}
{{- define "api.selectorLabels" -}}
app.kubernetes.io/name: {{ .Values.app.name }}
app.kubernetes.io/component: {{ .Values.app.component }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
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
