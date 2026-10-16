{{/* Deployment estandar de un microservicio. */}}
{{- define "aroma-comun.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "aroma-comun.nombre" . }}
  labels: {{- include "aroma-comun.etiquetas" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicas }}
  revisionHistoryLimit: 3
  strategy:
    type: RollingUpdate
    # Nunca bajar de las replicas declaradas durante una actualizacion.
    rollingUpdate: { maxUnavailable: 0, maxSurge: 1 }
  selector:
    matchLabels: {{- include "aroma-comun.selector" . | nindent 6 }}
  template: {{- include "aroma-comun.plantillaPod" . | nindent 4 }}
{{- end -}}

{{/* Service ClusterIP con el nombre fijo del servicio. */}}
{{- define "aroma-comun.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "aroma-comun.nombre" . }}
  labels: {{- include "aroma-comun.etiquetas" . | nindent 4 }}
spec:
  type: ClusterIP
  selector: {{- include "aroma-comun.selector" . | nindent 4 }}
  ports:
    - name: http
      port: {{ .Values.puerto }}
      targetPort: http
{{- end -}}

{{/*
PodDisruptionBudget: un "kubectl drain" no puede desalojar replicas si
quedarian menos de minDisponibles en ejecucion.
*/}}
{{- define "aroma-comun.pdb" -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "aroma-comun.nombre" . }}
  labels: {{- include "aroma-comun.etiquetas" . | nindent 4 }}
spec:
  minAvailable: {{ .Values.pdb.minDisponibles }}
  selector:
    matchLabels: {{- include "aroma-comun.selector" . | nindent 6 }}
{{- end -}}

{{/* ServiceAccount propia, sin token montado (los servicios no usan la API). */}}
{{- define "aroma-comun.serviceaccount" -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "aroma-comun.nombre" . }}
  labels: {{- include "aroma-comun.etiquetas" . | nindent 4 }}
automountServiceAccountToken: false
{{- end -}}
