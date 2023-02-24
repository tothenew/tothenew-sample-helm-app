{{/*
Default Template for Cluster Role. All Sub-Charts under this Chart can include the below template.
*/}}
{{- define "apps.clusterroletemplate" }}
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
    name: "{{ .Values.appName }}-service-role"
    namespace: "{{ $.Release.Namespace }}"
rules:
- apiGroups:
  - ""
  resources:
  - "*"
  verbs:
  - "*"
- apiGroups:
  - rbac.authorization.k8s.io
  resources:
  - "*"
  verbs:
  - "*"
- apiGroups:
  - apiextensions.k8s.io
  resources:
  - customresourcedefinitions
  verbs:
  - get
  - list
  - watch
  - create
  - delete
{{- end }}


{{/*
Default Template for Service Account. All Sub-Charts under this Chart can include the below template.
*/}}
{{- define "apps.serviceaccounttemplate" }}
apiVersion: v1
kind: ServiceAccount
metadata:
    name: "{{ .Values.appName }}-service-role"
    namespace: "{{ $.Release.Namespace }}"
    annotations:
      eks.amazonaws.com/role-arn: {{ $.Values.global.ssmCsiRole }}

{{- end }}


{{/*
Default Template for Cluster Role Binding. All Sub-Charts under this Chart can include the below template.
*/}}
{{- define "apps.rolebindingtemplate" }}
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
    name: "{{ .Values.appName }}-service-role"
    namespace: "{{ $.Release.Namespace }}"
subjects:
-   kind: ServiceAccount
    name: "{{ .Values.appName }}-service-role"
    namespace: "{{ $.Release.Namespace }}"
roleRef:
    kind: ClusterRole
    name: "{{ .Values.appName }}-service-role"
    apiGroup: rbac.authorization.k8s.io
{{- end }}


{{/*
Default Template for Service. All Sub-Charts under this Chart can include the below template.
*/}}
{{- define "apps.servicetemplate" }}
apiVersion: v1
kind: Service
metadata:
    name: "svc-{{ .Values.appName }}"
    namespace: "{{ $.Release.Namespace }}"
spec:
    ports:
        -   name: www
            port: 80
            protocol: TCP
            targetPort: {{ .Values.resources.containerInfo.containerPort }}
    selector:
        run: {{ .Values.appName }}
    type: ClusterIP
{{- end }}


{{/*
Default Template for HPA. All Sub-Charts under this Chart can include the below template.
*/}}
{{- define "apps.hpatemplate" }}
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2beta1
kind: HorizontalPodAutoscaler
metadata:
    name: {{ .Values.appName }}
    namespace: {{ $.Release.Namespace }}
    labels:
        app: {{ .Values.appName }}
spec:
    scaleTargetRef:
        apiVersion: apps/v1beta1
        kind: Deployment
        name: {{ .Values.appName }}
    minReplicas: {{ .Values.autoscaling.minReplicas }}
    maxReplicas: {{ .Values.autoscaling.maxReplicas }}
    metrics:
        -   type: Resource
            resource:
                name: cpu
                target:
                    type: Utilization
                    averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
        -   type: Resource
            resource:
                name: memory
                target:
                    type: Utilization
                    averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}
{{- end }}


{{/*
Default Template for Secret Provider Class. All Sub-Charts under this Chart can include the below template.
*/}}
{{- define "apps.spctemplate" }}
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: aws-secrets2
  namespace: {{ $.Release.Namespace }}
spec:
  provider: aws
  secretObjects:
    - secretName: vr-creds
      type: Opaque
      data:
        - objectName: rds-endpoint
          key: DATABASE_HOST_STRING_Secret
        - objectName: rds-password
          key: DB_PASSWORD_Secret
        - objectName: rds-user
          key: DB_USER_NAME_Secret
        - objectName: rds-name
          key: DATABASE_NAME_Secret
  parameters:
    objects: |
        - objectName: "/{{ $.Release.Namespace }}/RDS/ENDPOINT"
          objectType: "ssmparameter"
          objectAlias: rds-endpoint
        - objectName: "/{{ $.Release.Namespace }}/RDS/PASSWORD"
          objectType: "ssmparameter"
          objectAlias: rds-password
        - objectName: "/{{ $.Release.Namespace }}/RDS/USER"
          objectType: "ssmparameter"
          objectAlias: rds-user
        - objectName: "/{{ $.Release.Namespace }}/RDS/NAME"
          objectType: "ssmparameter"
          objectAlias: rds-name
{{- end }}

{{/*
Default Template for Secret-Provider-Class-Volume. All Sub-Charts under this Chart can include the below template.
*/}}
{{- define "apps.spcvolume" }}
volumes:
- name: creds-volume
  csi:
    driver: secrets-store.csi.k8s.io
    readOnly: true
    volumeAttributes:
        secretProviderClass: aws-secrets2
{{- end }}

{{- define "java-app.defaultEnvVars" -}}
- name: MODULE
  value: {{ .Values.appName }}
- name: ENV
  value: dev
{{- end }}

{{- define "swagger-host.dnsValue" -}}
- name: SWAGGER_HOST
  value: "{{ .Values.global.prefix }}-{{ .Release.Namespace }}.demo.videoready.tv"
{{- end }}

{{- define "ingress-ssl-redirect-block" -}}
- http:
    paths:
    - path: /
      pathType: Prefix
      backend:
        service:
          name: ssl-redirect
          port:
            name: use-annotation
{{- end }}

{{/*
Default Template for Ingress. All Sub-Charts under this Chart can include the below template.
*/}}
{{- define "apps.ingresstemplate" }}
{{- with .Values.ingress }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $.Values.appName }}-ingress
  namespace: {{ $.Release.Namespace }}
  labels:
    app: {{ $.Values.appName }}-ingress
  {{- with .annotations }}
  annotations:
    {{- toYaml . | nindent 4 -}}
  {{- end }}
    {{- if .ssl_redirect }}
    alb.ingress.kubernetes.io/actions.ssl-redirect: '{"Type": "redirect", "RedirectConfig": { "Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}'
    {{- end }}
spec:
  rules:
    {{ if .ssl_redirect }}
    {{ include "ingress-ssl-redirect-block" . | nindent 4 }}
    {{ end }}
    - http:
        paths:
        {{- range .paths }}
          - path: {{ .path }}
            pathType: Prefix
            backend:
              service:
                name: {{ .serviceName }}
                port:
                  number: {{ .servicePort }}
        {{- end }}
    {{- end }}
{{- end }}
