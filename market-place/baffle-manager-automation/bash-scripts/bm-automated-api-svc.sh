#!/bin/bash

# Input parameters
username=$USERNAME
password=$PASSWORD
#Keystore info
aws_region=$KM_AWS_REGION
s3_bucket_name=$KM_S3_BUCKET_NAME
# Kek info
kek_name=$KM_KEK_NAME
kek_name_1=$KM_KEK_NAME_1
kek_name_2=$KM_KEK_NAME_2

execute_workflow=$EXECUTE_WORKFLOW
# Base URL
base_url="https://localhost:443"

# Login API URL
checkAppUrl="$base_url/api/public/v2/application_access_check"
registration_url="$base_url/api/public/v2/init"
login_url="$base_url/api/public/v2/auth"

aws_kms_url="$base_url/api/v2/keystores/awskms"
kek_url="$base_url/api/v2/key-management/keks"
tenant_url="$base_url/api/v2/key-management/tenants"
api_service_url="$base_url/api/v3/api-svc/clusters"
permission_url="$base_url/api/v3/api-svc/permissions"

# Function to send a GET request and process the response
send_get_request() {
  local jwt_token=$1
  local url=$2


  # Send the GET request
  local response=$(curl -k -s -w "\n%{http_code}" -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $jwt_token" "$url")

  # Extract the status code from the last line
  local status_code=$(echo "$response" | tail -n1)

  # Remove the status code from the response
  response=$(echo "$response" | sed '$d')

  # Check if the status code is 200
  if [ "$status_code" -eq 200 ]; then
    # Parse the id from the response
    local id=$(echo "$response" | jq -r '.id')
    echo "$id"
  else
    echo "Request failed with status code: $status_code" >&2
    echo "error"
  fi
}

# Function to send a POST request and process the response
send_post_request() {
  local jwt_token=$1
  local url=$2
  local payload=$3
  local fields=("$@") # Capture all arguments into an array
  unset fields[0] fields[1] fields[2] # Remove the first three arguments which are jwt_token, url, and payload
  # Send the POST request
  # if jwt_token is null, then no need to pass Authorization header
  if [ "$jwt_token" == "null" ]; then
    local response=$(curl -k -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -d "$payload" "$url")
  else
    local response=$(curl -k -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $jwt_token" -d "$payload" "$url")
  fi

  # Extract the status code from the last line
  local status_code=$(echo "$response" | tail -n1)

  # Remove the status code from the response
  response=$(echo "$response" | sed '$d')

# Check if the status code is 200 or 201 or 204
  if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 201 ] || [ "$status_code" -eq 204 ]; then
    # Parse the fields from the response
    local parsed_fields=""
    for i in "${!fields[@]}"; do
      local value=$(echo "$response" | jq -r --arg field "${fields[$i]}" '.[$field]')
      # If it's the last element, don't add a space
      if (( i == ${#fields[@]}-1 )) || (( ${#fields[@]} == 1 )); then
        parsed_fields+="$value"
      else
        parsed_fields+="$value "
      fi
    done
    echo "$parsed_fields"
  else
    echo "Request to $url failed with status code: $status_code" >&2
    echo "error"
  fi
}

# Get AWS KMS payload
get_aws_kms_payload(){
  # convert from AWS region to java enum
  declare -A region_map=(
  ["us-east-1"]="US_EAST_1"
  ["us-east-2"]="US_EAST_2"
  ["us-west-1"]="US_WEST_1"
  ["us-west-2"]="US_WEST_2"
  ["af-south-1"]="AF_SOUTH_1"
  ["ap-east-1"]="AP_EAST_1"
  ["ap-south-1"]="AP_SOUTH_1"
  ["ap-south-2"]="AP_SOUTH_2"
  ["ap-southeast-1"]="AP_SOUTHEAST_1"
  ["ap-southeast-2"]="AP_SOUTHEAST_2"
  ["ap-southeast-3"]="AP_SOUTHEAST_3"
  ["ap-northeast-1"]="AP_NORTHEAST_1"
  ["ap-northeast-2"]="AP_NORTHEAST_2"
  ["ap-northeast-3"]="AP_NORTHEAST_3"
  ["ca-central-1"]="CA_CENTRAL_1"
  ["eu-central-1"]="EU_CENTRAL_1"
  ["eu-central-2"]="EU_CENTRAL_2"
  ["eu-west-1"]="EU_WEST_1"
  ["eu-west-2"]="EU_WEST_2"
  ["eu-west-3"]="EU_WEST_3"
  ["eu-south-1"]="EU_SOUTH_1"
  ["eu-south-2"]="EU_SOUTH_2"
  ["eu-north-1"]="EU_NORTH_1"
  ["me-central-1"]="ME_CENTRAL_1"
  ["sa-east-1"]="SA_EAST_1"
  ["us-gov-east-1"]="US_GOV_EAST_1"
  ["us-gov-west-1"]="US_GOV_WEST_1"
  )

  aws_region=${region_map[$aws_region]:-"US_WEST_2"}
  aws_kms_payload=$(jq -n \
                  --arg awsRegion "$aws_region" \
                  --arg bucketName "$s3_bucket_name" \
                  '{
                    "name": "aws-kms",
                    "kmsType": "AWS_KMS",
                    "awsRegion": $awsRegion,
                    "dekStoreType": "S3",
                    "s3StorePayload": {
                      "sseSupported": false,
                      "bucketName": $bucketName
                    },
                    "authenticationMethod": "IAM_ROLE"
                  }')

  echo "$aws_kms_payload"
}

# Get KEK payload
get_kek_payload(){
  name=$1
  kestore_id=$2
  kek_payload=$(jq -n \
                --arg name "$name" \
                --arg kestore_id "$kestore_id" \
                '{
                  "name": $name,
                  "keystore": {
                    "id": $kestore_id
                  },
                  "createNewDek": false,
                  "dekFilePrefix": ("baffle-" + $name)
                }')

  echo "$kek_payload"
}

# Get DEK payload
get_dek_payload(){
  kek_id=$1
  random_number=$((RANDOM % 1000 + 1)) # Generate a random number between 1 and 100
  dek_payload=$(jq -n \
                    --arg kek_id "$kek_id" \
                    --argjson random_number "$random_number" \
                    '{
                      "name": ("baffle-dek-" + ($random_number|tostring)),
                      "kek": {
                        "id": $kek_id
                      }
                    }')
  echo "$dek_payload"
}

# Get Tenant payload
get_tenant_payload(){
  name=$1
  identifier=$2
  keystore=$3
  kek=$4
  dek_name=$5

  tenant_payload=$(jq -n \
                --arg name "$name" \
                --arg identifier "$identifier" \
                --arg keystore "$keystore" \
                --arg kek "$kek" \
                --arg dek_name "$dek_name" \
                '{
                  "name": $name,
                  "identifier": $identifier,
                  "keystore": {
                    "id": $keystore
                  },
                  "kek": {
                    "id": $kek
                  },
                  "dekName": $dek_name
                }')

  echo "$tenant_payload"
}

# Get api permission payload
get_permission_payload(){
  name=$1
  roles=$2
  permissions=$3
  permission_payload=$(jq -n \
                --arg name "$name" \
                --arg roles "$roles" \
                '{
                  "name": $name,
                  "roles": [$roles],
                  "permissions": '"$permissions"'
                }')

  echo "$permission_payload"
}

# Get api permission payload
get_add_permission_payload(){
  permission_payload=$(jq -n \
                --arg all_permission_id "$all_permission_id" \
                --arg encrypt_permission_id "$encrypt_permission_id" \
                --arg decrypt_permission_id "$decrypt_permission_id" \
                '{
                  "addedPermissions": [
                  {"id" : $all_permission_id},
                  {"id" : $encrypt_permission_id},
                  {"id" : $decrypt_permission_id}]
                }')

  echo "$permission_payload"
}


# Get Tenant api  enroll payload
get_tenant_enroll_payload(){
  tenant_id=$1

  tenant_payload=$(jq -n \
                --arg tenant_id "$tenant_id" \
                --arg all_permission_id "$all_permission_id" \
                --arg encrypt_permission_id "$encrypt_permission_id" \
                --arg decrypt_permission_id "$decrypt_permission_id" \
                '{
                  "tenantKey": {
                     "id": $tenant_id
                  },
                  "permissions":[
                  {"id" : $all_permission_id},
                  {"id" : $encrypt_permission_id},
                  {"id" : $decrypt_permission_id}
                  ]
                }')

  echo "$tenant_payload"
}

# Get deploy payload
get_deploy_payload(){
  name=$1

  deploy_payload=$(jq -n \
                --arg name "$name" \
                '{
                  "name" : $name
                }')

  echo "$deploy_payload"
}


# Get cle api payload
get_api_svc_cle_payload(){
  api_svc_cle_payload=$(jq -n \
                        --arg name "$1" \
                        --arg aws_kms_id "$2" \
                        --arg kek_id "$3" \
                        '{
                          "name": $name,
                          "global": true,
                          "multiTenancy": false,
                          "globalEnc": {
                            "keystore": {
                              "id": $aws_kms_id
                            },
                            "kek": {
                              "id": $kek_id
                            }
                          },
                          "jwtAuth": {
                            "name": "jwt-role",
                            "jwtEnable": true,
                            "jwtAuthConfig": {
                              "claims": [
                                {
                                  "key": "aud",
                                  "values": [
                                    "bafapi.baffle.io"
                                  ]
                                },
                                {
                                  "key": "aud",
                                  "values": [
                                    "bafapi.baffle.io"
                                  ]
                                },
                                {
                                  "key": "iss",
                                  "values": [
                                    "bafapi.baffle.io"
                                  ]
                                }
                              ],
                              "auditLog": {
                                "logAllAccess": true,
                                "property": [
                                  "roles",
                                  "iat"
                                ]
                              }
                            },
                            "secretKey": "4S3aK8dN1R2bM6P5oH9LgE7cU4F3G2J1F8F9K3M2P1N6R4B5V2C1X9Z0W8E5Y6Q"
                          }
                        }')

  echo "$api_svc_cle_payload"
}

# Get rle api payload
get_api_svc_rle_payload(){
  api_svc_rle_payload=$(jq -n \
                        --arg name "$1" \
                        '{
                          "name": $name,
                          "global": false,
                          "multiTenancy": true,
                          "jwtAuth": {
                            "name": "jwt-role",
                            "jwtEnable": true,
                            "jwtAuthConfig": {
                              "claims": [
                                {
                                  "key": "aud",
                                  "values": [
                                    "bafapi.baffle.io"
                                  ]
                                },
                                {
                                  "key": "aud",
                                  "values": [
                                    "bafapi.baffle.io"
                                  ]
                                },
                                {
                                  "key": "iss",
                                  "values": [
                                    "bafapi.baffle.io"
                                  ]
                                }
                              ],
                              "auditLog": {
                                "logAllAccess": true,
                                "property": [
                                  "roles",
                                  "iat"
                                ]
                              }
                            },
                            "secretKey": "4S3aK8dN1R2bM6P5oH9LgE7cU4F3G2J1F8F9K3M2P1N6R4B5V2C1X9Z0W8E5Y6Q"
                          }
                        }')

  echo "$api_svc_rle_payload"
}

# Get system admin registration payload
get_registration_payload(){
  registration_payload=$(jq -n \
                      --arg username "$username" \
                      --arg password "$password" \
                      '{
                        "initPassword": "baffle123",
                        "orgName": "baffle",
                        "allowedDomains": ["baffle.io"],
                        "email": $username,
                        "firstName": "admin",
                        "lastName": "t",
                        "password": $password
                      }')

  echo "$registration_payload"
}

# Function to check if the BM REST API service is up and running
check_application(){
  # Counter for the number of retries
  counter=0
  while [ $counter -lt 10 ]; do
    # Send a request to the REST API endpoint and store the HTTP status code
    ssn_status_code=$(curl -k --write-out "%{http_code}\n" --silent --output /dev/null "$checkAppUrl")
    # If the HTTP status code is 200, print a success message and exit the loop
    if [ "$ssn_status_code" -eq 200 ]; then
      echo "BM REST API service is up and running."
      break
    fi
    # If the HTTP status code is not 200, print a retry message and wait for the specified time interval before the next retry
    echo "BM REST API service is not responding. Retrying in 30 seconds..." >&2
    sleep 30
    ((counter++))
  done
  # If the maximum number of retries has been reached, print an error message
  if [ $counter -eq 10 ]; then
    echo "BM REST API service is not responding after 5 minutes. Exiting script." >&2
    echo "error"
  else
    echo "BM REST API service is up and running."
    echo "success"
  fi
}

# Get Login payload
get_login_payload(){
  login_payload=$(jq -n \
                --arg password "$password" \
                --arg username "$username" \
                '{
                  "password": $password,
                  "username": $username
                }')

  echo "$login_payload"
}




start_api_service(){
  port=8444

  aws_metadata_token=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  private_ip=$(curl -H "X-aws-ec2-metadata-token: $aws_metadata_token" http://169.254.169.254/latest/meta-data/local-ipv4)
  echo "Private IP: $private_ip" >&2
  export "BM_URL=https://$private_ip"

  cd /home/ec2-user/baffle-api-service

  echo "Starting API  Service..." >&2
  # Run docker compose
  docker-compose up -d &

  # Check if port  is open
  counter=0
  while ! netstat -tuln | grep "$port" && [ $counter -lt 10 ]; do
    echo "Port $port is not open. Retrying in 30 seconds..." >&2
    sleep 30
    ((counter++))
  done

  if netstat -tuln | grep "$port"; then
    echo "Port $port is open. API Service is up and running." >&2
    echo "success"
  elif [ $counter -eq 10 ]; then
    echo "Port $port is not open after 5 minutes. Exiting script." >&2
    echo "error"
  fi
}

start_bm(){
  # change the current directory
  cd /opt/manager
  # Start the Baffle Manager service
  docker-compose up -d &
}

################## Configuration for standard api service ##################
configure_cle_api_service(){
  echo -e "\n#### Configuring CLE API Service... ####\n" >&2

  api_cle_payload=$(get_api_svc_cle_payload "cle-api-service" "$aws_kms_id" "$kek_id" )
  # Enroll api service
  read api_cle_id cle_syncId <<< $(send_post_request "$jwt_token" "$api_service_url" "$api_cle_payload" "id" "syncId")
  if [ "$api_cle_id" == "error" ]; then
    echo "API service enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "API Service cluster: $api_cle_id" >&2
    echo "Sync ID: $cle_syncId" >&2
    export "SERVICE_ID=$api_cle_id"
    export "SYNC_ID=$cle_syncId"
  fi

  # add permission
  add_all_permission=$(get_add_permission_payload)
  add_all_permission_id=$(send_post_request "$jwt_token" "$api_service_url/$api_cle_id/access-control" "$add_all_permission" "id")
   if [ "add_tenant_1_id" == "error" ]; then
     echo "Adding Permisssion  failed. Exiting script." >&2
     exit 1
   else
     echo "Permisssions added" >&2
   fi

  deploy_payload=$(get_deploy_payload "deploy-cle")
  deploy_id=$(send_post_request "$jwt_token" "$api_service_url/$api_cle_id/deployments" "$deploy_payload" "id")
  if [ "deploy_id" == "error" ]; then
   echo "Deployment failed. Exiting script." >&2
   exit 1
  else
   echo "Deployment ID: $deploy_id" >&2
  fi


  # Start API Service
  status=$(start_api_service)
  if [ "$status" == "error" ]; then
    echo "API Service startup failed. Exiting script."
    exit 1
  fi
}

################## Configuration for RLE api service ##################
configure_rle_api_service(){
  echo -e "\n#### Configuring RLE API Service.... ####\n" >&2

   # Enroll Tenant-1
    rle_tenant1_payload=$(get_tenant_payload "Rle-Tenant-1" "T-1001" "$aws_kms_id" "$kek_id" "T-rle-1001-dek")
    rle_tenant1_id=$(send_post_request "$jwt_token" "$tenant_url" "$rle_tenant1_payload" "id")
    if [ "$rle_tenant1_id" == "error" ]; then
      echo "RLE Tenant-1 enrollment failed. Exiting script." >&2
      exit 1
    else
      echo "RLE Tenant-1 ID: $rle_tenant1_id" >&2
    fi

    # Enroll Tenant-2
    rle_tenant2_payload=$(get_tenant_payload "Rle-Tenant-2" "T-2002" "$aws_kms_id" "$kek1_id" "T-rle-2002-dek")
    rle_tenant2_id=$(send_post_request "$jwt_token" "$tenant_url" "$rle_tenant2_payload" "id")
    if [ "$rle_tenant2_id" == "error" ]; then
      echo "Tenant-2 enrollment failed. Exiting script." >&2
      exit 1
    else
      echo "Tenant-2 ID: $rle_tenant2_id" >&2
    fi

  api_rle_payload=$(get_api_svc_rle_payload "rle-api-service" )
  # Enroll api service
  read api_rle_id rle_syncId <<< $(send_post_request "$jwt_token" "$api_service_url" "$api_rle_payload" "id" "syncId")
  if [ "$api_rle_id" == "error" ]; then
    echo "API service enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "API Service cluster: $api_rle_id" >&2
    echo "Sync ID: $rle_syncId" >&2
    export "SERVICE_ID=$api_rle_id"
    export "SYNC_ID=$rle_syncId"
  fi


   # add tenant to api
   add_tenant_1=$(get_tenant_enroll_payload "$rle_tenant1_id")
   add_tenant_1_id=$(send_post_request "$jwt_token" "$api_service_url/$api_rle_id/tenants" "$add_tenant_1" "id")
   if [ "add_tenant_1_id" == "error" ]; then
     echo "Tenant Add failed. Exiting script." >&2
     exit 1
   else
     echo "Tenant Add ID: $add_tenant_1_id" >&2
   fi

   add_tenant_2=$(get_tenant_enroll_payload "$rle_tenant2_id")
   add_tenant_2_id=$(send_post_request "$jwt_token" "$api_service_url/$api_rle_id/tenants" "$add_tenant_2" "id")
   if [ "add_tenant_2_id" == "error" ]; then
     echo "Tenant Add failed. Exiting script." >&2
     exit 1
   else
     echo "Tenant Add ID: $add_tenant_2_id" >&2
   fi


   deploy_payload=$(get_deploy_payload "deploy-rle")
   deploy_id=$(send_post_request "$jwt_token" "$api_service_url/$api_rle_id/deployments" "$deploy_payload" "id")
   if [ "deploy_id" == "error" ]; then
     echo "Deployment failed. Exiting script." >&2
     exit 1
   else
     echo "Deployment ID: $deploy_id" >&2
   fi


  # Start API Service
    status=$(start_api_service)
    if [ "$status" == "error" ]; then
      echo "API Service startup failed. Exiting script."
      exit 1
    fi

}

################## Main Workflow ##################
configure_bm(){
  ################## Configuration for Baffle Manager ##################
  echo -e "\n#### Configuring Baffle Manager... ####\n" >&2
  start_bm
  # Check if the BM REST API service is up and running
  status=$(check_application)
  if [ "$status" == "error" ]; then
    echo "BM REST API service is not responding. Exiting script." >&2
    exit 1
  fi

  # Get Registration payload
  registration_payload=$(get_registration_payload)
  # Register the system admin
  status=$(send_post_request "null" "$registration_url" "$registration_payload")
  if [ "$status" == "error" ]; then
    echo "System admin registration failed. Exiting script."  >&2
    exit 1
  else
    echo "System admin registration successful." >&2
  fi


  # Get Login payload
  login_payload=$(get_login_payload)
  # Login as the system admin
  jwt_token=$(send_post_request "null" "$login_url" "$login_payload" "accessToken")
  if [ "$jwt_token" == "error" ]; then
    echo "Login failed. Exiting script." >&2
    exit 1
  else
    echo "JWT Token: $jwt_token" >&2
    echo "Login successful." >&2
  fi

  # Get AWS KMS payload
  aws_kms_payload=$(get_aws_kms_payload)
  # Enroll AWS KMS
  aws_kms_id=$(send_post_request "$jwt_token" "$aws_kms_url" "$aws_kms_payload" "id")
  if [ "$aws_kms_id" == "error" ]; then
    echo "AWS KMS enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "AWS KMS ID: $aws_kms_id" >&2
  fi

  # Get KEK payload
  kek_payload=$(get_kek_payload "$kek_name" "$aws_kms_id" )
  # Enroll KEK
  kek_id=$(send_post_request "$jwt_token" "$kek_url" "$kek_payload" "id")
  if [ "$kek_id" == "error" ]; then
    echo "KEK enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "KEK ID: $kek_id" >&2
  fi

  # Get DEK payload
  dek_payload=$(get_dek_payload "$kek_id")
  # Enroll DEK
  dek_id=$(send_post_request "$jwt_token" "$kek_url/$kek_id/deks" "$dek_payload" "id")
  if [ "$dek_id" == "error" ]; then
    echo "DEK enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "DEK ID: $dek_id" >&2
  fi

  # write  if condition for workflows RLE
  if [ "$execute_workflow" == "BYOK" ]; then
    # Enroll KEK-1
      kek1_payload=$(get_kek_payload "$kek_name_1" "$aws_kms_id" )
      kek1_id=$(send_post_request "$jwt_token" "$kek_url" "$kek1_payload" "id")
      if [ "$kek1_id" == "error" ]; then
        echo "KEK-1 enrollment failed. Exiting script." >&2
        exit 1
      else
        echo "KEK-1 ID: $kek1_id" >&2
      fi
  fi

  # api service permission
  all_permission=$(get_permission_payload "encrypt-decrypt" "encrypt-decrypt" '["ENCRYPT","DECRYPT"]')
  all_permission_id=$(send_post_request "$jwt_token" "$permission_url" "$all_permission" "id")
  if [ "$all_permission_id" == "error" ]; then
    echo "All Permission failed. Exiting script." >&2
    exit 1
  else
    echo "All Permission: $all_permission_id" >&2
  fi

  encrypt_permission=$(get_permission_payload "encrypt-only" "encrypt" '["ENCRYPT"]')
  encrypt_permission_id=$(send_post_request "$jwt_token" "$permission_url" "$encrypt_permission" "id")
  if [ "$encrypt_permission_id" == "error" ]; then
    echo "Encrypt Permission failed. Exiting script." >&2
    exit 1
  else
    echo "Encrypt Permission: $encrypt_permission_id" >&2
  fi

  decrypt_permission=$(get_permission_payload "decrypt-only" "decrypt" '["DECRYPT"]')
  decrypt_permission_id=$(send_post_request "$jwt_token" "$permission_url" "$decrypt_permission" "id")
  if [ "$decrypt_permission_id" == "error" ]; then
    echo "Decrypt Permission failed. Exiting script." >&2
    exit 1
  else
    echo "Decrypt Permission: $decrypt_permission_id" >&2
  fi
}

# Execute workflow based on execute_workflow variable.
configure_bm

if [ "$execute_workflow" == "Standard" ]; then
  configure_cle_api_service
elif [ "$execute_workflow" == "BYOK" ]; then
  configure_rle_api_service
else
  echo "Invalid workflow. Exiting script." >&2
  exit 1
fi

