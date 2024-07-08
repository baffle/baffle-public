{{/*
Checking if the Secret with Credstore Password is configured
*/}}
{{- define "gen.dsbsecret" -}}
{{- $dsbsecret := (lookup "v1" "Secret" .Release.Namespace "dsb-secret") -}}
{{- if $dsbsecret -}}
{{/*
   Reusing the existing secret data
*/}}
{{- $secretData := (get $dsbsecret "data") }}
{{- range $key, $value := $secretData }}
{{ $key }}: {{ $value }}
{{- end -}}
{{- else -}}
{{/*
    Create a new secret with credstore password
*/}}
dsbCredstorePassword: {{ tpl ("{'kmsType': 'local', 'baffle_secret': '{{ required \"credstorePass is required and must be the same password set in DSB Manager.\" .Values.dsbShield.secret.credstorePass }}'}") . | b64enc }}
{{- end -}}
{{- end -}}
