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

execute_workflow=$EXECUTE_WORKFLOW
# Base URL
base_url="https://localhost:443"

# Login Data Proxy URL
checkAppUrl="$base_url/api/public/v2/application_access_check"
registration_url="$base_url/api/public/v2/init"
login_url="$base_url/api/public/v2/auth"

aws_kms_url="$base_url/api/v2/keystores/awskms"
kek_url="$base_url/api/v2/key-management/keks"
tenant_url="$base_url/api/v2/key-management/tenants"
data_proxy_url="$base_url/api/v3/data-proxy/clusters"
enc_policy_url="$base_url/api/v3/enc-policies"

full_file_name="kia.txt"
csv_file_name="customers.csv"
json_file_name="john.json"

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
    echo "$response"
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

get_region(){
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

  echo "${region_map[$aws_region]:-"US_WEST_2"}"

}

# Get AWS KMS payload
get_aws_kms_payload(){
  aws_region=$(get_region)
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

# Get Encryption policy payload
get_enc_policy_payload(){
  name=$1
  format=$2
  keystore=$3
  kek=$4
  dek=$5
  policy_payload=$(jq -n \
                --arg name "$name" \
                --arg format "$format" \
                --arg keystore "$keystore" \
                --arg kek "$kek" \
                --arg dek "$dek" \
                '{
                  "name": $name,
                  "encryptionFormat": $format,
                  "dekConfig": {
                    "dekType":"DEK",
                    "dekDetails": {
                      "keyStore": { "id": $keystore },
                      "kek": { "id": $kek },
                      "dek": { "id": $dek },
                    }
                  }
                }')

  echo "$policy_payload"
}

# get tenant encryption policy
get_tenant_enc_policy_payload(){
  name=$1
  format=$2
  policy_payload=$(jq -n \
                --arg name "$name" \
                --arg format "$format" \
                '{
                  "name": $name,
                  "encryptionFormat": $format,
                  "dekConfig": {
                    "dekType":"TENANT_DEK"
                  }
                }')

  echo "$policy_payload"
}

# Get Tenant group endpoint payload
get_tenant_group_payload(){
  tenant_group_payload=$(jq -n \
                --arg name "$1" \
                --arg tenant_one_id "$2" \
                --arg tenant_two_id "$3" \
                --arg s3_endpoint "$4" \
                '{
                  "name": $name,
                  "serverConfiguration":"NEW_SERVER",
                  "tenants": [
                  { "id": $tenant_one_id },
                  { "id": $tenant_two_id }
                  ],
                  "endpoints":[
                    {"id" : $s3_endpoint }
                  ]
                }')

  echo "$tenant_group_payload"
}

# Get full file payload request
get_full_file_read_policy_payload(){
  full_file_policy_payload=$(jq -n \
                --arg name "$1" \
                --arg endpoint "$2" \
                --arg operation "$3" \
                --arg encryption  "$4" \
                --arg file  "$5" \
                '{
                  "name": $name,
                  "endpoints":[{"id": $endpoint}],
                  "httpResponseSettings": {
                    "operation": $operation,
                    "fullFileEncPolicy": {"id": $encryption }
                  },
                  "matchConditionList":[
                    {"headers":[],"queryParams":[],"files":[$file],"precedence":"10"}]
                }')

  echo "$full_file_policy_payload"
}

# Get full file linked payload request
get_full_file_write_linked_policy_payload(){
  full_file_policy_payload=$(jq -n \
                --arg name "$1" \
                --arg endpoint "$2" \
                --arg operation "$3" \
                --arg encryption  "$4" \
                --arg file  "$5" \
                --arg linkedDPP "$6" \
                '{
                  "name": $name,
                  "linkedDppId": $linkedDPP,
                  "endpoints":[{"id": $endpoint}],
                  "httpRequestSettings": {
                    "operation": $operation,
                    "fullFileEncPolicy": {"id": $encryption }
                  },
                  "matchConditionList":[
                    {"headers":[],"queryParams":[],"files":[$file],"precedence":"10"}]
                }')

  echo "$full_file_policy_payload"
}

# Get field level payload response
get_field_read_policy_payload(){
  field_policy_payload=$(jq -n \
                --arg name "$1" \
                --arg endpoint "$2" \
                --arg operation "$3" \
                --arg data_container  "$4" \
                --arg file  "$5" \
                '{
                  "name": $name,
                  "endpoints":[{"id": $endpoint}],
                  "httpResponseSettings": {
                    "operation": $operation,
                    "dataContainer": { "id": $data_container},
                  },
                  "matchConditionList":[
                    {"headers":[],"queryParams":[],"files":[$file],"precedence":"10"}]
                }')

  echo "$field_policy_payload"
}

# Get field level linked payload response
get_field_write_linked_policy_payload(){
  field_policy_payload=$(jq -n \
                --arg name "$1" \
                --arg endpoint "$2" \
                --arg operation "$3" \
                --arg data_container  "$4" \
                --arg file  "$5" \
                --arg linkedDPP "$6" \
                '{
                  "name": $name,
                  "linkedDppId": $linkedDPP,
                  "endpoints":[{"id": $endpoint}],
                  "httpRequestSettings": {
                    "operation": $operation,
                    "dataContainer": { "id": $data_container},
                  },
                  "matchConditionList":[
                    {"headers":[],"queryParams":[],"files":[$file],"precedence":"10"}]
                }')

  echo "$field_policy_payload"
}

# Get full file rbac
get_full_file_rbac(){
  full_file_policy_payload=$(jq -n \
                --arg name "$1" \
                --arg file  "$2" \
                --arg encrypt_decrypt "$3" \
                --arg decrypt "$4" \
                --arg encrypt  "$5" \
                '{
                    "name": $name,
                    "resourceType":"FILE",
                    "hasFieldLevelPolicy":false,
                    "resources":[$file],
                    "permissions":[
                      {
                        "accessGroup":{ "id": $encrypt_decrypt },
                        "fileLevelPermissionAction":{"permissions":["DECRYPT","ENCRYPT","READ","WRITE"],"action":"ALLOW"}
                      },
                      {
                        "accessGroup":{"id": $decrypt },
                        "fileLevelPermissionAction":{"permissions":["DECRYPT","READ"],"action":"ALLOW"}
                      },
                      {
                        "accessGroup":{"id": $encrypt },
                        "fileLevelPermissionAction":{"permissions":["ENCRYPT","WRITE"],"action":"ALLOW"}
                      }
                    ]
                }')

  echo "$full_file_policy_payload"
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


# Get cle dp payload
get_dp_cle_payload(){
  dp_cle_payload=$(jq -n \
                 --arg name "$1" \
                 --arg keystore "$2" \
                 --arg kek "$3" \
                 '{
                   "name": $name,
                   "server": {
                     "type":"S3",
                     "checkServerConnections":false
                   },
                   "client": {
                     "type":"S3"
                   },
                   "encryption": {
                     "type":"GLOBAL",
                     "globalEnc": {
                      "keystore": { "id": $keystore },
                      "kek": {"id": $kek }
                      }
                   },
                   "accessControl": {
                     "enabled":false
                   }
                 }')

  echo "$dp_cle_payload"
}

# Get rle DP payload
get_dp_rle_payload(){
  dp_rle_payload=$(jq -n \
                        --arg name "$1" \
                        '{
                          "name": $name,
                          "server": {
                            "type":"S3",
                            "checkServerConnections":false
                          },
                          "client": {
                            "type":"S3"
                          },
                          "encryption": {
                            "type":"MULTI_TENANCY",
                            "tenantDetermination":"URI",
                            "urlPattern":".*/(T-\\d+)-(.*).(.*)"
                          },
                          "accessControl":{
                            "enabled":false
                          }
                        }')

  echo "$dp_rle_payload"
}

# Get system admin registration payload
get_registration_payload(){
  registration_payload=$(jq -n \
                      --arg username "$username" \
                      --arg password "$password" \
                      '{
                        "initPassword": "baffle123",
                        "defaultAccount": "baffle",
                        "allowedDomains": ["baffle.io"],
                        "email": $username,
                        "firstName": "admin",
                        "lastName": "t",
                        "password": $password
                      }')

  echo "$registration_payload"
}

# Get entity group payload response
get_entity_group_payload(){
  entity_group_payload=$(jq -n \
                --arg name "$1" \
                --arg encryption_policy_id "$2" \
                '{
                  "name": ($name + "-group"),
                  "piiEntities":[
                  {
                      "entityType": $name,
                      "dataType":"STRING",
                      "encryptionPolicy":
                      {
                        "id": $encryption_policy_id
                      }
                  }
                  ]
                }')

  echo "$entity_group_payload"
}

# Get data container csv payload
get_data_container_csv_payload(){
  data_container_payload=$(jq -n \
                --arg name "$1" \
                --arg field "$2" \
                --arg entity_group_id "$3" \
                '{
                  "name": ($name + "-csv-container"),
                  "type":"CSV",
                  "piiEntitiesGroup":
                  { "id": $entity_group_id },
                  "csvPayload":
                  {
                    "header": true,
                    "standardDelimiter": "COMMA",
                    "encoding":"UTF_8",
                    "columnNames":[
                      {
                        "name": $field,
                        "fieldConfig":
                        {
                          "type":"SIMPLE",
                          "simpleFieldConfig":
                          {
                            "dataType":"STRING",
                            "dynamicDetection":false,
                            "entityType": $name
                          }
                        }
                      }
                    ]
                  }
                }')

  echo "$data_container_payload"
}

# Get data container payload response
get_data_container_json_payload(){
  data_container_payload=$(jq -n \
                --arg name "$1" \
                --arg field "$2" \
                --arg entity_group_id "$3" \
                '{
                  "name": ($name + "-json-container"),
                  "type":"JSON",
                  "piiEntitiesGroup":
                  { "id": $entity_group_id },
                  "jsonPayload":
                  {
                    "fieldLocations":[
                    {
                      "location": $field,
                      "fieldConfig":
                      {
                        "type":"SIMPLE",
                        "simpleFieldConfig":
                        {
                          "dataType":"STRING",
                          "dynamicDetection":false,
                          "entityType":$name
                        }
                      }
                    }]
                  }
                }')

  echo "$data_container_payload"
}



# Function to check if the BM Data Proxy service is up and running
check_application(){
  # Counter for the number of retries
  counter=0
  while [ $counter -lt 10 ]; do
    # Send a request to the Data Proxy endpoint and store the HTTP status code
    ssn_status_code=$(curl -k --write-out "%{http_code}\n" --silent --output /dev/null "$checkAppUrl")
    # If the HTTP status code is 200, print a success message and exit the loop
    if [ "$ssn_status_code" -eq 200 ]; then
      echo "BM Data Proxy is up and running."
      break
    fi
    # If the HTTP status code is not 200, print a retry message and wait for the specified time interval before the next retry
    echo "BM Data Proxy  is not responding. Retrying in 30 seconds..." >&2
    sleep 30
    ((counter++))
  done
  # If the maximum number of retries has been reached, print an error message
  if [ $counter -eq 10 ]; then
    echo "BM Data Proxy  is not responding after 5 minutes. Exiting script." >&2
    echo "error"
  else
    echo "BM Data Proxy  is up and running."
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


extract_s3_endpoint_id() {
  json_string=$1
  read_id=$(echo "$json_string" | jq -r '.data[0].id')
  echo "$read_id"
}



start_data_proxy_docker(){
  all=$1
  port=8444
  rle_port=8445

  aws_metadata_token=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  private_ip=$(curl -H "X-aws-ec2-metadata-token: $aws_metadata_token" http://169.254.169.254/latest/meta-data/local-ipv4)
  echo "Private IP: $private_ip" >&2
  export "BM_URL=https://$private_ip"

  cd "/home/ec2-user/baffle-data-proxy"

  echo "Starting Data Proxy.." >&2

 if [ $all = true ]; then
    # Run docker compose
    docker-compose -f docker-compose-all.yaml up -d &
  else
    docker-compose up -d &
  fi

  # Check if port  is open
  counter=0
  while ! netstat -tuln | grep "$port" && [ $counter -lt 10 ]; do
    echo "Port $port is not open. Retrying in 30 seconds..." >&2
    sleep 30
    ((counter++))
  done

  if netstat -tuln | grep "$port"; then
    echo "Port $port is open. Data Proxy  is up and running." >&2
    echo "success"
  elif [ $counter -eq 10 ]; then
    echo "Port $port is not open after 5 minutes. Exiting script." >&2
    echo "error"
  fi

 if [ $all = true ]; then
    counter=0
     while ! netstat -tuln | grep "$rle_port" && [ $counter -lt 10 ]; do
       echo "Port $rle_port  for RLE is not open. Retrying in 30 seconds..." >&2
       sleep 30
       ((counter++))
     done

     if netstat -tuln | grep "$rle_port"; then
       echo "Port $rle_port is open. Data Proxy  is up and running." >&2
       echo "success"
     elif [ $counter -eq 10 ]; then
       echo "Port $rle_port for RLE is not open after 5 minutes. Exiting script." >&2
       echo "error"
     fi

 fi
}

start_bm(){
  # change the current directory
  cd "/opt/manager"
  # Start the Baffle Manager service
  docker-compose up -d &
}


################## Configuration for standard api service ##################
configure_cle_data_proxy(){
  echo -e "\n#### Configuring CLE Data Proxy... ####\n" >&2

  #create Encryption policy
  fpe_alphanum_policy=$(get_enc_policy_payload "fpe-alphanum" "FPE_ALPHANUM" "$aws_kms_id"  "$kek_id" "$dek_id")
  fpe_alphanum_policy_id=$(send_post_request "$jwt_token" "$enc_policy_url" "$fpe_alphanum_policy" "id")
   if [ "$fpe_alphanum_policy_id" == "error" ]; then
     echo "Adding FPE_ALPHANUM  failed. Exiting script." >&2
     exit 1
   else
     echo "FPE_ALPHANUM added : $fpe_alphanum_policy_id" >&2
   fi

   fpe_ccn_policy=$(get_enc_policy_payload "fpe-cc" "FPE_CREDIT_CARD" "$aws_kms_id"  "$kek_id" "$dek_id")
   fpe_ccn_policy_id=$(send_post_request "$jwt_token" "$enc_policy_url" "$fpe_ccn_policy" "id")
    if [ "$fpe_ccn_policy_id" == "error" ]; then
      echo "Adding FPE_CC  failed. Exiting script." >&2
      exit 1
    else
      echo "FPE_CC added : $fpe_ccn_policy_id" >&2
    fi

  aes_random_policy=$(get_enc_policy_payload "aes-random" "AES_RANDOM" "$aws_kms_id"  "$kek_id" "$dek_id")
  aes_random_policy_id=$(send_post_request "$jwt_token" "$enc_policy_url" "$aes_random_policy" "id")
  if [ "$aes_random_policy_id" == "error" ]; then
    echo "Adding AES Random failed. Exiting script." >&2
    exit 1
  else
    echo "AES Random  added : $aes_random_policy_id" >&2
  fi

  dp_cle_payload=$(get_dp_cle_payload "cle-s3-proxy" "$aws_kms_id" "$kek_id" )
  # Enroll api service
  read dp_cle_id cle_syncId <<< "$(send_post_request "$jwt_token" "$data_proxy_url" "$dp_cle_payload" "id" "syncId")"
  if [ "$dp_cle_id" == "error" ]; then
    echo "DP enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "DP cluster: $dp_cle_id" >&2
    echo "Sync ID: $cle_syncId" >&2
    export "SERVICE_ID=$dp_cle_id"
    export "SYNC_ID=$cle_syncId"
  fi

  add_endpoint_dpp_deploy false $dp_cle_id
}

################## Configuration for RLE api service ##################
configure_rle_data_proxy(){
  all=$1
  echo -e "\n#### Configuring RLE Data Proxy.... ####\n" >&2

  #create Encryption policy
  fpe_alphanum_policy=$(get_tenant_enc_policy_payload "fpe-alphanum-rle" "FPE_ALPHANUM")
  fpe_alphanum_policy_id=$(send_post_request "$jwt_token" "$enc_policy_url" "$fpe_alphanum_policy" "id")
   if [ "$fpe_alphanum_policy_id" == "error" ]; then
     echo "Adding FPE_ALPHANUM  failed. Exiting script." >&2
     exit 1
   else
     echo "FPE_ALPHANUM added : $fpe_alphanum_policy_id" >&2
   fi

   fpe_ccn_policy=$(get_tenant_enc_policy_payload "fpe-cc-rle" "FPE_CREDIT_CARD")
   fpe_ccn_policy_id=$(send_post_request "$jwt_token" "$enc_policy_url" "$fpe_ccn_policy" "id")
    if [ "$fpe_ccn_policy_id" == "error" ]; then
      echo "Adding FPE_CC  failed. Exiting script." >&2
      exit 1
    else
      echo "FPE_CC added : $fpe_ccn_policy_id" >&2
    fi

    aes_random_policy=$(get_tenant_enc_policy_payload "aes_random-rle" "AES_RANDOM")
    aes_random_policy_id=$(send_post_request "$jwt_token" "$enc_policy_url" "$aes_random_policy" "id")
    if [ "$aes_random_policy_id" == "error" ]; then
      echo "Adding AES RANDOM  failed. Exiting script." >&2
      exit 1
    else
      echo "AES RANDOM added : $aes_random_policy_id" >&2
    fi

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
    echo "RLE Tenant-2 enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "RLE Tenant-2 ID: $rle_tenant2_id" >&2
  fi

  dp_rle_payload=$(get_dp_rle_payload "rle-s3-proxy" )
  # Enroll api service
  read dp_rle_id rle_syncId <<< "$(send_post_request "$jwt_token" "$data_proxy_url" "$dp_rle_payload" "id" "syncId")"
  if [ "$dp_rle_id" == "error" ]; then
    echo "DP enrollment failed. Exiting script." >&2
    exit 1
  else
    if [ "$all" = true ]; then
      echo "RLE DP cluster: $dp_rle_id" >&2
      echo "RLE Sync ID: $rle_syncId" >&2
      export "RLE_SERVICE_ID=$dp_rle_id"
      export "RLE_SYNC_ID=$rle_syncId"
    else
      echo "DP cluster: $dp_rle_id" >&2
      echo "Sync ID: $rle_syncId" >&2
      export "SERVICE_ID=$dp_rle_id"
      export "SYNC_ID=$rle_syncId"
    fi
  fi

  add_endpoint_dpp_deploy true $dp_rle_id
}

######## ADD ENDPOINT, DPP,  DEPLOY ###########
add_endpoint_dpp_deploy(){
    rle=$1
    dp_id=$2

    name_prefix="cle-"
    if [ $rle = true ]; then
      name_prefix="rle-"
    fi

    endpoint_list=$(send_get_request "$jwt_token" "$data_proxy_url/$dp_id/endpoints" "response")
    #get s3 endpoint id
    read s3_endpoint_id <<< "$(extract_s3_endpoint_id "$endpoint_list")"
    echo "S3 Endpoint: $s3_endpoint_id"
    if [ "$s3_endpoint_id" == "error" ]; then
        echo "S3 Endpoints fail." >&2
        exit 1
    fi

   if [ $rle = true ]; then
     # add tenant endpoint
     add_tenants_group=$(get_tenant_group_payload "Rle-Tenant-group" "$rle_tenant1_id" "$rle_tenant2_id" "$s3_endpoint_id")
     add_tenants_group_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/tenants" "$add_tenants_group" "id")
     if [ "$add_tenants_group_id" == "error" ]; then
       echo "Tenant Group Addition failed. Exiting script." >&2
       exit 1
     else
       echo "Tenant 1 Add  Endpoint ID: $add_tenants_group_id" >&2
     fi

     full_file_name="(T-\\d+)-kia.txt"
     csv_file_name="(T-\\d+)-customers.csv"
     json_file_name="(T-\\d+)-john.json"
   fi

  # Add Data Policies
  # read full file
  full_file_read_policy=$(get_full_file_read_policy_payload "$name_prefix+dp-full-file-read" "$s3_endpoint_id"  "DECRYPT" "$aes_random_policy_id" "$full_file_name")
  full_file_read_policy_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/data-policies" "$full_file_read_policy" "id")
  if [ "$full_file_read_policy_id" == "error" ]; then
    echo "DPP Read Full failed. Exiting script." >&2
  exit 1
  else
    echo "DPP Read Full ID: $full_file_read_policy_id" >&2
  fi

  # write full file
  full_file_write_policy=$(get_full_file_write_linked_policy_payload "$name_prefix+dp-full-file-write" "$s3_endpoint_id"  "ENCRYPT" "$aes_random_policy_id" "$full_file_name" "$full_file_read_policy_id")
  full_file_write_policy_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/data-policies" "$full_file_write_policy" "id")
  if [ "$full_file_write_policy_id" == "error" ]; then
    echo "DPP Write Full failed. Exiting script." >&2
    exit 1
  else
    echo "DPP Write Full ID: $full_file_write_policy_id" >&2
  fi

  # entity group
  cc_entity_group_payload=$(get_entity_group_payload "$name_prefix+credit-card" "$fpe_ccn_policy_id")
  cc_entity_group_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/pii-entities-group" "$cc_entity_group_payload" "id")
  if [ "$cc_entity_group_id" == "error" ]; then
    echo "Entity Group Creation failed. Exiting script." >&2
    exit 1
  else
    echo "Entity Group ID: $cc_entity_group_id" >&2
  fi

  csv_data_container_payload=$(get_data_container_csv_payload "$name_prefix+credit-card" "ccn" "$cc_entity_group_id")
  csv_data_container_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/data-containers" "$csv_data_container_payload" "id")
  if [ "$csv_data_container_id" == "error" ]; then
    echo "CSV Data Container Creation failed. Exiting script." >&2
    exit 1
  else
    echo "CSV Data Container ID: $csv_data_container_id" >&2
  fi

   # field level read
   field_read_policy=$(get_field_read_policy_payload "$name_prefix+dp-csv-field-read" "$s3_endpoint_id"  "DECRYPT" "$csv_data_container_id" "$csv_file_name")
   field_read_policy_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/data-policies" "$field_read_policy" "id")
   if [ "$full_file_read_policy_id" == "error" ]; then
     echo "DPP CSV Read Field failed. Exiting script." >&2
     exit 1
   else
     echo "DPP CSV  Read Field ID: $field_read_policy_id" >&2
   fi

  #field level write
  field_write_policy=$(get_field_write_linked_policy_payload "$name_prefix+dp-csv-field-write" "$s3_endpoint_id"  "ENCRYPT" "$csv_data_container_id" "$csv_file_name" "$field_read_policy_id")
  field_write_policy_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/data-policies" "$field_write_policy" "id")
  if [ "$field_write_policy_id" == "error" ]; then
    echo "DPP CSV Write Filed failed. Exiting script." >&2
    exit 1
  else
    echo "DPP CSV Write Field ID: $field_write_policy_id" >&2
  fi

  json_data_container_payload=$(get_data_container_json_payload "$name_prefix+credit-card" "ccn" "$cc_entity_group_id")
  json_data_container_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/data-containers" "$json_data_container_payload" "id")
  if [ "$json_data_container_id" == "error" ]; then
    echo "JSON Data Container Creation failed. Exiting script." >&2
    exit 1
  else
    echo "JSON Data Container ID: $json_data_container_id" >&2
  fi

   # field level read
   json_field_read_policy=$(get_field_read_policy_payload "$name_prefix+dp-json-field-read" "$s3_endpoint_id"  "DECRYPT" "$json_data_container_id" "$json_file_name")
   json_field_read_policy_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/data-policies" "$json_field_read_policy" "id")
   if [ "$json_field_read_policy_id" == "error" ]; then
     echo "DPP JSON Read Field failed. Exiting script." >&2
     exit 1
     exit 1
   else
     echo "DPP JSON  Read Field ID: $json_field_read_policy_id" >&2
   fi

  #field level write
  json_field_write_policy=$(get_field_write_linked_policy_payload "$name_prefix+dp-json-field-write" "$s3_endpoint_id"  "ENCRYPT" "$json_data_container_id" "$json_file_name" "$json_field_read_policy_id")
  json_field_write_policy_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/data-policies" "$json_field_write_policy" "id")
  if [ "$json_field_write_policy_id" == "error" ]; then
    echo "DPP JSON Write Filed failed. Exiting script." >&2
    exit 1
  else
    echo "DPP JSON Write Field ID: $json_field_write_policy_id" >&2
  fi

  deploy_payload=$(get_deploy_payload "$name_prefix+deploy" )
  deploy_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/deployments" "$deploy_payload" "id")
  if [ "$deploy_id" == "error" ]; then
   echo "Deployment failed. Exiting script." >&2
   exit 1
  else
   echo "Deployment ID: $deploy_id" >&2
  fi
}

################## Main Workflow ##################
configure_bm(){
  ################## Configuration for Baffle Manager ##################
  echo -e "\n#### Configuring Baffle Manager... ####\n" >&2
  start_bm
  # Check if the BM Data Proxy is up and running
  status=$(check_application)
  if [ "$status" == "error" ]; then
    echo "BM Data Proxy  is not responding. Exiting script." >&2
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
  if [ "$execute_workflow" == "BYOK" ] || [ "$execute_workflow" == "ALL" ]; then
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
}

start_data_proxy(){
  all=$1
  # Start Data Proxy
  status=$(start_data_proxy_docker $all)
  if [ "$status" == "error" ]; then
    echo "Data Proxy startup failed. Exiting script."
    exit 1
  fi
}

# Execute workflow based on execute_workflow variable.
configure_bm

if [ "$execute_workflow" == "Standard" ]; then
  configure_cle_data_proxy
  (start_data_proxy false)
elif [ "$execute_workflow" == "BYOK" ]; then
  configure_rle_data_proxy false
  (start_data_proxy false)
elif [ "$execute_workflow" == "ALL" ]; then
  configure_cle_data_proxy
  configure_rle_data_proxy true
  (start_data_proxy true)
else
  echo "Invalid workflow. Exiting script." >&2
  exit 1
fi



