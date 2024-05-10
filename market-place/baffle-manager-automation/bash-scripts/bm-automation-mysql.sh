#!/bin/bash

# Input parameters
# Database info
#Keystore info
aws_region=us-west-2
# Kek info

# Base URL

# Login API URL
checkAppUrl="$base_url/api/public/v2/application_access_check"
registration_url="$base_url/api/public/v2/init"
login_url="$base_url/api/public/v2/auth"

db_proxy_url="$base_url/api/v2/svc/database-proxies"
database_url="$base_url/api/v2/databases"
keystore_url="$base_url/api/v2/keystores"
aws_kms_url="$base_url/api/v2/keystores/awskms"
kek_url="$base_url/api/v2/key-management/keks"
data_source_url="$base_url/api/v2/data-sources"
dpp_url="$base_url/api/v2/dpp"
fpe_decimal_url="$base_url/api/v2/encryption-policies/FPE_DECIMAL"
fpe_cc_url="$base_url/api/v2/encryption-policies/FPE_CREDIT_CARD"
user_group_url="$base_url/api/v2/data-access-control/user-groups"
tenant_url="$base_url/api/v2/key-management/tenants"



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
    # Check if hasMore key is present in the response
   hasMoreExists=$(echo "$response" | jq 'has("hasMore")')
  if [ "$hasMoreExists" != "null" ]; then
    # Parse the ids from the response and join them with a comma
    local ids=$(echo "$response" | jq -r '.data[].id')
    echo "$ids"
  else
    # Parse the id from the response
    local id=$(echo "$response" | jq -r '.id')
    echo "$id"
  fi
  else
    echo "Request failed with status code: $status_code" >&2
    echo "error"
  fi
}


send_delete_request() {
  local jwt_token=$1
  local url=$2

    # Send the DELETE request
    local response=$(curl -k -s -w "\n%{http_code}" -X DELETE -H "Content-Type: application/json" -H "Authorization: Bearer $jwt_token" "$url")

    # Extract the status code from the last line
    local status_code=$(echo "$response" | tail -n1)

    # Check if the status code is 204
    if [ "$status_code" -eq 204 ]; then
      echo "success"
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
# Get Database payload
get_database_payload(){
database_payload=$(jq -n \
                  --arg hn "$db_host_name" \
                  --argjson p "$db_port" \
                  --arg un "$db_user_name" \
                  --arg pw "$db_password" \
                  '{
                    "name": "mysqldb",
                    "dbType": "MYSQL",
                    "hostname": $hn,
                    "port": $p,
                    "dbUsername": $un,
                    "dbPassword": {
                      "secretStoreType": "CLEAR",
                      "secretValue": $pw
                    }
                  }')
  echo "$database_payload"
}

# Get AWS KMS payload
get_aws_kms_payload(){
  # convert from AWS region to java enum
  declare -A region_map=(
  ["us-east-1"]="US_EAST_1"
  ["us-east-2"]="US_EAST_2"
  ["us-west-1"]="US_WEST_1"
  ["us-west-2"]="US_WEST_2"
  ["ap-south-1"]="AP_SOUTH_1"
  ["ap-northeast-1"]="AP_NORTHEAST_1"
  ["ap-northeast-2"]="AP_NORTHEAST_2"
  ["ap-southeast-1"]="AP_SOUTHEAST_1"
  ["ap-southeast-2"]="AP_SOUTHEAST_2"
  ["ca-central-1"]="CA_CENTRAL_1"
  ["eu-central-1"]="EU_CENTRAL_1"
  ["eu-west-1"]="EU_WEST_1"
  ["eu-west-2"]="EU_WEST_2"
  ["eu-west-3"]="EU_WEST_3"
  ["eu-north-1"]="EU_NORTH_1"
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
  random_number=$((RANDOM % 10000 + 1)) # Generate a random number between 1 and 100
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
get_database_json_object(){
  input=$1
  # Initialize an empty JSON array
  json='[]'
  IFS=$'\n' read -d '' -ra items <<< "$input"
    for item in "${items[@]}"; do
      # Split each item by comma
      IFS=',' read -ra parts <<< "$item"
      database="${parts[0]}"
      table="${parts[1]}"
      column="${parts[2]}"
      datatype="${parts[3]}"
    
      # Create a JSON object for the column
      column_json=$(jq -n \
        --arg name "$column" \
        --arg datatype "$datatype" \
        '{
          "name": $name,
          "datatype": $datatype,
          "objectType": "TABLE",
          "verified": false
        }')
    
      # Check if the database exists in the JSON array
      database_index=$(echo "$json" | jq -r --arg name "$database" 'map(.name == $name) | index(true)')
    
      if [ "$database_index" == "null" ]; then
        # If the database doesn't exist, create a new one with the table and column
        json=$(echo "$json" | jq --arg name "$database" --arg table "$table" --argjson column "$column_json" '. += [{"name": $name, "tables": [{"name": $table, "columns": [$column]}]}]')
      else
        # If the database exists, check if the table exists
        table_index=$(echo "$json" | jq -r --arg name "$table" '.['"$database_index"'].tables | map(.name == $name) | index(true)')
    
        if [ "$table_index" == "null" ]; then
          # If the table doesn't exist, create a new one with the column
          json=$(echo "$json" | jq --arg table "$table" --argjson column "$column_json" '.['"$database_index"'].tables += [{"name": $table, "columns": [$column]}]')
        else
          # If the table exists, add the column to it
          json=$(echo "$json" | jq --argjson column "$column_json" '.['"$database_index"'].tables['"$table_index"'].columns += [$column]')
        fi
      fi
    done

    echo "$json" >&2
    # Print the final JSON array
    echo "$json"
}
# GET Data Source payload
get_ds_payload(){
  name=$1
  database_id=$2
  columns=$3

  database_json_object=$(get_database_json_object "$columns")  
  
  # Start building the JSON payload
  ds_payload=$(jq -n \
                --arg name "$name" \
                --arg database_id "$database_id" \
                 --argjson json "$database_json_object" \
                '{
                   "name": $name,
                   "type": "DB_COLUMN",
                   "dbColumn": {
                     "databaseRef": {
                       "id": $database_id
                     },
                     "databases": $json
                   }
                 }')
  echo "$ds_payload"
}

get_rle_dpp_payload(){
  name=$1
  data_source_ids_string=$2
  tenant_ids_string=$3
  tenant_columns=$4
  # Convert comma-separated strings to arrays
  IFS=',' read -ra data_source_ids <<< "$data_source_ids_string"
  IFS=',' read -ra tenant_ids <<< "$tenant_ids_string"
  tenant_columns_json=$(get_database_json_object "$tenant_columns")
 
  # Start building the JSON payload
  payload=$(jq -n \
            --arg name "$name" \
            --argjson tenant_columns_json "$tenant_columns_json" \
            '{
              "name": $name,
              "dataSources": [],
              "encryption": {
                "encryptionType": "TRADITIONAL",
                "encryptionKeyMode": "MULTI_TENANT",
                "traditionalEncryption": {
                  "encryptionFormat": "AES_CTR_DET",
                  "multiTenantKey": {
                    "tenantColumns": $tenant_columns_json,
                    "tenants": [],
                    "tenantDetermination": "TENANT_COLUMNS"
                  }
                }
              }
            }')

  # Iterate over the data source IDs and add each one to the dataSources array in the JSON payload
  for id in "${data_source_ids[@]}"; do
    payload=$(echo "$payload" | jq --arg id "$id" '.dataSources += [{"id": $id}]')
  done

  # Iterate over the tenant IDs and add each one to the tenants array in the JSON payload
  for id in "${tenant_ids[@]}"; do
    payload=$(echo "$payload" | jq --arg id "$id" '.encryption.traditionalEncryption.multiTenantKey.tenants += [{"id": $id}]')
  done
  echo "$payload"
}
# Get DB Proxy payload
get_db_proxy_payload(){
  db_proxy_access_payload=$(jq -n \
                        --arg name "$1" \
                        --arg database_id "$2" \
                        --arg aws_kms_id "$3" \
                        --arg kek_id "$4" \
                        '{
                          "name": $name,
                          "database": {
                            "id": $database_id
                          },
                          "keystore": {
                            "id": $aws_kms_id
                          },
                          "kek": {
                            "id": $kek_id
                          },
                          "encryption": true
                        }')

  echo "$db_proxy_access_payload"
}
get_proxy_configuration_payload(){
  local name=$1
  local type=$2
  local port=$3

  if [ "$type" == "RLE_PORT" ]; then
    proxy_configuration_payload=$(jq -n \
                         --arg name "$name" \
                         --argjson port "$port" \
                        '{
                          "name": $name,
                          "debugLevel": "NONE",
                          "rleConfig": {
                            "enabled": true,
                            "tenantDetermination": "TENANT_COLUMNS"
                          },
                          "advancedConfig": {
                             "baffleshield.clientPort": $port
                           }
                        }')

  elif [ "$type" == "PORT" ]; then
    proxy_configuration_payload=$(jq -n \
                         --arg name "$name" \
                         --argjson port "$port" \
                        '{
                          "name": $name,
                          "debugLevel": "TRANSFORMED_SQL",
                          "advancedConfig": {
                            "baffleshield.clientPort": $port
                          }
                        }')
  fi

  echo "$proxy_configuration_payload"

}

# get Deployment payload
get_deploy_payload(){
  name=$1
  dpp_ids=("$@")  # Capture all arguments into an array
  # remove name from the array
  unset dpp_ids[0]
  added_policies="["

  # Loop over the DPP IDs and add them to the JSON string
  for id in "${dpp_ids[@]}"; do
    added_policies+="{\"id\": \"$id\"},"
  done

  # Remove the trailing comma and close the JSON string
  added_policies=${added_policies%?}
  added_policies+="]"


 deploy_payload=$(jq -n \
                --arg name "$1" \
                --argjson added_policies "$added_policies" \
                '{
                  "name": $name,
                  "type": "DATA_POLICIES",
                  "mode": "ADD_POLICIES",
                  "dataPolicies": {
                    "addedDataPolicies": $added_policies
                  }
                }')

  echo "$deploy_payload"
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
################## Main Workflow ##################
configure_bm(){
  ################## Configuration for Baffle Manager ##################
  echo -e "\n#### Configuring Baffle Manager... ####\n" >&2
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
  # Enroll KEK-1
    kek1_payload=$(get_kek_payload "$kek_name_1" "$aws_kms_id" )
    kek1_id=$(send_post_request "$jwt_token" "$kek_url" "$kek1_payload" "id")
    if [ "$kek1_id" == "error" ]; then
      echo "KEK-1 enrollment failed. Exiting script." >&2
      exit 1
    else
      echo "KEK-1 ID: $kek1_id" >&2
    fi
    # Enroll KEK-2
    kek2_payload=$(get_kek_payload "$kek_name_2" "$aws_kms_id" )
    kek2_id=$(send_post_request "$jwt_token" "$kek_url" "$kek2_payload" "id")
    if [ "$kek2_id" == "error" ]; then
      echo "KEK-2 enrollment failed. Exiting script." >&2
      exit 1
    else
      echo "KEK-2 ID: $kek2_id" >&2
    fi



  # Get Database payload
  database_payload=$(get_database_payload)
  # Enroll Database
  database_id=$(send_post_request "$jwt_token" "$database_url" "$database_payload" "id")
  if [ "$database_id" == "error" ]; then
    echo "Database enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "Database ID: $database_id" >&2
  fi
}

################## Configuration for RLE Database Proxy ##################
configure_rle_database_proxy(){
  echo -e "\n#### Configuring RLE Database Proxy... ####\n" >&2

  # Enroll Tenant-1
  random_number_t1=$((RANDOM % 1000 + 1))
  rle_tenant1_payload=$(get_tenant_payload "Rle-Tenant-1" "T-1001" "$aws_kms_id" "$kek1_id" "T-rle-1001-dek-$random_number_t1")
  rle_tenant1_id=$(send_post_request "$jwt_token" "$tenant_url" "$rle_tenant1_payload" "id")
  if [ "$rle_tenant1_id" == "error" ]; then
    echo "RLE Tenant-1 enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "RLE Tenant-1 ID: $rle_tenant1_id" >&2
  fi

  # Enroll Tenant-2
  random_number_t2=$((RANDOM % 1000 + 1))
  rle_tenant2_payload=$(get_tenant_payload "Rle-Tenant-2" "T-2002" "$aws_kms_id" "$kek2_id" "T-rle-2002-dek-$random_number_t2")
  rle_tenant2_id=$(send_post_request "$jwt_token" "$tenant_url" "$rle_tenant2_payload" "id")
  if [ "$rle_tenant2_id" == "error" ]; then
    echo "Tenant-2 enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "Tenant-2 ID: $rle_tenant2_id" >&2
  fi

  # Get SSN Data Source payload
  customers_data_source="rle_db,customers,ssn,varchar(50)
rle_db,customers,ccn,varchar(50)"
  ds_rle_payload=$(get_ds_payload "ssn_rle_ds" "$database_id" "$customers_data_source")
  # Enroll SSN data source
  ds_rle_id=$(send_post_request "$jwt_token" "$data_source_url" "$ds_rle_payload" "id")
  if [ "$ds_rle_id" == "error" ]; then
    echo "SSN Data Source enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "SSN Data Source ID: $ds_rle_id" >&2
  fi


  # Get DPP payload
  tenant_columns="rle_db,customers,entity_id,varchar(50)"
  rle_dpp_payload=$(get_rle_dpp_payload "rle-ssn-ccn-dpp" "$ds_rle_id" "$rle_tenant1_id,$rle_tenant2_id" "$tenant_columns")
  # Enroll DPP
  rle_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$rle_dpp_payload" "id")
  if [ "$rle_dpp_id" == "error" ]; then
    echo "RLE DPP enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "RLE DPP ID: $rle_dpp_id" >&2
  fi

  # Get DB Proxy payload
  db_proxy_rle_payload=$(get_db_proxy_payload "proxy_rle" "$database_id" "$aws_kms_id" "$kek_id")
  # Enroll DB Proxy
  read db_proxy_rle_id rle_syncId <<< $(send_post_request "$jwt_token" "$db_proxy_url" "$db_proxy_rle_payload" "id" "syncId")
  if [ "$db_proxy_rle_id" == "error" ]; then
    echo "DB Proxy enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "DB Proxy ID: $db_proxy_rle_id" >&2
    echo "Sync ID: $rle_syncId" >&2
  fi

  # Apply Configure
  config_payload=$(get_proxy_configuration_payload "rle_port_change" "RLE_PORT" "5432")
  # Apply Configuration
  config_name=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_rle_id/configurations" "$config_payload" "name")
  if [ "$config_name" == "error" ]; then
    echo "Applying configuration failed. Exiting script." >&2
    exit 1
  else
    echo "Configuration applied : RLE Enabled and Port change to $shield_rle_port" >&2
  fi



  # Get Deployment payload
  deploy_rle_payload=$(get_deploy_payload "add_encryption_access_policies" "$rle_dpp_id")
  # Deploy DPP
  deployment_rle_id=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_rle_id/data-policies/deploy" "$deploy_rle_payload" "id")
  if [ "$deployment_rle_id" == "error" ]; then
    echo "Deployment failed. Exiting script." >&2
    exit 1
  else
    echo "Deployment ID: $deployment_rle_id" >&2
  fi

}

delete_resources(){
  ids_string=$1
  url=$2

  # Set IFS to newline and read each line into the array
  IFS=$'\n' read -d '' -ra ids <<< "$ids_string"
  for id in "${ids[@]}"; do
    echo "  Deleting resource with ID: $id" >&2
    result=$(send_delete_request "$jwt_token" "$url/$id")
    if [ "$result" == "error" ]; then
      echo "  Failed to delete DPP with ID: $id" >&2
    else
      echo "  Resource with ID: $id deleted" >&2
    fi
  done
}

cleanup(){
  echo -e "\n#### Cleaning up... ####\n" >&2
  #login
  login_payload=$(get_login_payload)
  jwt_token=$(send_post_request "null" "$login_url" "$login_payload" "accessToken" )
  if [ "$jwt_token" == "error" ]; then
    echo "Login failed. Exiting script." >&2
    exit 1
  else
    echo "JWT Token: $jwt_token" >&2
    echo "Login successful." >&2
  fi

  # Delete Proxy
  ids=$(send_get_request "$jwt_token" "$db_proxy_url?fields=id")
  if [ "$ids" == "error" ]; then
    echo "Failed to get Proxy IDs. Exiting script." >&2
    exit 1
  fi
  echo "Proxy IDs: $ids" >&2
  delete_resources "$ids" "$db_proxy_url"

  # Delete DPP
  ids=$(send_get_request "$jwt_token" "$dpp_url?fields=id")
  if [ "$ids" == "error" ]; then
    echo "Failed to get DPP IDs. Exiting script." >&2
    exit 1
  fi
 echo "DPP IDs: $ids" >&2
 delete_resources "$ids" "$dpp_url"

  # Delete Data Sources
  ids=$(send_get_request "$jwt_token" "$data_source_url?fields=id")
  if [ "$ids" == "error" ]; then
    echo "Failed to get Data Source IDs. Exiting script." >&2
    exit 1
  fi
  echo "Data Source IDs: $ids" >&2
  delete_resources "$ids" "$data_source_url"

  # Delete Database
  ids=$(send_get_request "$jwt_token" "$database_url?fields=id")
  if [ "$ids" == "error" ]; then
    echo "Failed to get Database IDs. Exiting script." >&2
    exit 1
  fi
  echo "Database IDs: $ids" >&2
  delete_resources "$ids" "$database_url"

  # Delete Tenants
  ids=$(send_get_request "$jwt_token" "$tenant_url?fields=id")
  if [ "$ids" == "error" ]; then
    echo "Failed to get Tenant IDs. Exiting script." >&2
    exit 1
  fi
  echo "Tenant IDs: $ids" >&2
  delete_resources "$ids" "$tenant_url"

  # Delete KEKs
  ids=$(send_get_request "$jwt_token" "$kek_url")
  if [ "$ids" == "error" ]; then
    echo "Failed to get KEK IDs. Exiting script." >&2
    exit 1
  fi
  echo "KEK IDs: $ids" >&2
  delete_resources "$ids" "$kek_url"

  # Delete AWS KMS
  ids=$(send_get_request "$jwt_token" "$keystore_url")
  if [ "$ids" == "error" ]; then
    echo "Failed to get AWS KMS IDs. Exiting script." >&2
    exit 1
  fi
  echo "AWS KMS IDs: $ids" >&2
  delete_resources "$ids" "$keystore_url"
}

if [ "$1" == "cleanup" ]; then
  cleanup
else
  configure_bm
  configure_rle_database_proxy
fi
