{{/*
Nombre fijo del servicio (values: nombre). Es tambien el nombre DNS del
Service: el gateway llama a http://catalogo:4001, http://pedidos:4003...
sin depender del nombre del release de ArgoCD.
*/}}
{{- define "aroma-comun.nombre" -}}
{{- required "Falta values.nombre" .Values.nombre -}}
{{- end -}}

{{- define "aroma-comun.etiquetas" -}}
app.kubernetes.io/name: {{ include "aroma-comun.nombre" . }}
app.kubernetes.io/version: {{ .Values.imagen.tag | quote }}
app.kubernetes.io/part-of: aroma
app.kubernetes.io/managed-by: {{ .Release.Service }}
ambiente: {{ required "Falta values.ambiente" .Values.ambiente }}
{{- end -}}

{{/*
Selector minimo e inmutable (el selector de un Deployment no puede
cambiar despues de creado; la version si cambia en cada release).
*/}}
{{- define "aroma-comun.selector" -}}
app.kubernetes.io/name: {{ include "aroma-comun.nombre" . }}
{{- end -}}

{{/*
Imagen con tag explicito y obligatorio: sin valor por defecto, para que
nunca termine en "latest" (Kyverno lo rechazaria y no es versionable).
*/}}
{{- define "aroma-comun.imagen" -}}
{{- $tag := required "Falta values.imagen.tag (nunca latest)" .Values.imagen.tag -}}
{{- if eq $tag "latest" }}{{ fail "imagen.tag no puede ser latest" }}{{ end -}}
{{- printf "%s:%s" .Values.imagen.repositorio $tag -}}
{{- end -}}

{{/*
Variables de conexion a PostgreSQL (recurso postgresql aroma-pg del
operador de Zalando). Usuario y contrasena salen del Secret que el
operador genera dentro del cluster; la URL se arma con la expansion
$(VAR) de Kubernetes, asi la contrasena nunca aparece en Git ni en un
ConfigMap. "parametros" agrega opciones de conexion (SSL).
*/}}
{{- define "aroma-comun.envBaseDeDatos" -}}
{{- if .Values.baseDeDatos.habilitada }}
- name: DB_USUARIO
  valueFrom:
    secretKeyRef: { name: {{ .Values.baseDeDatos.secreto }}, key: username }
- name: DB_CLAVE
  valueFrom:
    secretKeyRef: { name: {{ .Values.baseDeDatos.secreto }}, key: password }
- name: DATABASE_URL
  value: "{{ .Values.baseDeDatos.esquema }}://$(DB_USUARIO):$(DB_CLAVE)@{{ .Values.baseDeDatos.host }}:5432/{{ .Values.baseDeDatos.nombre }}{{ .Values.baseDeDatos.parametros | default "" }}"
{{- end }}
{{- end -}}

{{/*
Plantilla de Pod compartida por Deployment (servicios) y Rollout (gateway).
*/}}
{{- define "aroma-comun.plantillaPod" -}}
metadata:
  labels: {{- include "aroma-comun.etiquetas" . | nindent 4 }}
spec:
  serviceAccountName: {{ include "aroma-comun.nombre" . }}
  automountServiceAccountToken: false
  # Pod sin root (Kyverno exige runAsNonRoot). UID numerico porque las
  # imagenes declaran un usuario por nombre ("aroma") y Kubernetes no
  # puede verificar que un nombre no sea root.
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile: { type: RuntimeDefault }
  # Anti-afinidad PREFERIDA (no obligatoria): reparte las replicas entre
  # los dos workers, pero si uno se drena las replicas desalojadas pueden
  # reprogramarse en el otro. Con "required" quedarian Pending y el PDB
  # bloquearia el drenaje.
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          podAffinityTerm:
            topologyKey: kubernetes.io/hostname
            labelSelector:
              matchLabels: {{- include "aroma-comun.selector" . | nindent 16 }}
  containers:
    - name: {{ include "aroma-comun.nombre" . }}
      image: {{ include "aroma-comun.imagen" . }}
      imagePullPolicy: IfNotPresent
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities: { drop: ["ALL"] }
      ports:
        - name: http
          containerPort: {{ .Values.puerto }}
      env:
        - name: PUERTO
          value: {{ .Values.puerto | quote }}
        {{- range $k, $v := .Values.entorno }}
        - name: {{ $k }}
          value: {{ $v | quote }}
        {{- end }}
        {{- include "aroma-comun.envBaseDeDatos" . | nindent 8 }}
      # Limites obligatorios (Kyverno y ResourceQuota de aroma-prod).
      resources: {{- toYaml (required "Faltan values.recursos" .Values.recursos) | nindent 8 }}
      # Las tres sondas usan /salud, que cada servicio expone (puertos y
      # rutas tomados de P5/services/*/Dockerfile).
      startupProbe:
        httpGet: { path: /salud, port: http }
        periodSeconds: 3
        failureThreshold: 30
      livenessProbe:
        httpGet: { path: /salud, port: http }
        periodSeconds: 10
        timeoutSeconds: 3
        failureThreshold: 3
      readinessProbe:
        httpGet: { path: /salud, port: http }
        periodSeconds: 5
        timeoutSeconds: 2
        failureThreshold: 2
      volumeMounts:
        - name: tmp
          mountPath: /tmp
  volumes:
    # Raiz de solo lectura: Node y Python solo necesitan escribir en /tmp.
    - name: tmp
      emptyDir: { sizeLimit: 64Mi }
{{- end -}}
