#!/bin/bash

# Input parameters
username=$USERNAME
password=$PASSWORD
#Keystore info
aws_region=$KM_AWS_REGION
s3_bucket_name=$KM_S3_BUCKET_NAME
data_bucket_name=$DATA_S3_BUCKET_NAME

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
access_group_url="$base_url/api/v3/data-proxy/access-groups"
data_source_url="$base_url/api/v3/data-proxy/data-sources"

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

# get data source
get_data_source_payload(){
  name=$1
  data_source_payload=$(jq -n \
                --arg name "$name" \
                '{
                  "name": $name,
                  "type":"CSV",
                  "csvPayload": {
                    "header": true,
                    "standardDelimiter": "COMMA",
                    "encoding":"UTF_8",
                    "columnNames":[
                      {"name":"name","dataType":"STRING"},
                      {"name":"ssn","dataType":"STRING"}
                    ]
                  }
                }')

  echo "$data_source_payload"
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

# Get dp access group payload
get_access_group_payload(){
  name=$1
  roles=$2
  access_group_payload=$(jq -n \
                --arg name "$name" \
                --arg roles "$roles" \
                '{
                  "name": $name,
                  "accessControlMethod":"ROLE",
                  "roles": [$roles]
                }')

  echo "$access_group_payload"
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


# Get Tenant endpoint payload
get_tenant_endpoint_payload(){
  tenant_endpoint_payload=$(jq -n \
                --arg name "$1" \
                --arg tenant_id "$2" \
                --arg read_endpoint "$3" \
                --arg write_endpoint  "$4" \
                '{
                  "name": $name,
                  "serverConfiguration":"DEFAULT_SERVER",
                  "tenant": {
                     "id": $tenant_id
                  },
                  "endpoints":[
                    {"id" : $read_endpoint},
                    {"id" : $write_endpoint}
                  ]
                }')

  echo "$tenant_endpoint_payload"
}


# Get full file payload response
get_full_file_policy_response(){
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

# Get full file payload request
get_full_file_policy_request(){
  full_file_policy_payload=$(jq -n \
                --arg name "$1" \
                --arg endpoint "$2" \
                --arg operation "$3" \
                --arg encryption  "$4" \
                --arg file  "$5" \
                '{
                  "name": $name,
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
get_field_policy_response(){
  field_policy_payload=$(jq -n \
                --arg name "$1" \
                --arg endpoint "$2" \
                --arg operation "$3" \
                --arg data_source  "$4" \
                --arg alphanum  "$5" \
                --arg decimal  "$6" \
                --arg file  "$7" \
                '{
                  "name": $name,
                  "endpoints":[{"id": $endpoint}],
                  "httpResponseSettings": {
                    "operation": $operation,
                    "dataSource": { "id": $data_source},
                    "fieldLevelPolicies":[
                      {
                        "encryptionPolicy":  {"id": $decimal},
                        "field":"ssn",
                        "fieldIdentifierType":"COLUMN_NAME"
                      },
                      {
                        "encryptionPolicy": {"id": $alphanum},
                        "field":"name",
                        "fieldIdentifierType":"COLUMN_NAME"
                      }
                    ]
                  },
                  "matchConditionList":[
                    {"headers":[],"queryParams":[],"files":[$file],"precedence":"10"}]
                }')

  echo "$field_policy_payload"
}

# Get field level payload response
get_field_policy_request(){
  field_policy_payload=$(jq -n \
                --arg name "$1" \
                --arg endpoint "$2" \
                --arg operation "$3" \
                --arg data_source  "$4" \
                --arg alphanum  "$5" \
                --arg decimal  "$6" \
                --arg file  "$7" \
                '{
                  "name": $name,
                  "endpoints":[{"id": $endpoint}],
                  "httpRequestSettings": {
                    "operation": $operation,
                    "dataSource": { "id": $data_source},
                    "fieldLevelPolicies":[
                      {
                        "encryptionPolicy":  {"id": $decimal},
                        "field":"ssn",
                        "fieldIdentifierType":"COLUMN_NAME"
                      },
                      {
                        "encryptionPolicy": {"id": $alphanum},
                        "field":"name",
                        "fieldIdentifierType":"COLUMN_NAME"
                      }
                    ]
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


# Get full file rbac
get_field_rbac(){
  full_file_policy_payload=$(jq -n \
                --arg name "$1" \
                --arg data_source "$2" \
                --arg file  "$3" \
                --arg encrypt_decrypt "$4" \
                --arg decrypt "$5" \
                --arg encrypt  "$6" \
                '{
                    "name": $name,
                    "resourceType":"FILE",
                    "hasFieldLevelPolicy":true,
                    "dataSource": {"id": $data_source },
                    "resources":[$file],
                    "permissions":[
                    {
                      "accessGroup": {"id": $encrypt_decrypt },
                      "fileLevelPermissionAction":{"permissions":["DECRYPT","ENCRYPT","READ","WRITE"],"action":"ALLOW"},
                      "fieldLevelAccessPolicies":[
                        {"field":"name","fieldIdentifierType":"COLUMN_NAME","permissionAction":{"permissions":["DECRYPT","ENCRYPT","READ","WRITE"],"action":"ALLOW"}},
                        {"field":"ssn","fieldIdentifierType":"COLUMN_NAME","permissionAction":{"permissions":["DECRYPT","ENCRYPT","READ","WRITE"],"action":"ALLOW"}}
                      ],
                      "fieldLevelAccessControlType":"FIELD"
                    },
                    {
                      "accessGroup":{"id": $decrypt },
                      "fileLevelPermissionAction":{"permissions":["DECRYPT","READ"],"action":"ALLOW"},
                      "fieldLevelAccessPolicies":[
                        {"field":"name","fieldIdentifierType":"COLUMN_NAME","permissionAction":{"permissions":["DECRYPT","READ"],"action":"ALLOW"}},
                        {"field":"ssn","fieldIdentifierType":"COLUMN_NAME","permissionAction":{"permissions":["DECRYPT","READ"],"action":"ALLOW"}}
                      ],
                      "fieldLevelAccessControlType":"FIELD"
                      },
                      {
                        "accessGroup":{"id": $encrypt },
                        "fileLevelPermissionAction":{"permissions":["ENCRYPT","WRITE"],"action":"ALLOW"},
                        "fieldLevelAccessPolicies":[
                          {"field":"name","fieldIdentifierType":"COLUMN_NAME","permissionAction":{"permissions":["ENCRYPT","WRITE"],"action":"ALLOW"}},
                          {"field":"ssn","fieldIdentifierType":"COLUMN_NAME","permissionAction":{"permissions":["ENCRYPT","WRITE"],"action":"ALLOW"}}
                        ],
                        "fieldLevelAccessControlType":"FIELD"
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
  region=$(get_region)
  dp_cle_payload=$(jq -n \
                 --arg name "$1" \
                 --arg region "$region" \
                 --arg bucket "$data_bucket_name" \
                 --arg keystore "$2" \
                 --arg kek "$3" \
                 '{
                   "name": $name,
                   "server": {
                     "type":"S3",
                     "checkServerConnections":false,
                     "s3Config": {
                       "region": $region,
                       "bucket": $bucket
                     }
                   },
                   "client": {
                     "type":"HTTP",
                     "httpClientJwtAuth":{
                       "jwtEnable":true,
                       "name":"jwt-role",
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
                   },
                   "encryption": {
                     "type":"GLOBAL",
                     "globalEnc": {
                      "keystore": { "id": $keystore },
                      "kek": {"id": $kek }
                      }
                   },
                   "accessControl": {
                     "accessControlMethod":"ROLE"
                   }
                 }')

  echo "$dp_cle_payload"
}

# Get rle DP payload
get_dp_rle_payload(){
  region=$(get_region)
  dp_rle_payload=$(jq -n \
                        --arg name "$1" \
                        --arg region "$region" \
                        --arg bucket "$data_bucket_name" \
                        --arg stack_name "$stack_name" \
                        '{
                          "name": $name,
                          "server": {
                            "type":"S3",
                            "checkServerConnections":false,
                            "s3Config": {
                              "region": $region,
                              "bucket": $bucket
                            }
                          },
                          "client": {
                            "type":"HTTP",
                            "httpClientJwtAuth":{
                              "jwtEnable":true,
                              "name":"jwt-role",
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
                          },
                          "encryption": {
                            "type":"MULTI_TENANCY",
                            "tenantDetermination":"HEADER"
                          },
                          "accessControl":{
                            "accessControlMethod":"ROLE"
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
                        "orgName": "baffle",
                        "allowedDomains": ["baffle.io"],
                        "email": $username,
                        "firstName": "admin",
                        "lastName": "t",
                        "password": $password
                      }')

  echo "$registration_payload"
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


extract_endpoint_ids() {
  json_string=$1
  read_id=$(echo "$json_string" | jq -r '.data[0].id')
  write_id=$(echo "$json_string" | jq -r '.data[1].id')
  echo "$read_id $write_id"
}



start_data_proxy(){
  port=8444

  aws_metadata_token=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  private_ip=$(curl -H "X-aws-ec2-metadata-token: $aws_metadata_token" http://169.254.169.254/latest/meta-data/local-ipv4)
  echo "Private IP: $private_ip" >&2
  export "BM_URL=https://$private_ip"

  cd "/home/ec2-user/baffle-data-proxy"

  echo "Starting Data Proxy.." >&2
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
    echo "Port $port is open. Data Proxy  is up and running." >&2
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
configure_cle_data_proxy(){
  echo -e "\n#### Configuring CLE Data Proxy... ####\n" >&2

  #create Encryption policy
  fpe_alphanum_policy=$(get_enc_policy_payload "fpe-alphanum" "FPE_ALPHANUM" "$aws_kms_id"  "$kek_id" "$dek_id")
  fpe_alphanum_policy_id=$(send_post_request "$jwt_token" "$enc_policy_url" "$fpe_alphanum_policy" "id")
   if [ "fpe_alphanum_policy_id" == "error" ]; then
     echo "Adding FPE_ALPHANUM  failed. Exiting script." >&2
     exit 1
   else
     echo "FPE_ALPHANUM added : $fpe_alphanum_policy_id" >&2
   fi

   fpe_decimal_policy=$(get_enc_policy_payload "fpe-decimal" "FPE_DECIMAL" "$aws_kms_id"  "$kek_id" "$dek_id")
   fpe_decimal_policy_id=$(send_post_request "$jwt_token" "$enc_policy_url" "$fpe_decimal_policy" "id")
    if [ "fpe_decimal_policy_id" == "error" ]; then
      echo "Adding FPE_DECIMAL  failed. Exiting script." >&2
      exit 1
    else
      echo "FPE_DECIMAL added : $fpe_decimal_policy_id" >&2
    fi

  aes_random_policy=$(get_enc_policy_payload "aes-random" "AES_RANDOM" "$aws_kms_id"  "$kek_id" "$dek_id")
  aes_random_policy_id=$(send_post_request "$jwt_token" "$enc_policy_url" "$aes_random_policy" "id")
  if [ "aes_random_policy_id" == "error" ]; then
    echo "Adding AES Random failed. Exiting script." >&2
    exit 1
  else
    echo "AES Random  added : $aes_random_policy_id" >&2
  fi


  dp_cle_payload=$(get_dp_cle_payload "cle-dp-proxy" "$aws_kms_id" "$kek_id" )
  # Enroll api service
  read dp_cle_id cle_syncId <<< $(send_post_request "$jwt_token" "$data_proxy_url" "$dp_cle_payload" "id" "syncId")
  if [ "$dp_cle_id" == "error" ]; then
    echo "DP enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "DP cluster: $dp_cle_id" >&2
    echo "Sync ID: $cle_syncId" >&2
    export "SERVICE_ID=$dp_cle_id"
    export "SYNC_ID=$cle_syncId"
  fi

  add_endpoint_dpp_rbac_deploy false $dp_cle_id
}

################## Configuration for RLE api service ##################
configure_rle_data_proxy(){
  echo -e "\n#### Configuring RLE Data Proxy.... ####\n" >&2

  #create Encryption policy
  fpe_alphanum_policy=$(get_tenant_enc_policy_payload "fpe-alphanum" "FPE_ALPHANUM")
  fpe_alphanum_policy_id=$(send_post_request "$jwt_token" "$enc_policy_url" "$fpe_alphanum_policy" "id")
   if [ "fpe_alphanum_policy_id" == "error" ]; then
     echo "Adding FPE_ALPHANUM  failed. Exiting script." >&2
     exit 1
   else
     echo "FPE_ALPHANUM added : $fpe_alphanum_policy_id" >&2
   fi

   fpe_decimal_policy=$(get_tenant_enc_policy_payload "fpe-decimal" "FPE_DECIMAL")
   fpe_decimal_policy_id=$(send_post_request "$jwt_token" "$enc_policy_url" "$fpe_decimal_policy" "id")
    if [ "fpe_decimal_policy_id" == "error" ]; then
      echo "Adding FPE_DECIMAL  failed. Exiting script." >&2
      exit 1
    else
      echo "FPE_DECIMAL added : $fpe_decimal_policy_id" >&2
    fi

    aes_random_policy=$(get_tenant_enc_policy_payload "aes_random" "AES_RANDOM")
    aes_random_policy_id=$(send_post_request "$jwt_token" "$enc_policy_url" "$aes_random_policy" "id")
    if [ "aes_random_policy_id" == "error" ]; then
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
      echo "Tenant-2 enrollment failed. Exiting script." >&2
      exit 1
    else
      echo "Tenant-2 ID: $rle_tenant2_id" >&2
    fi

    dp_rle_payload=$(get_dp_rle_payload "rle-dp-proxy" )
    # Enroll api service
    read dp_rle_id rle_syncId <<< $(send_post_request "$jwt_token" "$data_proxy_url" "$dp_rle_payload" "id" "syncId")
    if [ "$dp_rle_id" == "error" ]; then
      echo "DP enrollment failed. Exiting script." >&2
      exit 1
    else
      echo "DP cluster: $dp_rle_id" >&2
      echo "Sync ID: $rle_syncId" >&2
      export "SERVICE_ID=$dp_rle_id"
      export "SYNC_ID=$rle_syncId"
    fi

    add_endpoint_dpp_rbac_deploy true $dp_rle_id
}

######## ADD ENDPOINT, DPP, RBAC and DEPLOY ###########
add_endpoint_dpp_rbac_deploy(){
    rle=$1
    dp_id=$2

    endpoint_list=$(send_get_request "$jwt_token" "$data_proxy_url/$dp_id/endpoints" "response")
    #get read and write endpoint id
    read read_endpoint_id write_endpoint_id <<< $(extract_endpoint_ids "$endpoint_list")
    echo "Read Endpoint: $read_endpoint_id"
    echo "Write Endpoint: $write_endpoint_id"
    if [ "$read_endpoint_id" == "error" ]; then
        echo "Reading Endpoints fail." >&2
        exit 1
    fi

   if [ $rle = true ]; then
     # add tenant endpoint
     add_tenant_1=$(get_tenant_endpoint_payload "Rle-Tenant-1-endpoint" "$rle_tenant1_id" "$read_endpoint_id"  "$write_endpoint_id")
     add_tenant_1_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/tenants" "$add_tenant_1" "id")
     if [ "add_tenant_1_id" == "error" ]; then
       echo "Tenant 1 Add  Endpoint failed. Exiting script." >&2
       exit 1
     else
       echo "Tenant 1 Add  Endpoint ID: $add_tenant_1_id" >&2
     fi

     add_tenant_2=$(get_tenant_endpoint_payload "Rle-Tenant-2-endpoint" "$rle_tenant2_id" "$read_endpoint_id"  "$write_endpoint_id")
     add_tenant_2_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/tenants" "$add_tenant_2" "id")
     if [ "add_tenant_2_id" == "error" ]; then
       echo "Tenant Add failed. Exiting script." >&2
       exit 1
     else
       echo "Tenant Add ID: $add_tenant_2_id" >&2
     fi
   fi

  # Add Data Policies
  # read full file
  full_file_read_policy=$(get_full_file_policy_response "dp-full-file-read" "$read_endpoint_id"  "DECRYPT" "$aes_random_policy_id" "bill.txt")
  full_file_read_policy_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/data-policies" "$full_file_read_policy" "id")
  if [ "full_file_read_policy_id" == "error" ]; then
    echo "DPP Read Full failed. Exiting script." >&2
  exit 1
  else
    echo "DPP Read Full ID: $full_file_read_policy_id" >&2
  fi

  # write full file
  full_file_write_policy=$(get_full_file_policy_request "dp-full-file-write" "$write_endpoint_id"  "ENCRYPT" "$aes_random_policy_id" "bill.txt")
  full_file_write_policy_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/data-policies" "$full_file_write_policy" "id")
  if [ "$full_file_write_policy_id" == "error" ]; then
    echo "DPP Write Full failed. Exiting script." >&2
    exit 1
  else
    echo "DPP Write Full ID: $full_file_write_policy_id" >&2
  fi

   # field level read
   field_read_policy=$(get_field_policy_response "dp-field-read" "$read_endpoint_id"  "DECRYPT" "$data_source_id" "$fpe_alphanum_policy_id"  "$fpe_decimal_policy_id" "employee.csv")
   field_read_policy_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/data-policies" "$field_read_policy" "id")
   if [ "full_file_read_policy_id" == "error" ]; then
     echo "DPP Read Field failed. Exiting script." >&2
     exit 1
   else
     echo "DPP Read Field ID: $field_read_policy_id" >&2
   fi

  #field level write
  field_write_policy=$(get_field_policy_request "dp-field-write" "$write_endpoint_id"  "ENCRYPT" "$data_source_id" "$fpe_alphanum_policy_id"  "$fpe_decimal_policy_id" "employee.csv")
  field_write_policy_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/data-policies" "$field_write_policy" "id")
  if [ "$field_write_policy_id" == "error" ]; then
    echo "DPP Write Filed failed. Exiting script." >&2
    exit 1
  else
    echo "DPP Write Field ID: $field_write_policy_id" >&2
  fi

  # add rbac file level
  full_rbac=$(get_full_file_rbac "full-file-rbac"  "bill.txt" "$encrypt_decrypt_ag_id" "$decrypt_ag_id" "$encrypt_ag_id")
  full_rbac_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/access-control-policies" "$full_rbac" "id")
  if [ "full_rbac_id" == "error" ]; then
   echo "Full File Rbac failed. Exiting script." >&2
   exit 1
  else
   echo "Full File Rbac ID: $full_rbac_id" >&2
  fi


  # add rbac field level
  field_rbac=$(get_field_rbac "field-rbac" "$data_source_id"  "employee.csv" "$encrypt_decrypt_ag_id" "$decrypt_ag_id" "$encrypt_ag_id")
  field_rbac_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/access-control-policies" "$field_rbac" "id")
  if [ "field_rbac_id" == "error" ]; then
   echo "Field  Rbac failed. Exiting script." >&2
   exit 1
  else
   echo "Full  Rbac ID: $field_rbac_id" >&2
  fi

  deploy_payload=$(get_deploy_payload "deploy-cle")
  deploy_id=$(send_post_request "$jwt_token" "$data_proxy_url/$dp_id/deployments" "$deploy_payload" "id")
  if [ "deploy_id" == "error" ]; then
   echo "Deployment failed. Exiting script." >&2
   exit 1
  else
   echo "Deployment ID: $deploy_id" >&2
  fi

  # Start Data Proxy
  status=$(start_data_proxy)
  if [ "$status" == "error" ]; then
    echo "Data Proxy startup failed. Exiting script."
    exit 1
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

  # dp access group
  encrypt_decrypt_ag_payload=$(get_access_group_payload "encrypt-decrypt-both" "encrypt-decrypt")
  encrypt_decrypt_ag_id=$(send_post_request "$jwt_token" "$access_group_url" "$encrypt_decrypt_ag_payload" "id")
  if [ "$encrypt_decrypt_ag_id" == "error" ]; then
    echo "Encrypt Decrypt AG failed. Exiting script." >&2
    exit 1
  else
    echo "Encrypt Decrypt AG: $encrypt_decrypt_ag_id" >&2
  fi

  encrypt_ag_payload=$(get_access_group_payload "encrypt-only" "encrypt")
  encrypt_ag_id=$(send_post_request "$jwt_token" "$access_group_url" "$encrypt_ag_payload" "id")
  if [ "$encrypt_ag_id" == "error" ]; then
    echo "Encrypt AG failed. Exiting script." >&2
    exit 1
  else
    echo "Encrypt AG: $encrypt_ag_id" >&2
  fi

  decrypt_ag_payload=$(get_access_group_payload "decrypt-only" "decrypt")
  decrypt_ag_id=$(send_post_request "$jwt_token" "$access_group_url" "$decrypt_ag_payload" "id")
  if [ "$decrypt_ag_id" == "error" ]; then
    echo "Decrypt AG failed. Exiting script." >&2
    exit 1
  else
    echo "Decrypt AG: $decrypt_ag_id" >&2
  fi

  # dp data source
  data_source_payload=$(get_data_source_payload "data_source")
  data_source_id=$(send_post_request "$jwt_token" "$data_source_url" "$data_source_payload" "id")
  if [ "$data_source_id" == "error" ]; then
    echo "Data Source failed. Exiting script." >&2
    exit 1
  else
    echo "Data Source: $data_source_id" >&2
  fi

}

# Execute workflow based on execute_workflow variable.
configure_bm

if [ "$execute_workflow" == "Standard" ]; then
  configure_cle_data_proxy
elif [ "$execute_workflow" == "BYOK" ]; then
  configure_rle_data_proxy
else
  echo "Invalid workflow. Exiting script." >&2
  exit 1
fi

