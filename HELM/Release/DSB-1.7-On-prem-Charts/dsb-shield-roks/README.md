<!--- app-name: dsbshield -->

# IBM Cloud Data Security Broker Helm Chart


## Parameters

### Security Context

| Name                                | Description                                                          | Value                                                                                       |
| ------------------------------------|----------------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| `dsbShield.secret.credstorePass`                    |Only if DSB Manager is installed in a different namespace. Enter a password used for Encryption (i.e. secrets.credstorePass) while installing DSB Manager.               | `""`                                                                         |
| `dsbShield.deployment.name`                    |Only if you are deploying one more shield in same namespace, else leave it as it is. Enter a unique name for deployment for Data Security Broker Shield               | `"dsb-shield-app1"`                                                                         |
| `dsbShield.service.name`                    |Only if you are deploying one more shield in same namespace, else leave it as it is. Enter a unique name for service name for Data Security Broker Shield               | `"dsb-shield-app1"`                                                                         |
| `dsbShield.configMap.name`                    |Only if you are deploying one more shield in same namespace, else leave it as it is. Enter a unique name for configmap for Data Security Broker Shield               | `"dsb-shield-app1"`                                                                         |
| `dsbShield.configMap.data.BM_SHIELD_SYNC_ID`    |Provide the Data Security Broker Shield Sync ID. [See](https://test.cloud.ibm.com/docs/security-broker?topic=security-broker-sb_install_catalog#sb_install_ui_procedure) for more details on how to fetch the Shield Sync ID from the Data Security Broker Manager.                   | `"IyNTSElFTEQjIzE3Mi4zMC40NC4yMDQjIzQ0MyMjaWJtIyM2MzA0ZWJjMTU3NzQyYTBkZTJkZDVmZmYjIzg0NDQ="`|
| `dsbShield.configMap.data.BM_IP`                    | Only if DSB Manager is installed in different namespace else leave this value as it is i.e. dsb-nginx , If DSB Manager in different namespace then add namespace for e.g. "dsb-nginx.<namespace>", If DSB Manager in different cluster then replace "dsb-nginx" with Public URL/IP of DSB Manager           | `"dsb-nginx"` |
