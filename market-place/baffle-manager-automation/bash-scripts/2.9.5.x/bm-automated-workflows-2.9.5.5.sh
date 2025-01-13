#!/bin/bash

# Input parameters
username=$USERNAME
password=$PASSWORD
# Database info
db_host_name=$DB_HOST_NAME
db_port=5432
db_user_name=$DB_USER_NAME
db_password=$DB_PASSWORD
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

db_proxy_url="$base_url/api/v2/svc/database-proxies"
database_url="$base_url/api/v2/databases"
aws_kms_url="$base_url/api/v2/keystores/awskms"
kek_url="$base_url/api/v2/key-management/keks"
data_source_url="$base_url/api/v2/data-sources"
dpp_url="$base_url/api/v2/dpp"
fpe_decimal_url="$base_url/api/v2/encryption-policies/FPE_DECIMAL"
fpe_cc_url="$base_url/api/v2/encryption-policies/FPE_CREDIT_CARD"
user_group_url="$base_url/api/v2/data-access-control/user-groups"
tenant_url="$base_url/api/v2/key-management/tenants"
#Migration
migration_image=baffle-migration-v4:Release-Baffle.2.9.5.5
# Shield Hosts
postgres_shield_image=baffle-shield-postgresql-v4:Release-Baffle.2.9.5.5
shield_static_mask_folder="Baffle-Shield-Postgresql-Static-Mask"
shield_static_mask_host="shield_static_mask"
shield_static_mask_port=5432
shield_dynamic_mask_folder="Baffle-Shield-Postgresql-Dynamic-Mask"
shield_dynamic_mask_host="shield_dynamic_mask"
shield_dynamic_mask_port=5433
shield_cle_folder="Baffle-Shield-Postgresql-CLE"
shield_cle_host="shield_cle"
shield_cle_port=5434
shield_rle_folder="Baffle-Shield-Postgresql-RLE"
shield_rle_host="shield_rle"
shield_rle_port=5435
shield_dle_folder="Baffle-Shield-Postgresql-DLE"
shield_dle_host="shield_dle"
shield_dle_port=5436
shield_rqe_folder="Baffle-Shield-Postgresql-RQE"
shield_rqe_host="shield_rqe"
shield_rqe_port=5437
shield_rqe_migration_folder="Baffle-Shield-Postgresql-RQE-Migration"
shield_rqe_migration_host="shield_rqe_migration"
shield_rqe_migration_port=5438
migration_service_folder="Baffle-Migration"
shield_pg_vector_folder="Baffle-Shield-Postgresql-PG-vector"
shield_pg_vector_host="shield_pg_vector"
shield_pg_vector_port=5439


#Database Names
dms_source_db="dms_source_db"
dms_target_db="dms_target_db"
dynamic_mask_db="dynamic_mask_db"
cle_db="cle_db"
rle_db="rle_db"
dle_t1_db="dle_t1_db"
dle_t2_db="dle_t2_db"
rqe_db="rqe_db"
rqe_migration_db="rqe_migration_db"
pg_vector_db="pg_vector_db"

# Database Table Creation SQL Commands
customers_table_create_command="CREATE TABLE customers (
      uuid VARCHAR(40),
      first_name VARCHAR(50),
      ccn VARCHAR(50),
      ssn VARCHAR(50),
      entity_id VARCHAR(50)

  );"
employees_table_create_command="CREATE TABLE employees (
      uuid VARCHAR(40),
      first_name VARCHAR(50),
      last_name VARCHAR(50),
      ssn VARCHAR(50),
      age INT,
      salary INT
  );"
# Inserts for employees table
employees_insert_command="INSERT INTO employees (uuid, first_name, last_name, ssn, age, salary) VALUES
                          ('1', 'John', 'Doe Junior', '123-45-6789', 30, 100000),
                          ('2', 'Jane', 'Doe Senior', '234-56-7891', 35, 120000),
                          ('3', 'Bob', 'Smith', '345-67-8912', 40, 140000),
                          ('4', 'Alice', 'Smith Johnson', '456-78-9123', 45, 160000),
                          ('5', 'Charlie', 'Brown', '567-89-0123', 50, 180000),
                          ('6', 'David', 'Johnson', '678-90-1234', 55, 200000),
                          ('7', 'Eva', 'Jackson', '789-01-2345', 60, 220000),
                          ('8', 'Frank', 'Miller', '890-12-3456', 65, 240000),
                          ('9', 'Grace', 'Davis', '901-23-4567', 70, 260000),
                          ('10', 'Helen', 'Martin', '012-34-5678', 75, 280000);"

customer_profile_embeddings_table="CREATE TABLE customer_profile_embeddings (id int, chunk text, embeddings vector(1536));"
customer_profile_embeddings_insert_command="\COPY customer_profile_embeddings  from '/home/ec2-user/AE-2/data/customer_profile_embeddings.csv' delimiter ',' CSV HEADER;"

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
# Get Database payload
get_database_payload(){
database_payload=$(jq -n \
                  --arg hn "$db_host_name" \
                  --argjson p "$db_port" \
                  --arg un "$db_user_name" \
                  --arg pw "$db_password" \
                  '{
                    "name": "PostgresSQL",
                    "dbType": "POSTGRES",
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
# GET Data Source payload
get_ds_payload(){
  name=$1
  database_id=$2
  database_name=$3
  schema_name=$4
  table_name=$5
  columns=("${@:6}")  # Capture all arguments starting from the 6th into an array

  # Start building the JSON payload
  ds_payload=$(jq -n \
                --arg name "$name" \
                --arg database_id "$database_id" \
                --arg database_name "$database_name" \
                --arg schema_name "$schema_name" \
                --arg table_name "$table_name" \
                '{
                  "name": $name,
                  "type": "DB_COLUMN",
                  "dbColumn": {
                    "databaseRef": {
                      "id": $database_id
                    },
                    "databases": [
                      {
                        "name": $database_name,
                        "schemas": [
                          {
                            "name": $schema_name,
                            "tables": [
                              {
                                "name": $table_name,
                                "columns": []
                              }
                            ]
                          }
                        ]
                      }
                    ]
                  }
                }')

  # Loop over the columns and add them to the JSON payload
  for column in "${columns[@]}"; do
    IFS=':' read -r column_name column_datatype <<< "$column"
    if [ -z "$column_datatype" ]; then
      column_datatype="varchar(20)"  # Set a default datatype if none is provided
    fi
    ds_payload=$(echo "$ds_payload" | jq --arg column_name "$column_name" --arg column_datatype "$column_datatype" '.dbColumn.databases[0].schemas[0].tables[0].columns += [{"name": $column_name, "datatype": $column_datatype, "objectType": "TABLE", "verified": false}]')
  done

  echo "$ds_payload"
}
# Get User Group payload
get_user_group_payload() {
  local name=$1
  local users=("$@") # Capture all arguments into an array
  unset users[0] # Remove the first argument which is the name

  # Convert the array into a JSON array
  local json_users=$(printf '"%s",' "${users[@]}")
  json_users="[${json_users%,}]"

  user_group_payload=$(jq -n \
                    --arg name "$name" \
                    --arg json_users "$json_users" \
                    '{
                      "name": $name,
                      "users": $json_users|fromjson
                    }')

  echo "$user_group_payload"
}
# Get ssn data protection policy payload
get_ssn_fpe_dpp_payload(){
  data_source_id=$1
  kek_id=$2
  dek_id=$3
  fpe_decimal_id=$4

  ssn_dpp_payload=$(jq -n \
                  --arg data_source_id "$data_source_id" \
                  --arg fpe_decimal_id "$fpe_decimal_id" \
                  --arg kek_id "$kek_id" \
                  --arg dek_id "$dek_id" \
                  '{
                    "name": "ssn-fpe-decimal",
                    "dataSources": [
                      {
                        "id": $data_source_id
                      }
                    ],
                    "encryption": {
                      "encryptionType": "FPE",
                      "encryptionKeyMode": "GLOBAL",
                      "fpeEncryption": {
                        "fpeFormats": [
                          {
                            "id": $fpe_decimal_id,
                            "format": "fpe-decimal",
                            "datatype": "varchar"
                          }
                        ],
                        "globalKey": {
                          "kek": {
                            "id": $kek_id
                          },
                          "dek": {
                            "id": $dek_id
                          }
                        }
                      }
                    }
                  }')

  echo "$ssn_dpp_payload"
}

# Get ccn data protection policy payload
get_ccn_fpe_dpp_payload(){
  data_source_id=$1
  kek_id=$2
  dek_id=$3
  fpe_cc_id=$4
  support_user_group_id=$5
  ccn_access_dpp_payload=$(jq -n \
                        --arg data_source_id "$data_source_id" \
                        --arg fpe_cc_id "$fpe_cc_id" \
                        --arg kek_id "$kek_id" \
                        --arg dek_id "$dek_id" \
                        '{
                          "name": "ccn-fpe-cc",
                          "dataSources": [
                            {
                              "id": $data_source_id
                            }
                          ],
                          "encryption": {
                            "encryptionType": "FPE",
                            "encryptionKeyMode": "GLOBAL",
                            "fpeEncryption": {
                                "fpeFormats": [
                                  {
                                    "id": $fpe_cc_id,
                                    "format": "fpe-cc",
                                    "datatype": "varchar"
                                  }
                                ],
                                "globalKey": {
                                  "kek": {
                                    "id": $kek_id
                                  },
                                  "dek": {
                                    "id": $dek_id
                                  }
                                }
                            }
                          }
                        }')

  echo "$ccn_access_dpp_payload"
}

# Get ssn data protection with access policy payload
get_ssn_fpe_access_dpp_payload(){
  data_source_id=$1
  kek_id=$2
  dek_id=$3
  fpe_decimal_id=$4
  admin_user_group_id=$5
  support_user_group_id=$6
  hr_user_group_id=$7

  ssn_access_dpp_payload=$(jq -n \
                        --arg data_source_id "$data_source_id" \
                        --arg fpe_decimal_id "$fpe_decimal_id" \
                        --arg kek_id "$kek_id" \
                        --arg dek_id "$dek_id" \
                        --arg support_user_group_id "$support_user_group_id" \
                        --arg hr_user_group_id "$hr_user_group_id" \
                        --arg admin_user_group_id "$admin_user_group_id" \
                        '{
                          "name": "ssn-fpe-decimal-access",
                          "dataSources": [
                            {
                              "id": $data_source_id,
                              "name": "user-pii"
                            }
                          ],
                          "encryption": {
                            "encryptionType": "FPE",
                            "encryptionKeyMode": "GLOBAL",
                            "fpeEncryption": {
                                "fpeFormats": [
                                  {
                                    "id": $fpe_decimal_id,
                                    "format": "fpe-decimal",
                                    "datatype": "varchar"
                                  }
                                ],
                                "globalKey": {
                                  "kek": {
                                    "id": $kek_id
                                  },
                                  "dek": {
                                    "id": $dek_id
                                  }
                                }
                            }
                          },
                          "accessControl": {
                           "databaseProxy": {
                             "defaultPermission": "MASK",
                             "defaultMasks": [
                               {
                                 "datatype": "varchar",
                                 "type": "FIXED",
                                 "value": "**confidential**"
                               }
                             ],
                             "userGroupPayloads": [
                               {
                                 "userGroup": {
                                   "id": $support_user_group_id
                                 },
                                 "permission": "MASK",
                                 "masks": [
                                   {
                                     "datatype": "varchar",
                                     "type": "PATTERN",
                                     "value": "ddd-dd-vvvv"
                                   }
                                 ]
                               },
                               {
                                 "userGroup": {
                                   "id": $hr_user_group_id
                                 },
                                 "permission": "READ",
                                 "masks": []
                               },
                               {
                                 "userGroup": {
                                   "id": $admin_user_group_id
                                 },
                                 "permission": "READ_WRITE",
                                 "masks": []
                               }
                             ]
                           }
                          }
                        }')

  echo "$ssn_access_dpp_payload"
}
# Get ccn data protection with access policy payload
get_ccn_fpe_access_dpp_payload(){
  data_source_id=$1
  kek_id=$2
  dek_id=$3
  fpe_cc_id=$4
  admin_user_group_id=$5
  support_user_group_id=$6

  ccn_access_dpp_payload=$(jq -n \
                        --arg data_source_id "$data_source_id" \
                        --arg fpe_cc_id "$fpe_cc_id" \
                        --arg kek_id "$kek_id" \
                        --arg dek_id "$dek_id" \
                        --arg support_user_group_id "$support_user_group_id" \
                        --arg admin_user_group_id "$admin_user_group_id" \
                        '{
                          "name": "ccn-fpe-cc-access",
                          "dataSources": [
                            {
                              "id": $data_source_id,
                              "name": "user-pii"
                            }
                          ],
                          "encryption": {
                            "encryptionType": "FPE",
                            "encryptionKeyMode": "GLOBAL",
                            "fpeEncryption": {
                                "fpeFormats": [
                                  {
                                    "id": $fpe_cc_id,
                                    "format": "fpe-cc",
                                    "datatype": "varchar"
                                  }
                                ],
                                "globalKey": {
                                  "kek": {
                                    "id": $kek_id
                                  },
                                  "dek": {
                                    "id": $dek_id
                                  }
                                }
                            }
                          },
                          "accessControl": {
                           "databaseProxy": {
                             "defaultPermission": "MASK",
                             "defaultMasks": [
                               {
                                 "datatype": "varchar",
                                 "type": "FIXED",
                                 "value": "**confidential**"
                               }
                             ],
                             "userGroupPayloads": [
                               {
                                 "userGroup": {
                                   "id": $support_user_group_id
                                 },
                                 "permission": "MASK",
                                 "masks": [
                                   {
                                     "datatype": "varchar",
                                     "type": "PATTERN",
                                     "value": "XXXX-XXXX-XXXX-vvvv"
                                   }
                                 ]
                               },
                               {
                                 "userGroup": {
                                   "id": $admin_user_group_id
                                 },
                                 "permission": "READ_WRITE",
                                 "masks": []
                               }
                             ]
                           }
                          }
                        }')

  echo "$ccn_access_dpp_payload"
}

# Get SSN CCN DPP payload with Ctr cmode
get_ctr_dpp_payload(){

  payload=$(jq -n \
          --arg name "$1" \
          --arg data_source_id "$2" \
          --arg kek_id "$3" \
          --arg dek_id "$4" \
          '{
            "name": $name,
            "dataSources": [
              {
                "id": $data_source_id
              }
            ],
            "encryption": {
              "encryptionType": "TRADITIONAL",
              "encryptionKeyMode": "GLOBAL",
              "traditionalEncryption": {
                "encryptionFormat": "AES_CTR_DET",
                "globalKey": {
                  "kek": {
                    "id": $kek_id
                  },
                  "dek": {
                    "id": $dek_id
                  }
                }
              }
            }
          }')

  echo "$payload"
}

# Get SSN CCN RLE DPP payload with Ctr cmode
get_rle_ctr_dpp_payload(){

  payload=$(jq -n \
          --arg name "$1" \
          --arg ds_id "$2" \
          --arg database_name "$3" \
          --arg tenant1_id "$4" \
          --arg tenant2_id "$5" \
          '{
            "name": $name,
            "dataSources": [
              {
                "id": $ds_id
              }
            ],
            "encryption": {
              "encryptionType": "TRADITIONAL",
              "encryptionKeyMode": "MULTI_TENANT",
              "traditionalEncryption": {
                "encryptionFormat": "AES_CTR_DET",
                "multiTenantKey": {
                  "tenantColumns": [
                    {
                      "name": $database_name,
                      "schemas": [
                        {
                          "name": "public",
                          "tables": [
                            {
                              "name": "customers",
                              "columns": [
                                {
                                  "name": "entity_id",
                                  "datatype": "varchar(50)",
                                  "objectType": "TABLE"
                                }
                              ]
                            }
                          ]
                        }
                      ]
                    }
                  ],
                  "tenants": [
                    {
                      "id": $tenant1_id
                    },
                    {
                      "id": $tenant2_id
                    }
                  ],
                  "tenantDetermination": "TENANT_COLUMNS"
                }
              }
            }
          }')

  echo "$payload"
}

# Get SSN CCN RLE DPP payload with Ctr cmode
get_ssn_ccn_dle_dpp_payload(){

  payload=$(jq -n \
          --arg name "$1" \
          --arg ds_id "$2" \
          --arg tenant_id "$3" \
          '{
             "name": $name,
             "dataSources": [
               {
                 "id": $ds_id
               }
             ],
             "encryption": {
               "encryptionType": "TRADITIONAL",
               "encryptionKeyMode": "MULTI_TENANT",
               "traditionalEncryption": {
                 "encryptionFormat": "AES_CTR_DET",
                 "multiTenantKey": {
                   "tenantColumns": [],
                   "tenants": [
                     {
                       "id": $tenant_id
                     }
                   ],
                   "tenantDetermination": "DB_NAME"
                 }
               }
             }
           }')

  echo "$payload"
}

# Get RQE DPP payload with Ctr cmode
get_rqe_ctr_dpp_payload(){

  payload=$(jq -n \
          --arg name "$1" \
          --arg rqe_ds_id "$2" \
          --arg kek_id "$3" \
          --arg dek_id "$4" \
          '{
            "name": $name,
            "dataSources": [
              {
                "id": $rqe_ds_id
              }
            ],
            "encryption": {
              "encryptionType": "TRADITIONAL",
              "encryptionKeyMode": "GLOBAL",
              "traditionalEncryption": {
                "encryptionFormat": "AES_CTR_DET",
                "globalKey": {
                  "kek": {
                    "id": $kek_id
                  },
                  "dek": {
                    "id": $dek_id
                  }
                }
              }
            }
          }')

  echo "$payload"
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
  if [ "$type" == "RBAC_PORT" ]; then
    proxy_configuration_payload=$(jq -n \
                        --arg name "$name" \
                        --argjson port "$port" \
                        '{
                           "name": $name,
                           "debugLevel": "NONE",
                           "rbacConfig": {
                             "mode": "SUPPORTED",
                             "userDetermination": "SESSION",
                             "enabled": true
                           },
                           "advancedConfig": {
                              "baffleshield.clientPort": $port
                            },
                            "observabilityConfig": {
                                "enableWorkload": true,
                                "enableError": true,
                                "enableAudit": true,
                                "includeQuery": true,
                                "outputAsJson": true
                            }
                         }')
  elif [ "$type" == "RLE_PORT" ]; then
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
                           },
                           "observabilityConfig": {
                             "enableWorkload": true,
                             "enableError": true,
                             "enableAudit": true,
                             "includeQuery": true,
                             "outputAsJson": true
                           }
                        }')
  elif [ "$type" == "DLE_PORT" ]; then
    proxy_configuration_payload=$(jq -n \
                         --arg name "$name" \
                         --argjson port "$port" \
                        '{
                          "name": $name,
                          "debugLevel": "NONE",
                          "dleConfig": {
                            "enabled": true
                          },
                          "advancedConfig": {
                             "baffleshield.clientPort": $port
                           },
                           "observabilityConfig": {
                             "enableWorkload": true,
                             "enableError": true,
                             "enableAudit": true,
                             "includeQuery": true,
                             "outputAsJson": true
                           }
                        }')
  elif [ "$type" == "RQE_PORT" ] || [ "$type" == "RQE_MIGRATION_PORT" ] || [ "$type" == "PG_VECTOR_PORT" ]; then
    proxy_configuration_payload=$(jq -n \
                             --arg name "$name" \
                             --argjson port "$port" \
                            '{
                              "name": $name,
                              "debugLevel": "NONE",
                              "advancedEncryption": "tier-2",
                              "advancedConfig": {
                                 "baffleshield.clientPort": $port
                               },
                               "observabilityConfig": {
                                 "enableWorkload": true,
                                 "enableError": true,
                                 "enableAudit": true,
                                 "includeQuery": true,
                                 "outputAsJson": true
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
                          },
                          "observabilityConfig": {
                            "enableWorkload": true,
                            "enableError": true,
                            "enableAudit": true,
                            "includeQuery": true,
                            "outputAsJson": true
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

# Get multi tenancy tenant payload
get_multi_tenancy_tenant_payload(){
  name=$1
  tenant_ids_string=$2 # comma-separated string
  # Convert comma-separated strings to arrays
  IFS=',' read -ra tenant_ids <<<"$tenant_ids_string"

  # Start building the JSON payload
  payload=$(jq -n \
    --arg name "$name" \
    '{
      "name": $name,
      "tenant": {
        "action": "ADD",
        "tenants":[]
      }
    }')
  # Iterate over the tenant IDs and add each one to the tenants array in the JSON payload
  for id in "${tenant_ids[@]}"; do
    payload=$(echo "$payload" | jq --arg id "$id" '.tenant.tenants += [{"id": $id}]')
  done
  echo "$payload"
}

get_postgres_rle_tenant_columns(){
  rle_db=$1
  rle_table=$2
  columns="$rle_db,public,$rle_table,entity_id,varchar"
  echo "$columns"
}

# Get multi tenancy tenant column payload
get_multi_tenancy_tenant_column_payload(){
  tenant_column_string=$1 # comma-separated string
  # Convert comma-separated string to array
  IFS=',' read -ra tenant_column_details <<<"$tenant_column_string"

  payload=$(jq -n \
    --arg database "${tenant_column_details[0]}" \
    --arg schema "${tenant_column_details[1]}" \
    --arg table "${tenant_column_details[2]}" \
    --arg column "${tenant_column_details[3]}" \
    '{
      "action": "ADD",
      "tenantColumns": [
        {
          "database": $database,
          "schema": $schema,
          "table": $table,
          "column": $column
        }
      ]
    }')
  echo "$payload"
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




start_postgres_proxy(){
  access_syncId=$1
  folder_path=$2
  service_name=$3
  port=$4
  # create folder if it doesn't exist
  mkdir -p /home/ec2-user/"$folder_path"
  # create docker-compose.yml file
 printf '
version: "3.2"
services:
 %s:
   image: "%s"
   ports:
     - "%s:%s"
   environment:
     - BS_SYNC=BM4
     - BM_DB_PROXY_SYNC_ID=%s
     - BM_IP=nginx
     - BM_PORT=8443
     - BS_SSL=false
     - BS_SSL_KEYSTORE_PASSWORD=keystore
     - BS_SSL_TRUSTSTORE_PASSWORD=keystore
     - BS_SSL_TLS_VERSION=TLSv1.2
   networks:
     - baffle_network-frontend
   restart: always
networks:
 baffle_network-frontend:
   external: true
 ' "$service_name" "$postgres_shield_image" "$port" "$port" "$access_syncId" > /home/ec2-user/"$folder_path"/docker-compose.yml

  cd /home/ec2-user/"$folder_path"

  echo "Starting Postgres Proxy Service..." >&2
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
    echo "Port $port is open. Postgres Proxy Service is up and running." >&2
    echo "success"
  elif [ $counter -eq 10 ]; then
    echo "Port $port is not open after 5 minutes. Exiting script." >&2
    echo "error"
  fi
}

start_migration(){
  folder_path=$1
  service_name=$2
  sync_id=$3
  bs_Ip=$4
  bs_port=$5

  # create folder if it doesn't exist
  mkdir -p /home/ec2-user/"$folder_path"
  # create docker-compose.yml file
 printf '
version: "3.2"
services:
 %s:
   image: "%s"
   environment:
     - BM_DB_PROXY_SYNC_ID=%s
     - BM_IP=nginx
     - BM_PORT=8443
     - BS_IP=%s
     - BS_PORT=%s
   networks:
     - baffle_network-frontend
   restart: always

networks:
 baffle_network-frontend:
   external: true
 ' "$service_name" "$migration_image" "$sync_id" "$bs_Ip" "$bs_port" > /home/ec2-user/"$folder_path"/docker-compose.yml

  cd /home/ec2-user/"$folder_path"

  echo "Starting Migration Service..." >&2
  # Run docker compose
  docker-compose up -d &

}


start_bm(){
  # change the current directory
  cd /opt/manager
  # Start the Baffle Manager service
  docker-compose up -d &
}

start_pg_admin(){
  # change the current directory
   mkdir -p /home/ec2-user/pg-admin
   cd /home/ec2-user/pg-admin
  # create server.json based on $execute_workflow
  if [ "$execute_workflow" == "DYNAMIC_MASK" ]; then
    group="dynamic-mask"
    shield_host=$shield_dynamic_mask_host
    shield_port=$shield_dynamic_mask_port
  elif [ "$execute_workflow" == "CLE" ]; then
    group="cle"
    shield_host=$shield_cle_host
    shield_port=$shield_cle_port
  elif [ "$execute_workflow" == "RLE" ]; then
    group="rle"
    shield_host=$shield_rle_host
    shield_port=$shield_rle_port
  elif [  "$execute_workflow" == "DLE" ]; then
    group="dle"
    shield_host=$shield_dle_host
    shield_port=$shield_dle_port
  elif [  "$execute_workflow" == "RQE" ]; then
    group="rqe"
    shield_host=$shield_rqe_host
    shield_port=$shield_rqe_port
  elif [  "$execute_workflow" == "RQE_MIGRATION" ]; then
    group="rqe-migration"
    shield_host=$shield_rqe_migration_host
    shield_port=$shield_rqe_migration_port
  elif [  "$execute_workflow" == "PG_VECTOR" ]; then
    group="pg-vector"
    shield_host=$shield_pg_vector_host
    shield_port=$shield_pg_vector_port
  fi


   if [ "$execute_workflow" == "STATIC_MASK" ]; then
     servers_json=$(jq -n \
                                    --arg db_host_name "$db_host_name" \
                                    --argjson db_port "$db_port" \
                                    --arg db_user_name "$db_user_name" \
                                    '{
                                        "Servers": {
                                          "1": {
                                            "Name": "direct@baffle",
                                            "Group": "dms-static-mask",
                                            "Host": $db_host_name,
                                            "Port": $db_port,
                                            "MaintenanceDB": "postgres",
                                            "Username": $db_user_name,
                                            "PassFile": "/pgadmin4/pgpass",
                                            "role": "baffle"
                                          }
                                        }
                                    }')
    elif [ "$execute_workflow" == "DYNAMIC_MASK" ]; then
      servers_json=$(jq -n \
                                    --arg db_host_name "$db_host_name" \
                                    --argjson db_port "$db_port" \
                                    --arg db_user_name "$db_user_name" \
                                    --arg shield_host "$shield_host" \
                                    --argjson shield_port "$shield_port" \
                                    --arg group "$group" \
                                    '{
                                        "Servers": {
                                          "1": {
                                            "Name": "direct@baffle",
                                            "Group": $group,
                                            "Host": $db_host_name,
                                            "Port": $db_port,
                                            "MaintenanceDB": "postgres",
                                            "Username": $db_user_name,
                                            "PassFile": "/pgadmin4/pgpass",
                                            "role": $db_user_name
                                          },
                                          "2": {
                                            "Name": "shield@baffle",
                                            "Group": $group,
                                            "Host": $shield_host,
                                            "Port": $shield_port,
                                            "MaintenanceDB": "postgres",
                                            "Username": $db_user_name,
                                            "PassFile": "/pgadmin4/pgpass",
                                            "role": $db_user_name
                                          },

                                          "3": {
                                            "Name": "Shield@harry_HR",
                                            "Group": $group,
                                            "Host": $shield_host,
                                            "Port": $shield_port,
                                            "MaintenanceDB": "postgres",
                                            "Username": "harry",
                                            "PassFile": "/pgadmin4/pgpass",
                                            "role": $db_user_name
                                          },
                                          "4": {
                                            "Name": "Shield@sally_support",
                                            "Group": $group,
                                            "Host": $shield_host,
                                            "Port": $shield_port,
                                            "MaintenanceDB": "postgres",
                                            "Username": "sally",
                                            "PassFile": "/pgadmin4/pgpass",
                                            "role": $db_user_name
                                          },
                                          "5": {
                                            "Name": "Shield@ron_remote",
                                            "Group": $group,
                                            "Host": $shield_host,
                                            "Port": $shield_port,
                                            "MaintenanceDB": "postgres",
                                            "Username": "ron",
                                            "PassFile": "/pgadmin4/pgpass",
                                            "role": $db_user_name
                                          }
                                        }
                                    }')
    elif [ "$execute_workflow" == "CLE" ] || [ "$execute_workflow" == "RLE" ] || [ "$execute_workflow" == "DLE" ] || [ "$execute_workflow" == "RQE" ] || [ "$execute_workflow" == "RQE_MIGRATION" ] || [ "$execute_workflow" == "PG_VECTOR" ]; then
      servers_json=$(jq -n \
                                    --arg db_host_name "$db_host_name" \
                                    --argjson db_port "$db_port" \
                                    --arg db_user_name "$db_user_name" \
                                    --arg shield_host "$shield_host" \
                                    --argjson shield_port "$shield_port" \
                                    --arg group "$group" \
                                    '{
                                        "Servers": {
                                          "1": {
                                            "Name": "shield@baffle",
                                            "Group": $group,
                                            "Host": $shield_host,
                                            "Port": $shield_port,
                                            "MaintenanceDB": "postgres",
                                            "Username": "baffle",
                                            "PassFile": "/pgadmin4/pgpass",
                                            "role": $db_user_name
                                          },
                                          "2": {
                                            "Name": "direct@baffle",
                                            "Group": $group,
                                            "Host": $db_host_name,
                                            "Port": $db_port,
                                            "MaintenanceDB": "postgres",
                                            "Username": $db_user_name,
                                            "PassFile": "/pgadmin4/pgpass",
                                            "role": $db_user_name
                                          }
                                        }
                                    }')
    elif [ "$execute_workflow" == "ALL" ]; then
      servers_json=$(jq -n \
                        --arg db_host_name "$db_host_name" \
                        --argjson db_port "$db_port" \
                        --arg db_user_name "$db_user_name" \
                        --argjson shield_static_mask_port "$shield_static_mask_port" \
                        --arg shield_dynamic_mask_host "$shield_dynamic_mask_host" \
                        --argjson shield_dynamic_mask_port "$shield_dynamic_mask_port" \
                        --arg shield_cle_host "$shield_cle_host" \
                        --argjson shield_cle_port "$shield_cle_port" \
                        --arg shield_rle_host "$shield_rle_host" \
                        --argjson shield_rle_port "$shield_rle_port" \
                        --arg shield_dle_host "$shield_dle_host" \
                        --argjson shield_dle_port "$shield_dle_port" \
                        --arg shield_rqe_host "$shield_rqe_host" \
                        --argjson shield_rqe_port "$shield_rqe_port" \
                        --arg shield_rqe_migration_host "$shield_rqe_migration_host" \
                        --argjson shield_rqe_migration_port "$shield_rqe_migration_port" \
                        --arg shield_pg_vector_host "$shield_pg_vector_host" \
                        --argjson shield_pg_vector_port "$shield_pg_vector_port" \
                        '{
                          "Servers": {
                            "1": {
                              "Name": "direct@baffle",
                              "Group": "dms-static-mask",
                              "Host": $db_host_name,
                              "Port": $shield_static_mask_port,
                              "MaintenanceDB": "postgres",
                              "Username": $db_user_name,
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "2": {
                              "Name": "direct@baffle",
                              "Group": "dynamic-mask",
                              "Host": $db_host_name,
                              "Port": $db_port,
                              "MaintenanceDB": "postgres",
                              "Username": $db_user_name,
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "3": {
                              "Name": "shield@baffle",
                              "Group": "dynamic-mask",
                              "Host": $shield_dynamic_mask_host,
                              "Port": $shield_dynamic_mask_port,
                              "MaintenanceDB": "postgres",
                              "Username": $db_user_name,
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "4": {
                              "Name": "Shield@harry_HR",
                              "Group": "dynamic-mask",
                              "Host": $shield_dynamic_mask_host,
                              "Port": $shield_dynamic_mask_port,
                              "MaintenanceDB": "postgres",
                              "Username": "harry",
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "5": {
                              "Name": "Shield@sally_support",
                              "Group": "dynamic-mask",
                              "Host": $shield_dynamic_mask_host,
                              "Port": $shield_dynamic_mask_port,
                              "MaintenanceDB": "postgres",
                              "Username": "sally",
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "6": {
                              "Name": "Shield@ron_remote",
                              "Group": "dynamic-mask",
                              "Host": $shield_dynamic_mask_host,
                              "Port": $shield_dynamic_mask_port,
                              "MaintenanceDB": "postgres",
                              "Username": "ron",
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "7": {
                              "Name": "Shield@baffle",
                              "Group": "cle",
                              "Host": $shield_cle_host,
                              "Port": $shield_cle_port,
                              "MaintenanceDB": "postgres",
                              "Username": "baffle",
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "8": {
                              "Name": "direct@baffle",
                              "Group": "cle",
                              "Host": $db_host_name,
                              "Port": $db_port,
                              "MaintenanceDB": "postgres",
                              "Username": $db_user_name,
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "9": {
                              "Name": "Shield@baffle",
                              "Group": "rle",
                              "Host": $shield_rle_host,
                              "Port": $shield_rle_port,
                              "MaintenanceDB": "postgres",
                              "Username": "baffle",
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "10": {
                              "Name": "direct@baffle",
                              "Group": "rle",
                              "Host": $db_host_name,
                              "Port": $db_port,
                              "MaintenanceDB": "postgres",
                              "Username": $db_user_name,
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "11": {
                              "Name": "Shield@baffle",
                              "Group": "dle",
                              "Host": $shield_dle_host,
                              "Port": $shield_dle_port,
                              "MaintenanceDB": "postgres",
                              "Username": "baffle",
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "12": {
                              "Name": "direct@baffle",
                              "Group": "dle",
                              "Host": $db_host_name,
                              "Port": $db_port,
                              "MaintenanceDB": "postgres",
                              "Username": $db_user_name,
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "13": {
                              "Name": "Shield@baffle",
                              "Group": "rqe",
                              "Host": $shield_rqe_host,
                              "Port": $shield_rqe_port,
                              "MaintenanceDB": "postgres",
                              "Username": "baffle",
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "14": {
                              "Name": "direct@baffle",
                              "Group": "rqe",
                              "Host": $db_host_name,
                              "Port": $db_port,
                              "MaintenanceDB": "postgres",
                              "Username": $db_user_name,
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "15": {
                              "Name": "Shield@baffle",
                              "Group": "rqe-migration",
                              "Host": $shield_rqe_migration_host,
                              "Port": $shield_rqe_migration_port,
                              "MaintenanceDB": "postgres",
                              "Username": "baffle",
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "16": {
                              "Name": "direct@baffle",
                              "Group": "rqe-migration",
                              "Host": $db_host_name,
                              "Port": $db_port,
                              "MaintenanceDB": "postgres",
                              "Username": $db_user_name,
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "17": {
                              "Name": "Shield@baffle",
                              "Group": "pg-vector",
                              "Host": $shield_pg_vector_host,
                              "Port": $shield_pg_vector_port,
                              "MaintenanceDB": "postgres",
                              "Username": "baffle",
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            },
                            "18": {
                              "Name": "direct@baffle",
                              "Group": "pg-vector",
                              "Host": $db_host_name,
                              "Port": $db_port,
                              "MaintenanceDB": "postgres",
                              "Username": $db_user_name,
                              "PassFile": "/pgadmin4/pgpass",
                              "role": "baffle"
                            }
                          }
                        }')
    fi



  echo  "Starting pgAdmin..." >&2
  # remove .env, servers.json and pgpass  files if they exist
  rm -f servers.json pgpass .env
  # create Servers.json file
  echo "$servers_json" > servers.json
  # create .env file with username and password
  printf "USERNAME=%s\nPASSWORD=%s\n" "$username" "$password" > .env

  # create PassFile
  pgpass_content="
$db_host_name:$db_port:*:$db_user_name:$db_password
$shield_dynamic_mask_host:$shield_dynamic_mask_port:*:$db_user_name:$db_password
$shield_dynamic_mask_host:$shield_dynamic_mask_port:*:harry:harry
$shield_dynamic_mask_host:$shield_dynamic_mask_port:*:sally:sally
$shield_dynamic_mask_host:$shield_dynamic_mask_port:*:ron:ron
$shield_cle_host:$shield_cle_port:*:baffle:$db_password
$shield_rle_host:$shield_rle_port:*:baffle:$db_password
$shield_dle_host:$shield_dle_port:*:baffle:$db_password
"
echo "$pgpass_content" > pgpass


  chmod 644 pgpass
  # Start pgAdmin

  #create docker-compose.yml file
  printf '
version: "3.3"
services:
  pgAdmin:
    image: dpage/pgadmin4
    environment:
      - PGADMIN_DEFAULT_EMAIL=${USERNAME}
      - PGADMIN_DEFAULT_PASSWORD=${PASSWORD}
    ports:
      - '8446:80'
    volumes:
       - ./servers.json:/pgadmin4/servers.json
       - ./pgpass:/pgadmin4/pgpass
    restart: always
    networks:
      - baffle_network-frontend
networks:
  baffle_network-frontend:
    external: true
  ' > docker-compose.yml

  docker-compose up -d &

  # sleep for 10 seconds
  sleep 10
  # Check if port 8446 is open
  counter=0
  while ! netstat -tuln | grep 8446 && [ $counter -lt 10 ]; do
    echo "Port 8446 is not open. Retrying in 30 seconds..." >&2
    sleep 30
    ((counter++))
  done

 if netstat -tuln | grep 8446; then
   echo "Port 8446 is open. PgAdmin Service is up and running." >&2
   echo "success"
 elif [ $counter -eq 10 ]; then
   echo "Port 8446 is not open after 5 minutes. Exiting script." >&2
   echo "error"
 fi


}
execute_sql_command() {
  hostname=$1
  port=$2
  username=$3
  database=$4
  command=$5
  error_message=$(PGPASSWORD=$db_password psql -v ON_ERROR_STOP=1 -h "$hostname" -p "$port" -U "$username" -d "$database" -c "$command" 2>&1)
  ssn_status_code=$?
  if [ $ssn_status_code -ne 0 ]; then
    echo "Error message: $error_message" >&2
    echo "error"
  else
    echo "success"
  fi
}

execute_sql_file() {
  hostname=$1
  port=$2
  username=$3
  database=$4
  sql_file=$5
  PGPASSWORD=$db_password psql -v ON_ERROR_STOP=1 -h "$hostname" -p "$port" -U "$username" -d "$database" -f "$sql_file" >&2
  ssn_status_code=$?
  if [ $ssn_status_code -ne 0 ]; then
    echo "error"
  else
    echo "success"
  fi
}

configure_static_mask_database_proxy(){
  ################## Configuration for Static Masking DMS Proxy ##################
  echo -e "\n#### Configuring Static Masking Proxy... ####\n" >&2
  # Create database and tables
  echo "Dropping & Creating databases and tables..." >&2
  drop_dms_source_db="DROP DATABASE IF EXISTS $dms_source_db;"
  drop_dms_target_db="DROP DATABASE IF EXISTS $dms_target_db;"
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "$drop_dms_source_db")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "$drop_dms_target_db")


  create_dms_source_db="CREATE DATABASE $dms_source_db;"
  create_dms_target_db="CREATE DATABASE $dms_target_db;"
  alter_table_replica_full_identity="ALTER TABLE customers REPLICA IDENTITY FULL;"
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "$create_dms_source_db")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "$create_dms_target_db")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$dms_source_db" "$customers_table_create_command")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$dms_target_db" "$customers_table_create_command")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$dms_source_db" "$alter_table_replica_full_identity")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$dms_target_db" "$alter_table_replica_full_identity")

  if [ "$execution_status" == "error" ]; then
    echo "Database and table creation failed. Exiting script." >&2
    exit 1
  fi
  # Get SSN Data Source payload
  ssn_ds_dms_payload=$(get_ds_payload "ssn_dms_ds" "$database_id" "$dms_target_db" "public" "customers" "ssn")
  # Enroll SSN data source
  ssn_ds_dms_id=$(send_post_request "$jwt_token" "$data_source_url" "$ssn_ds_dms_payload" "id")
  if [ "$ssn_ds_dms_id" == "error" ]; then
    echo "SSN Data Source enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "SSN Data Source ID: $ssn_ds_dms_id" >&2
  fi

  # Get CCN Data Source payload
  ccn_ds_dms_payload=$(get_ds_payload "ccn_dms_ds" "$database_id" "$dms_target_db" "public" "customers" "ccn")
  # Enroll CCN data source
  ccn_ds_dms_id=$(send_post_request "$jwt_token" "$data_source_url" "$ccn_ds_dms_payload" "id")
  if [ "$ccn_ds_dms_id" == "error" ]; then
    echo "CCN Data Source enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "CCN Data Source ID: $ccn_ds_dms_id" >&2
  fi

  # Get SSN DPP payload
  ssn_dpp_payload=$(get_ssn_fpe_dpp_payload "$ssn_ds_dms_id" "$kek_id" "$dek_id" "$fpe_decimal_id" "$support_user_group_id" "$hr_user_group_id")
  # Enroll SSN DPP
  ssn_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$ssn_dpp_payload" "id")
  if [ "$ssn_dpp_id" == "error" ]; then
    echo "SSN DPP enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "SSN DPP ID: $ssn_dpp_id" >&2
  fi

  # Get CCN DPP payload
  ccn_dpp_payload=$(get_ccn_fpe_dpp_payload "$ccn_ds_dms_id" "$kek_id" "$dek_id" "$fpe_cc_id" "$support_user_group_id")
  # Enroll CCN DPP
  ccn_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$ccn_dpp_payload" "id")
  if [ "$ccn_dpp_id" == "error" ]; then
    echo "CCN DPP enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "CCN DPP ID: $ccn_dpp_id" >&2
  fi

  db_proxy_static_mask_payload=$(get_db_proxy_payload "proxy_static_mask" "$database_id" "$aws_kms_id" "$kek_id")
  # Enroll DB Proxy
  read db_proxy_static_mask_id static_mask_syncId <<< $(send_post_request "$jwt_token" "$db_proxy_url" "$db_proxy_static_mask_payload" "id" "syncId")
  if [ "$db_proxy_static_mask_id" == "error" ]; then
    echo "DB Proxy enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "DB Proxy ID: $db_proxy_static_mask_id" >&2
    echo "Sync ID: $static_mask_syncId" >&2
  fi

  # Deploy DPP
  deploy_enc_payload=$(get_deploy_payload "add_encryption_policies" "$ssn_dpp_id" "$ccn_dpp_id")
  deployment_enc_id=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_static_mask_id/data-policies/deploy" "$deploy_enc_payload" "id")
  if [ "$deployment_enc_id" == "error" ]; then
    echo "Deployment failed. Exiting script." >&2
    exit 1
  else
    echo "Deployment ID: $deployment_enc_id" >&2
  fi

  # Start Static Mask Postgres Proxy
  status=$(start_postgres_proxy "$static_mask_syncId" "$shield_static_mask_folder" "$shield_static_mask_host" "$shield_static_mask_port")
  if [ "$status" == "error" ]; then
    echo "Postgres Static Mask Proxy startup failed. Exiting script."
    exit 1
  fi
}

################## Configuration for Dynamic Masking DMS Proxy ##################
configure_dynamic_mask_database_proxy(){
  echo -e "\n#### Configuring Dynamic Masking DMS Proxy... ####\n" >&2
    # Create database and tables
    echo "Dropping and Creating databases and tables..." >&2
    drop_dynamic_mask_db="DROP DATABASE IF EXISTS $dynamic_mask_db;"
    execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "$drop_dynamic_mask_db")

    create_dynamic_mask_db="CREATE DATABASE $dynamic_mask_db;"
    create_users_with_permissions_command="
      DROP USER IF EXISTS harry;
      CREATE USER harry PASSWORD 'harry';
      DROP USER IF EXISTS sally;
      CREATE USER sally PASSWORD 'sally';
      DROP USER IF EXISTS ron;
      CREATE USER ron WITH PASSWORD 'ron';
      GRANT USAGE ON SCHEMA public TO harry;
      GRANT SELECT ON TABLE customers TO harry;
      GRANT USAGE ON SCHEMA public TO sally;
      GRANT SELECT ON TABLE customers TO sally;
      GRANT USAGE ON SCHEMA public TO ron;
      GRANT SELECT ON TABLE customers TO ron;

      CREATE TABLE IF NOT EXISTS public.baffle_shadow_schema
        (
            attrelid oid NOT NULL,
            attname name COLLATE pg_catalog.\"C\" NOT NULL,
            atttypid oid,
            atttypmod integer,
            table_schema information_schema.sql_identifier COLLATE pg_catalog.\"C\",
            table_name information_schema.sql_identifier COLLATE pg_catalog.\"C\",
            column_name information_schema.sql_identifier COLLATE pg_catalog.\"C\",
            udt_name information_schema.sql_identifier COLLATE pg_catalog.\"C\",
            udt_schema information_schema.sql_identifier COLLATE pg_catalog.\"C\",
            data_type information_schema.character_data COLLATE pg_catalog.\"C\",
            character_maximum_length information_schema.cardinal_number,
            character_octet_length information_schema.cardinal_number,
            numeric_precision information_schema.cardinal_number,
            numeric_precision_radix information_schema.cardinal_number,
            numeric_scale information_schema.cardinal_number,
            datetime_precision information_schema.cardinal_number,
            interval_type information_schema.character_data COLLATE pg_catalog.\"C\",
            interval_precision information_schema.cardinal_number,
            column_default information_schema.character_data COLLATE pg_catalog.\"C\",
            attnum smallint,
            attlen smallint,
            attstorage \"char\",
            CONSTRAINT shadow_db_key PRIMARY KEY (attname, attrelid)
        )
        TABLESPACE pg_default;

        ALTER TABLE IF EXISTS public.baffle_shadow_schema
            OWNER to baffle;

        REVOKE ALL ON TABLE public.baffle_shadow_schema FROM harry;
        REVOKE ALL ON TABLE public.baffle_shadow_schema FROM ron;
        REVOKE ALL ON TABLE public.baffle_shadow_schema FROM sally;
        GRANT ALL ON TABLE public.baffle_shadow_schema TO baffle;
        GRANT SELECT ON TABLE public.baffle_shadow_schema TO harry;
        GRANT SELECT ON TABLE public.baffle_shadow_schema TO ron;
        GRANT SELECT ON TABLE public.baffle_shadow_schema TO sally;"



    execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "$create_dynamic_mask_db")
    execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$dynamic_mask_db" "$customers_table_create_command")
    execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$dynamic_mask_db" "$create_users_with_permissions_command")

    if [ "$execution_status" == "error" ]; then
      echo "Database and table creation failed. Exiting script." >&2
      exit 1
    fi


  # Get Baffle User group payload
  baffle_user_group_payload=$(get_user_group_payload "admin" "baffle")
  # Enroll Baffle User Group
  baffle_user_group_id=$(send_post_request "$jwt_token" "$user_group_url" "$baffle_user_group_payload" "id")
  if [ "$baffle_user_group_id" == "error" ]; then
    echo "Baffle User Group enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "Baffle User Group ID: $baffle_user_group_id" >&2
  fi

  # Get HR User Group payload
  hr_user_group_payload=$(get_user_group_payload "human_resources" "harry")
  # Enroll HR User Group
  hr_user_group_id=$(send_post_request "$jwt_token" "$user_group_url" "$hr_user_group_payload" "id")
  if [ "$hr_user_group_id" == "error" ]; then
    echo "HR User Group enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "HR User Group ID: $hr_user_group_id" >&2
  fi

  # Get Support User Group payload
  support_user_group_payload=$(get_user_group_payload "support" "sally")
  # Enroll Support User Group
  support_user_group_id=$(send_post_request "$jwt_token" "$user_group_url" "$support_user_group_payload" "id")
  if [ "$support_user_group_id" == "error" ]; then
    echo "Support User Group enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "Support User Group ID: $support_user_group_id" >&2
  fi

  # Get Remote User Group payload
  remote_user_group_payload=$(get_user_group_payload "remote" "ron")
  # Enroll Remote User Group
  remote_user_group_id=$(send_post_request "$jwt_token" "$user_group_url" "$remote_user_group_payload" "id")
  if [ "$remote_user_group_id" == "error" ]; then
    echo "Remote User Group enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "Remote User Group ID: $remote_user_group_id"  >&2
  fi
  # Get SSN Data Source payload
  ssn_ds_dynamic_payload=$(get_ds_payload "ssn_dynamic_ds" "$database_id" "$dynamic_mask_db" "public" "customers" "ssn")
  # Enroll SSN data source
  ssn_ds_dynamic_id=$(send_post_request "$jwt_token" "$data_source_url" "$ssn_ds_dynamic_payload" "id")
  if [ "$ssn_ds_dynamic_id" == "error" ]; then
    echo "SSN Data Source enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "SSN Data Source ID: $ssn_ds_dynamic_id" >&2
  fi

  # Get CCN Data Source payload
  ccn_ds_dynamic_payload=$(get_ds_payload "ccn_dynamic_ds" "$database_id" "$dynamic_mask_db" "public" "customers" "ccn")
  # Enroll CCN data source
  ccn_ds_dynamic_id=$(send_post_request "$jwt_token" "$data_source_url" "$ccn_ds_dynamic_payload" "id")
  if [ "$ccn_ds_dynamic_id" == "error" ]; then
    echo "CCN Data Source enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "CCN Data Source ID: $ccn_ds_dynamic_id" >&2
  fi

  # Get SSN ACCESS DPP payload
  ssn_access_dpp_payload=$(get_ssn_fpe_access_dpp_payload "$ssn_ds_dynamic_id" "$kek_id" "$dek_id" "$fpe_decimal_id" "$baffle_user_group_id" "$support_user_group_id" "$hr_user_group_id")
  # Enroll SSN ACCESS DPP
  ssn_access_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$ssn_access_dpp_payload" "id")
  if [ "$ssn_access_dpp_id" == "error" ]; then
    echo "SSN_ACCESS DPP enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "SSN_ACCESS DPP ID: $ssn_access_dpp_id" >&2
  fi

  # Get CCN ACCESS DPP payload
  ccn_access_dpp_payload=$(get_ccn_fpe_access_dpp_payload "$ccn_ds_dynamic_id" "$kek_id" "$dek_id" "$fpe_cc_id" "$baffle_user_group_id" "$support_user_group_id")
  # Enroll CCN ACCESS DPP
  ccn_access_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$ccn_access_dpp_payload" "id")
  if [ "$ccn_access_dpp_id" == "error" ]; then
    echo "CCN_ACCESS DPP enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "CCN_ACCESS DPP ID: $ccn_access_dpp_id" >&2
  fi


  # Get Dynamic Mask DB Proxy payload
  db_proxy_access_payload=$(get_db_proxy_payload "proxy_dynamic_mask" "$database_id" "$aws_kms_id" "$kek_id")
  # Enroll DB Proxy
  read db_proxy_access_id access_syncId <<< $(send_post_request "$jwt_token" "$db_proxy_url" "$db_proxy_access_payload" "id" "syncId")
  if [ "$db_proxy_access_id" == "error" ]; then
    echo "DB Proxy enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "DB Proxy ID: $db_proxy_access_id" >&2
    echo "Sync ID: $access_syncId" >&2
  fi

  # Apply Configure
  config_payload=$(get_proxy_configuration_payload "rbac_port_change" "RBAC_PORT" "$shield_dynamic_mask_port")
  # Apply Configuration
  config_name=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_access_id/configurations" "$config_payload" "name")
  if [ "$config_name" == "error" ]; then
    echo "Applying configuration failed. Exiting script." >&2
    exit 1
  else
    echo "Configuration applied : RBAC Enabled and Port change to $shield_dynamic_mask_port" >&2
  fi


  # Get Deployment payload
  deploy_payload=$(get_deploy_payload "add_encryption_access_policies" "$ssn_access_dpp_id" "$ccn_access_dpp_id")
  # Deploy DPP
  deployment_id=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_access_id/data-policies/deploy" "$deploy_payload" "id")
  if [ "$deployment_id" == "error" ]; then
    echo "Deployment failed. Exiting script." >&2
    exit 1
  else
    echo "Deployment ID: $deployment_id" >&2
  fi

  # Start Dynamic Mask Postgres Proxy
  status=$(start_postgres_proxy "$access_syncId" "$shield_dynamic_mask_folder" "$shield_dynamic_mask_host" "$shield_dynamic_mask_port")
  if [ "$status" == "error" ]; then
    echo "Postgres Dynamic MAsk Proxy startup failed. Exiting script."
    exit 1
  fi
}

################## Configuration for Cle Database Proxy ##################
configure_cle_database_proxy(){
  echo -e "\n#### Configuring CLE Database Proxy... ####\n" >&2
  # Create database and tables
  echo "Dropping & Creating Cle database..." >&2

  drop_cle_db="DROP DATABASE IF EXISTS $cle_db;"
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "$drop_cle_db")

  create_cle_db="CREATE DATABASE $cle_db;"
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "$create_cle_db")

  if [ "$execution_status" == "error" ]; then
    echo "Database and table creation failed. Exiting script." >&2
    exit 1
  fi

  # Get SSN Data Source payload
  ssn_ds_cle_payload=$(get_ds_payload "ssn_cle_ds" "$database_id" "$cle_db" "public" "customers" "ssn")
  # Enroll SSN data source
  ssn_ds_cle_id=$(send_post_request "$jwt_token" "$data_source_url" "$ssn_ds_cle_payload" "id")
  if [ "$ssn_ds_cle_id" == "error" ]; then
    echo "SSN Data Source enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "SSN Data Source ID: $ssn_ds_cle_id" >&2
  fi

  # Get CCN Data Source payload
  ccn_ds_cle_payload=$(get_ds_payload "ccn_cle_ds" "$database_id" "$cle_db" "public" "customers" "ccn")
  # Enroll CCN data source
  ccn_ds_cle_id=$(send_post_request "$jwt_token" "$data_source_url" "$ccn_ds_cle_payload" "id")
  if [ "$ccn_ds_cle_id" == "error" ]; then
    echo "CCN Data Source enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "CCN Data Source ID: $ccn_ds_cle_id" >&2
  fi

  # Get DPP payload
  ssn_cle_dpp_payload=$(get_ctr_dpp_payload "cle-ssn-dpp" "$ssn_ds_cle_id" "$kek_id" "$dek_id")
  # Enroll DPP
  ssn_cle_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$ssn_cle_dpp_payload" "id")
  if [ "$ssn_cle_dpp_id" == "error" ]; then
    echo "SSN CLE DPP enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "SSN CLE DPP ID: $ssn_cle_dpp_id" >&2
  fi

  # Get DPP payload
  ccn_cle_dpp_payload=$(get_ctr_dpp_payload "cle-ccn-dpp" "$ccn_ds_cle_id" "$kek_id" "$dek_id")
  # Enroll DPP
  ccn_cle_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$ccn_cle_dpp_payload" "id")
  if [ "$ccn_cle_dpp_id" == "error" ]; then
    echo "CCN CLE DPP enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "CCN CLE DPP ID: $ccn_cle_dpp_id" >&2
  fi

  # Get DB Proxy payload
  db_proxy_cle_payload=$(get_db_proxy_payload "proxy_cle" "$database_id" "$aws_kms_id" "$kek_id")
  # Enroll DB Proxy
  read db_proxy_cle_id cle_syncId <<< $(send_post_request "$jwt_token" "$db_proxy_url" "$db_proxy_cle_payload" "id" "syncId")
  if [ "$db_proxy_cle_id" == "error" ]; then
    echo "DB Proxy enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "DB Proxy ID: $db_proxy_cle_id" >&2
    echo "Sync ID: $cle_syncId" >&2
  fi

  # Get Port Change payload
  port_change_payload=$(get_proxy_configuration_payload "cle_port_change" "PORT" "$shield_cle_port")
  # Change the port
  port_name=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_cle_id/configurations" "$port_change_payload" "name")
  if [ "$port_name" == "error" ]; then
    echo "Changing port failed. Exiting script." >&2
    exit 1
  else
    echo "Port changed to 5434" >&2
  fi


  # Get Deployment payload
  deploy_cle_payload=$(get_deploy_payload "add_encryption_access_policies" "$ssn_cle_dpp_id" "$ccn_cle_dpp_id")
  # Deploy DPP
  deployment_cle_id=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_cle_id/data-policies/deploy" "$deploy_cle_payload" "id")
  if [ "$deployment_cle_id" == "error" ]; then
    echo "Deployment failed. Exiting script." >&2
    exit 1
  else
    echo "Deployment ID: $deployment_cle_id" >&2
  fi

  # Start CLE Postgres Proxy
  status=$(start_postgres_proxy "$cle_syncId" "$shield_cle_folder" "$shield_cle_host" "$shield_cle_port")
  if [ "$status" == "error" ]; then
    echo "Postgres CLE Proxy startup failed. Exiting script."
    exit 1
  fi


  # sleep for 10 seconds
  echo "Sleeping for 10 seconds..." >&2
  sleep 10

  # insert 4 rows into customers table into cle_db database using cle proxy
  echo "Inserting rows into customers table in CLE database..." >&2
  insert_command="INSERT INTO customers (uuid, first_name, ccn, ssn, entity_id) VALUES ('1', 'John', '1234-5678-1234-5678', '123-45-6789', 'T-1001');"
  insert_command+="INSERT INTO customers (uuid, first_name, ccn, ssn, entity_id) VALUES ('2', 'Jane', '2345-6789-0123-4567', '234-56-7891', 'T-1001');"
  insert_command+="INSERT INTO customers (uuid, first_name, ccn, ssn, entity_id) VALUES ('3', 'Bob', '3456-7890-1234-5678', '345-67-8912', 'T-2002');"
  insert_command+="INSERT INTO customers (uuid, first_name, ccn, ssn, entity_id) VALUES ('4', 'Alice', '4567-8901-2345-6789', '456-78-9123', 'T-2002');"
  execution_status=$(execute_sql_command "localhost" "$shield_cle_port" "$db_user_name" "$cle_db" "$customers_table_create_command")
  execution_status=$(execute_sql_command "localhost" "$shield_cle_port" "$db_user_name" "$cle_db" "$insert_command")

  if [ "$execution_status" == "error" ]; then
    echo "Inserting rows into customers table in CLE database failed. Exiting script." >&2
    exit 1
  else
    echo "Rows inserted into customers table in CLE database." >&2
  fi
}
################## Configuration for RLE Database Proxy ##################
configure_rle_database_proxy(){
  echo -e "\n#### Configuring RLE Database Proxy... ####\n" >&2
  # Create database and tables
  echo "Creating RLE database..." >&2

  drop_rle_db="DROP DATABASE IF EXISTS $rle_db;"
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "$drop_rle_db")

  create_rle_db="CREATE DATABASE $rle_db;"
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "$create_rle_db")

  if [ "$execution_status" == "error" ]; then
    echo "Database and table creation failed. Exiting script." >&2
    exit 1
  fi


  # Enroll Tenant-1
  rle_tenant1_payload=$(get_tenant_payload "Rle-Tenant-1" "T-1001" "$aws_kms_id" "$kek1_id" "T-rle-1001-dek")
  rle_tenant1_id=$(send_post_request "$jwt_token" "$tenant_url" "$rle_tenant1_payload" "id")
  if [ "$rle_tenant1_id" == "error" ]; then
    echo "RLE Tenant-1 enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "RLE Tenant-1 ID: $rle_tenant1_id" >&2
  fi

  # Enroll Tenant-2
  rle_tenant2_payload=$(get_tenant_payload "Rle-Tenant-2" "T-2002" "$aws_kms_id" "$kek2_id" "T-rle-2002-dek")
  rle_tenant2_id=$(send_post_request "$jwt_token" "$tenant_url" "$rle_tenant2_payload" "id")
  if [ "$rle_tenant2_id" == "error" ]; then
    echo "Tenant-2 enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "Tenant-2 ID: $rle_tenant2_id" >&2
  fi

  # Get SSN Data Source payload
  ssn_ds_rle_payload=$(get_ds_payload "ssn_rle_ds" "$database_id" "$rle_db" "public" "customers" "ssn")
  # Enroll SSN data source
  ssn_ds_rle_id=$(send_post_request "$jwt_token" "$data_source_url" "$ssn_ds_rle_payload" "id")
  if [ "$ssn_ds_rle_id" == "error" ]; then
    echo "SSN Data Source enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "SSN Data Source ID: $ssn_ds_rle_id" >&2
  fi

  # Get CCN Data Source payload
  ccn_ds_rle_payload=$(get_ds_payload "ccn_rle_ds" "$database_id" "$rle_db" "public" "customers" "ccn")
  # Enroll CCN data source
  ccn_ds_rle_id=$(send_post_request "$jwt_token" "$data_source_url" "$ccn_ds_rle_payload" "id")
  if [ "$ccn_ds_rle_id" == "error" ]; then
    echo "CCN Data Source enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "CCN Data Source ID: $ccn_ds_rle_id" >&2
  fi

  # Get DPP payload
  rle_ssn_dpp_payload=$(get_rle_ctr_dpp_payload "rle-ssn-dpp" "$ssn_ds_rle_id" "$rle_db" "$rle_tenant1_id" "$rle_tenant2_id")
  # Enroll DPP
  rle_ssn_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$rle_ssn_dpp_payload" "id")
  if [ "$rle_ssn_dpp_id" == "error" ]; then
    echo "RLE SSN DPP enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "RLE SSN DPP ID: $rle_ssn_dpp_id" >&2
  fi

  rle_ccn_dpp_payload=$(get_rle_ctr_dpp_payload "rle-ccn-dpp"  "$ccn_ds_rle_id" "$rle_db" "$rle_tenant1_id" "$rle_tenant2_id")
  # Enroll DPP
  rle_ccn_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$rle_ccn_dpp_payload" "id")
  if [ "$rle_ccn_dpp_id" == "error" ]; then
    echo "RLE CCN DPP enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "RLE CCN DPP ID: $rle_ccn_dpp_id" >&2
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
  config_payload=$(get_proxy_configuration_payload "rle_port_change" "RLE_PORT" "$shield_rle_port")
  # Apply Configuration
  config_name=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_rle_id/configurations" "$config_payload" "name")
  if [ "$config_name" == "error" ]; then
    echo "Applying configuration failed. Exiting script." >&2
    exit 1
  else
    echo "Configuration applied : RLE Enabled and Port change to $shield_rle_port" >&2
  fi


  # Add Multi Tenancy Tenant
  multi_tenant_payload=$(get_multi_tenancy_tenant_payload "MultiTenancyTenant" "$rle_tenant1_id,$rle_tenant2_id")
  multi_tenant_id=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_rle_id/multi-tenancy/deploy" "$multi_tenant_payload")
  if [ "$multi_tenant_id" == "error" ]; then
    echo "MultiTenancyTenant Addition failed. Exiting script." >&2
    exit 1
  else
    echo "MultiTenancyTenant Added" >&2
  fi

  # Add Multi Tenancy Tenant Column
  multi_tenant_columns_payload=$(get_multi_tenancy_tenant_column_payload "$(get_postgres_rle_tenant_columns "$rle_db" "customers")")
  multi_tenant_column_id=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_rle_id/multi-tenancy/tenant-columns" "$multi_tenant_columns_payload")
  if [ "$multi_tenant_column_id" == "error" ]; then
    echo "MultiTenancyTenantColumns Addition failed. Exiting script." >&2
    exit 1
  else
    echo "MultiTenancyTenantColumns Added" >&2
  fi


  # Get Deployment payload
  deploy_rle_payload=$(get_deploy_payload "add_encryption_access_policies" "$rle_ssn_dpp_id" "$rle_ccn_dpp_id")
  # Deploy DPP
  deployment_rle_id=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_rle_id/data-policies/deploy" "$deploy_rle_payload" "id")
  if [ "$deployment_rle_id" == "error" ]; then
    echo "Deployment failed. Exiting script." >&2
    exit 1
  else
    echo "Deployment ID: $deployment_rle_id" >&2
  fi

  # Start RLE Postgres Proxy
  status=$(start_postgres_proxy "$rle_syncId" "$shield_rle_folder" "$shield_rle_host" "$shield_rle_port")
  if [ "$status" == "error" ]; then
    echo "Postgres RLE Proxy startup failed. Exiting script."
    exit 1
  fi

  # Sleep for 10 seconds
  echo "Sleeping for 10 seconds..." >&2
  sleep 10
  # insert 4 rows into customers table into rle_db database using cle proxy
  echo "Inserting rows into customers table in RLE database..." >&2
  insert_command="INSERT INTO customers (uuid, first_name, ccn, ssn, entity_id) VALUES ('1', 'John', '1234-5678-1234-5678', '123-45-6789', 'T-1001');"
  insert_command+="INSERT INTO customers (uuid, first_name, ccn, ssn, entity_id) VALUES ('2', 'Jane', '2345-6789-0123-4567', '234-56-7891', 'T-1001');"
  insert_command+="INSERT INTO customers (uuid, first_name, ccn, ssn, entity_id) VALUES ('3', 'Bob', '3456-7890-1234-5678', '345-67-8912', 'T-2002');"
  insert_command+="INSERT INTO customers (uuid, first_name, ccn, ssn, entity_id) VALUES ('4', 'Alice', '4567-8901-2345-6789', '456-78-9123', 'T-2002');"
  execution_status=$(execute_sql_command "localhost" "$shield_rle_port" "$db_user_name" "$rle_db" "$customers_table_create_command")
  execution_status=$(execute_sql_command "localhost" "$shield_rle_port" "$db_user_name" "$rle_db" "$insert_command")

  if [ "$execution_status" == "error" ]; then
    echo "Inserting rows into customers table in RLE database failed. Exiting script." >&2
    exit 1
  else
    echo "Rows inserted into customers table in RLE database." >&2
  fi
}
################## Configuration DLE Proxy ##################
configure_dle_database_proxy(){
  echo -e "\n#### Configuring DLE Database Proxy... ####\n" >&2
  # Create database and tables
  echo "Dropping & Creating DLE Tenant-1 database..." >&2

  drop_dle_t1_db="DROP DATABASE IF EXISTS $dle_t1_db;"
  drop_dle_t2_db="DROP DATABASE IF EXISTS $dle_t2_db;"
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "$drop_dle_t1_db")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "$drop_dle_t2_db")

  create_dle_t1_db="CREATE DATABASE $dle_t1_db;"
  create_dle_t2_db="CREATE DATABASE $dle_t2_db;"
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "$create_dle_t1_db")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "$create_dle_t2_db")

  if [ "$execution_status" == "error" ]; then
    echo "Database and table creation failed. Exiting script." >&2
    exit 1
  fi

  # Enroll Tenant-1
  dle_tenant1_payload=$(get_tenant_payload "dle_tenant_1" "$dle_t1_db" "$aws_kms_id" "$kek1_id" "T1-dle-dek")
  dle_tenant1_id=$(send_post_request "$jwt_token" "$tenant_url" "$dle_tenant1_payload" "id")
  if [ "$dle_tenant1_id" == "error" ]; then
    echo "DLE Tenant-1 enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "DLE Tenant-1 ID: $dle_tenant1_id" >&2
  fi

  # Enroll Tenant-2
  dle_tenant2_payload=$(get_tenant_payload "dle_tenant_2" "$dle_t2_db" "$aws_kms_id" "$kek2_id" "T2-dle-dek")
  dle_tenant2_id=$(send_post_request "$jwt_token" "$tenant_url" "$dle_tenant2_payload" "id")
  if [ "$dle_tenant2_id" == "error" ]; then
    echo "DLE Tenant-2 enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "DLE Tenant-2 ID: $dle_tenant2_id" >&2
  fi

  # Get SSN CCN Data Source payload for tenant-1
  ds_dle_t1_payload=$(get_ds_payload "ssn_ccn_dle_t1_ds" "$database_id" "$dle_t1_db" "public" "customers" "ssn" "ccn")
  # Enroll SSN data source
  ds_dle_t1_id=$(send_post_request "$jwt_token" "$data_source_url" "$ds_dle_t1_payload" "id")
  if [ "$ds_dle_t1_id" == "error" ]; then
    echo "SSN Data Source enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "SSN Data Source ID: $ds_dle_t1_id" >&2
  fi

  # Get SSN CCN Data Source payload for tenant-2
  ds_dle_t2_payload=$(get_ds_payload "ssn_ccn_dle_t2_ds" "$database_id" "$dle_t2_db" "public" "customers" "ssn" "ccn")
  # Enroll CCN data source
  ds_dle_t2_id=$(send_post_request "$jwt_token" "$data_source_url" "$ds_dle_t2_payload" "id")
  if [ "$ds_dle_t2_id" == "error" ]; then
    echo "CCN Data Source enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "CCN Data Source ID: $ds_dle_t2_id" >&2
  fi

  # Get Tenant 1 DPP payload
  dle_tenant1_dpp_payload=$(get_ssn_ccn_dle_dpp_payload "dle-tenant1-ssn-ccn-dpp" "$ds_dle_t1_id" "$dle_tenant1_id")
  # Enroll DPP
  dle_tenant1_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$dle_tenant1_dpp_payload" "id")
  if [ "$dle_tenant1_dpp_id" == "error" ]; then
    echo "Tenant 1 DLE DPP enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "Tenant 1 DLE DPP ID: $dle_tenant1_dpp_id" >&2
  fi

  # Get Tenant 2 DPP payload
  dle_tenant2_dpp_payload=$(get_ssn_ccn_dle_dpp_payload "dle-tenant2-ssn-ccn-dpp" "$ds_dle_t2_id"  "$dle_tenant2_id")
  # Enroll DPP
  dle_tenant2_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$dle_tenant2_dpp_payload" "id")
  if [ "$dle_tenant2_dpp_id" == "error" ]; then
    echo "Tenant 2 DLE DPP enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "Tenant 2 DLE DPP ID: $dle_tenant2_dpp_id" >&2
  fi

  # Get DB Proxy payload
  db_proxy_dle_payload=$(get_db_proxy_payload "proxy_dle" "$database_id" "$aws_kms_id" "$kek_id")
  # Enroll DB Proxy
  read db_proxy_dle_id dle_syncId <<< $(send_post_request "$jwt_token" "$db_proxy_url" "$db_proxy_dle_payload" "id" "syncId")
  if [ "$db_proxy_dle_id" == "error" ]; then
    echo "DB Proxy enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "DB Proxy ID: $db_proxy_dle_id" >&2
    echo "Sync ID: $dle_syncId" >&2
  fi

  # Apply Configure
  config_payload=$(get_proxy_configuration_payload "dle_port_change" "DLE_PORT" "$shield_dle_port")
  # Apply Configuration
  config_name=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_dle_id/configurations" "$config_payload" "name")
  if [ "$config_name" == "error" ]; then
    echo "Applying configuration failed. Exiting script." >&2
    exit 1
  else
    echo "Configuration applied : DLE Enabled and Port change to $shield_dle_port" >&2
  fi

  # Add Multi Tenancy Tenant
  multi_tenant_payload=$(get_multi_tenancy_tenant_payload "DleMultiTenancyTenant" "$dle_tenant1_id,$dle_tenant2_id")
  multi_tenant_id=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_dle_id/multi-tenancy/deploy" "$multi_tenant_payload")
  if [ "$multi_tenant_id" == "error" ]; then
    echo "DleMultiTenancyTenant Addition failed. Exiting script." >&2
    exit 1
  else
    echo "DleMultiTenancyTenant Added" >&2
  fi


  # Get Deployment payload
  deploy_dle_payload=$(get_deploy_payload "add_encryption_access_policies" "$dle_tenant1_dpp_id" "$dle_tenant2_dpp_id")
  # Deploy DPP
  deployment_dle_id=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_dle_id/data-policies/deploy" "$deploy_dle_payload" "id")
  if [ "$deployment_dle_id" == "error" ]; then
    echo "Deployment failed. Exiting script." >&2
    exit 1
  else
    echo "Deployment ID: $deployment_dle_id" >&2
  fi

  # Start DLE Postgres Proxy
  status=$(start_postgres_proxy "$dle_syncId" "$shield_dle_folder" "$shield_dle_host" "$shield_dle_port")
  if [ "$status" == "error" ]; then
    echo "Postgres DLE Proxy startup failed. Exiting script."
    exit 1
  fi

  # Sleep for 10 seconds
  echo "Sleeping for 10 seconds..." >&2
  sleep 10

  dle_customers_table_create_command="CREATE TABLE customers (
        uuid VARCHAR(40),
        first_name VARCHAR(50),
        ccn VARCHAR(50),
        ssn VARCHAR(50)
    );"
  # insert 4 rows into customers table into dle_t1_db database using dle proxy
  insert_command="INSERT INTO customers (uuid, first_name, ccn, ssn ) VALUES ('1', 'John', '1234-5678-1234-5678', '123-45-6789');"
  insert_command+="INSERT INTO customers (uuid, first_name, ccn, ssn ) VALUES ('2', 'Jane', '2345-6789-0123-4567', '234-56-7891');"
  insert_command+="INSERT INTO customers (uuid, first_name, ccn, ssn ) VALUES ('3', 'Bob', '3456-7890-1234-5678', '345-67-8912');"
  insert_command+="INSERT INTO customers (uuid, first_name, ccn, ssn ) VALUES ('4', 'Alice', '4567-8901-2345-6789', '456-78-9123');"
  execution_status=$(execute_sql_command "localhost" "$shield_dle_port" "$db_user_name" "$dle_t1_db" "$dle_customers_table_create_command")
  execution_status=$(execute_sql_command "localhost" "$shield_dle_port" "$db_user_name" "$dle_t1_db" "$insert_command")

  if [ "$execution_status" == "error" ]; then
    echo "Inserting rows into customers table in DLE $dle_t1_db database failed. Exiting script." >&2
    exit 1
  else
    echo "Rows inserted into customers table in DLE $dle_t1_db database." >&2
  fi

  # insert 4 rows into customers table into dle_t2_db database using dle proxy
  insert_command="INSERT INTO customers (uuid, first_name, ccn, ssn ) VALUES ('1', 'John', '1234-5678-1234-5678', '123-45-6789');"
  insert_command+="INSERT INTO customers (uuid, first_name, ccn, ssn ) VALUES ('2', 'Jane', '2345-6789-0123-4567', '234-56-7891');"
  insert_command+="INSERT INTO customers (uuid, first_name, ccn, ssn ) VALUES ('3', 'Bob', '3456-7890-1234-5678', '345-67-8912');"
  insert_command+="INSERT INTO customers (uuid, first_name, ccn, ssn ) VALUES ('4', 'Alice', '4567-8901-2345-6789', '456-78-9123');"
  execution_status=$(execute_sql_command "localhost" "$shield_dle_port" "$db_user_name" "$dle_t2_db" "$dle_customers_table_create_command")
  execution_status=$(execute_sql_command "localhost" "$shield_dle_port" "$db_user_name" "$dle_t2_db" "$insert_command")

  if [ "$execution_status" == "error" ]; then
    echo "Inserting rows into customers table in DLE $dle_t2_db database failed. Exiting script." >&2
    exit 1
  else
    echo "Rows inserted into customers table in DLE $dle_t2_db database." >&2
  fi

}
################## Create RQE Database and Install UDF's ##################
create_rqe_db_install_udfs(){
  db_name=$1
 # Create database and tables
  echo "Dropping & Creating RQE database..." >&2
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "DROP DATABASE IF EXISTS $db_name;")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "CREATE DATABASE $db_name;")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$db_name" "create schema baffle_udfs;")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$db_name" "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA baffle_udfs TO $db_user_name;")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$db_name" "create extension if not exists pg_tle;")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$db_name" "GRANT pgtle_admin TO $db_user_name;")
  echo "Installing RQE UDFs..."
  execution_status=$(execute_sql_file "$db_host_name" "$db_port" "$db_user_name" "$db_name" "/home/ec2-user/AE-2/rqe_base_plpgsql.sql")
  if [ "$execution_status" == "error" ]; then
    echo "Installing RQE Base UDFs failed. Exiting script." >&2
    exit 1
  fi

  execution_status=$(execute_sql_file "$db_host_name" "$db_port" "$db_user_name" "$db_name" "/home/ec2-user/AE-2/rqe_udfs_plpgsql.sql")
  if [ "$execution_status" == "error" ]; then
    echo "Installing RQE UDFs failed. Exiting script." >&2
    exit 1
  fi
}

################## Configuration for RQE Database Proxy ##################
configure_rqe_database_proxy(){
  echo -e "\n#### Configuring RQE Database Proxy... ####\n" >&2
  # Create RQE database and install UDF's
  create_rqe_db_install_udfs "$rqe_db"
  # Get Data Source payload
  ds_rqe_payload=$(get_ds_payload "rqe_ds" "$database_id" "$rqe_db" "public" "employees" "ssn:varchar(50)" "age:int" "salary:int")

  # Enroll data source
  ds_rqe_id=$(send_post_request "$jwt_token" "$data_source_url" "$ds_rqe_payload" "id")
  if [ "$ds_rqe_id" == "error" ]; then
    echo "Data Source enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "Data Source ID: $ds_rqe_id" >&2
  fi

  # Get DPP payload
  rqe_dpp_payload=$(get_rqe_ctr_dpp_payload "rqe-dpp" "$ds_rqe_id" "$kek_id" "$dek_id" )
  # Enroll DPP
  rqe_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$rqe_dpp_payload" "id")
  if [ "$rqe_dpp_id" == "error" ]; then
    echo "RQE DPP enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "RQE DPP ID: $rqe_dpp_id" >&2
  fi

  # Get DB Proxy payload
  db_proxy_rqe_payload=$(get_db_proxy_payload "proxy_rqe" "$database_id" "$aws_kms_id" "$kek_id")
  # Enroll DB Proxy
  read db_proxy_rqe_id rqe_syncId <<< $(send_post_request "$jwt_token" "$db_proxy_url" "$db_proxy_rqe_payload" "id" "syncId")
  if [ "$db_proxy_rqe_id" == "error" ]; then
    echo "DB Proxy enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "DB Proxy ID: $db_proxy_rqe_id" >&2
    echo "Sync ID: $rqe_syncId" >&2
  fi

  # Apply Configure
  config_payload=$(get_proxy_configuration_payload "rqe_port_change" "RQE_PORT" "$shield_rqe_port")
  # Apply Configuration
  config_name=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_rqe_id/configurations" "$config_payload" "name")
  if [ "$config_name" == "error" ]; then
    echo "Applying configuration failed. Exiting script." >&2
    exit 1
  else
    echo "Configuration applied : RQE Enabled and Port change to $shield_rqe_port" >&2
  fi

  # Get Deployment payload
  deploy_rqe_payload=$(get_deploy_payload "add_encryption_access_policies" "$rqe_dpp_id")
  # Deploy DPP
  deployment_rqe_id=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_rqe_id/data-policies/deploy" "$deploy_rqe_payload" "id")
  if [ "$deployment_rqe_id" == "error" ]; then
    echo "Deployment failed. Exiting script." >&2
    exit 1
  else
    echo "Deployment ID: $deployment_rqe_id" >&2
  fi

  # Start RQE Postgres Proxy
  status=$(start_postgres_proxy "$rqe_syncId" "$shield_rqe_folder" "$shield_rqe_host" "$shield_rqe_port")
  if [ "$status" == "error" ]; then
    echo "Postgres RQE Proxy startup failed. Exiting script."
    exit 1
  fi

  # Sleep for 10 seconds
  echo "Sleeping for 10 seconds..." >&2
  sleep 10

  # create employees table
  echo "Creating employees table in RQE database..." >&2
  execution_status=$(execute_sql_command "localhost" "$shield_rqe_port" "$db_user_name" "$rqe_db" "$employees_table_create_command")
  execution_status=$(execute_sql_command "localhost" "$shield_rqe_port" "$db_user_name" "$rqe_db" "$employees_insert_command")

  if [ "$execution_status" == "error" ]; then
    echo "Inserting rows into employees table in RQE database failed. Exiting script." >&2
    exit 1
  else
    echo "Rows inserted into employees table in RQE database." >&2
  fi

}

################## Configuration for RQE Migration Database Proxy ##################
configure_rqe_migration_database_proxy(){
  echo -e "\n#### Configuring RQE Migration Database Proxy... ####\n" >&2
  # Create RQE Migration database and install UDF's
  create_rqe_db_install_udfs "$rqe_migration_db"
  # Get Data Source payload
  ds_rqe_migration_payload=$(get_ds_payload "rqe_migration_ds" "$database_id" "$rqe_migration_db" "public" "employees" "ssn:varchar(50)" "age:int" "salary:int")

  # Enroll data source
  ds_rqe_migration_id=$(send_post_request "$jwt_token" "$data_source_url" "$ds_rqe_migration_payload" "id")
  if [ "$ds_rqe_migration_id" == "error" ]; then
    echo "Data Source enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "Data Source ID: $ds_rqe_migration_id" >&2
  fi

  # Get DPP payload
  rqe_migration_dpp_payload=$(get_rqe_ctr_dpp_payload "rqe-migration-dpp" "$ds_rqe_migration_id" "$kek_id" "$dek_id" )
  # Enroll DPP
  rqe_migration_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$rqe_migration_dpp_payload" "id")
  if [ "$rqe_migration_dpp_id" == "error" ]; then
    echo "RQE Migration DPP enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "RQE Migration DPP ID: $rqe_migration_dpp_id" >&2
  fi

  # Get DB Proxy payload
  db_proxy_rqe_migration_payload=$(get_db_proxy_payload "proxy_rqe_migration" "$database_id" "$aws_kms_id" "$kek_id")
  # Enroll DB Proxy
  read db_proxy_rqe_migration_id rqe_migration_syncId <<< $(send_post_request "$jwt_token" "$db_proxy_url" "$db_proxy_rqe_migration_payload" "id" "syncId")
  if [ "$db_proxy_rqe_migration_id" == "error" ]; then
    echo "DB Proxy enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "DB Proxy ID: $db_proxy_rqe_migration_id" >&2
    echo "Sync ID: $rqe_migration_syncId" >&2
  fi

  # Apply Configure
  config_payload=$(get_proxy_configuration_payload "rqe_migration_port_change" "RQE_MIGRATION_PORT" "$shield_rqe_migration_port")
  # Apply Configuration
  config_name=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_rqe_migration_id/configurations" "$config_payload" "name")
  if [ "$config_name" == "error" ]; then
    echo "Applying configuration failed. Exiting script." >&2
    exit 1
  else
    echo "Configuration applied : RQE Migration Enabled and Port change to $shield_rqe_migration_port" >&2
  fi

  # Start RQE Migration Postgres Proxy
  status=$(start_postgres_proxy "$rqe_migration_syncId" "$shield_rqe_migration_folder" "$shield_rqe_migration_host" "$shield_rqe_migration_port")
  if [ "$status" == "error" ]; then
    echo "Postgres RQE Migration Proxy startup failed. Exiting script."
    exit 1
  fi

  # Sleep for 10 seconds
  echo "Sleeping for 10 seconds..." >&2
  sleep 10

  # Start RQE Migration Service
  status=$(start_migration "$migration_service_folder" "rqe_migration" "$rqe_migration_syncId" "$shield_rqe_migration_host" "$shield_rqe_migration_port" )
  if [ "$status" == "error" ]; then
    echo "RQE Migration Service startup failed. Exiting script."
    exit 1
  fi

  #create employees table
  echo "Creating employees table in RQE_Migration database..." >&2
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$rqe_migration_db" "$employees_table_create_command")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$rqe_migration_db" "$employees_insert_command")

  if [ "$execution_status" == "error" ]; then
    echo "Inserting rows into employees table in RQE_Migration database failed. Exiting script." >&2
    exit 1
  else
    echo "Rows inserted into employees table in RQE_Migration database." >&2
  fi

}

################## Create RQE Database and Install UDF's ##################
create_rqe_db_install_udfs(){
  db_name=$1
 # Create database and tables
  echo "Dropping & Creating RQE database..." >&2
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "DROP DATABASE IF EXISTS $db_name;")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "CREATE DATABASE $db_name;")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$db_name" "create schema baffle_udfs;")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$db_name" "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA baffle_udfs TO $db_user_name;")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$db_name" "create extension if not exists pg_tle;")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$db_name" "GRANT pgtle_admin TO $db_user_name;")
  echo "Installing RQE UDFs..."
  execution_status=$(execute_sql_file "$db_host_name" "$db_port" "$db_user_name" "$db_name" "/home/ec2-user/AE-2/rqe_base_plpgsql.sql")
  if [ "$execution_status" == "error" ]; then
    echo "Installing RQE Base UDFs failed. Exiting script." >&2
    exit 1
  fi

  execution_status=$(execute_sql_file "$db_host_name" "$db_port" "$db_user_name" "$db_name" "/home/ec2-user/AE-2/rqe_udfs_plpgsql.sql")
  if [ "$execution_status" == "error" ]; then
    echo "Installing RQE UDFs failed. Exiting script." >&2
    exit 1
  fi
}

################## Configuration for PG Vector Database Proxy ##################
configure_pg_vector_database_proxy(){
  echo -e "\n#### Configuring PG Vector Database Proxy... ####\n" >&2
  # Create PG vector database and install UDF's
  create_pg_vector_db_install_udfs "$pg_vector_db"
  # Get Data Source payload
  ds_vector_payload=$(get_ds_payload "pg_vector_ds" "$database_id" "$pg_vector_db" "public" "customer_profile_embeddings" "chunk:text" "embeddings:vector(1536)")

  # Enroll data source
  ds_pg_vector_id=$(send_post_request "$jwt_token" "$data_source_url" "$ds_vector_payload" "id")
  if [ "$ds_pg_vector_id" == "error" ]; then
    echo "Pg Vector Data Source enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "Pg Vector  Data Source ID: $ds_pg_vector_id" >&2
  fi

  # Get DPP payload
  pg_vector_dpp_payload=$(get_ctr_dpp_payload "pg-vector-dpp" "$ds_pg_vector_id" "$kek_id" "$dek_id" )
  # Enroll DPP
  pg_vector_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$pg_vector_dpp_payload" "id")
  if [ "$pg_vector_dpp_id" == "error" ]; then
    echo "Pg Vector  DPP enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "Pg Vector DPP ID: $pg_vector_dpp_id" >&2
  fi

  # Get DB Proxy payload
  db_proxy_pg_vector_payload=$(get_db_proxy_payload "proxy_pg_vector" "$database_id" "$aws_kms_id" "$kek_id")
  # Enroll DB Proxy
  read db_proxy_pq_vector_id pq_vector_syncId <<< $(send_post_request "$jwt_token" "$db_proxy_url" "$db_proxy_pg_vector_payload" "id" "syncId")
  if [ "$db_proxy_pq_vector_id" == "error" ]; then
    echo "DB Proxy enrollment failed. Exiting script." >&2
    exit 1
  else
    echo "DB Proxy ID: $db_proxy_pq_vector_id" >&2
    echo "Sync ID: $pq_vector_syncId" >&2
  fi

  # Apply Configure
  config_payload=$(get_proxy_configuration_payload "pg_vector_port_change" "PG_VECTOR_PORT" "$shield_pg_vector_port")
  # Apply Configuration
  config_name=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_pq_vector_id/configurations" "$config_payload" "name")
  if [ "$config_name" == "error" ]; then
    echo "Applying configuration failed. Exiting script." >&2
    exit 1
  else
    echo "Configuration applied : PG Vector Enabled and Port change to $shield_pg_vector_port" >&2
  fi

  # Get Deployment payload
  deploy_pg_vector_payload=$(get_deploy_payload "add_pg_vector_encryption_access_policies" "$pg_vector_dpp_id")
  # Deploy DPP
  deployment_pg_vector_id=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_pq_vector_id/data-policies/deploy" "$deploy_pg_vector_payload" "id")
  if [ "$deployment_pg_vector_id" == "error" ]; then
    echo "Deployment failed. Exiting script." >&2
    exit 1
  else
    echo "Deployment ID: $deployment_pg_vector_id" >&2
  fi

  # Start PG_Vector Postgres Proxy
  status=$(start_postgres_proxy "$pq_vector_syncId" "$shield_pg_vector_folder" "$shield_pg_vector_host" "$shield_pg_vector_port")
  if [ "$status" == "error" ]; then
    echo "Postgres PG Vector Proxy startup failed. Exiting script."
    exit 1
  fi

  # Sleep for 10 seconds
  echo "Sleeping for 10 seconds..." >&2
  sleep 10

  # create employees table
  echo "Creating customer_profile_embeddings table in RQE database..." >&2
  execution_status=$(execute_sql_command "localhost" "$shield_pg_vector_port" "$db_user_name" "$pg_vector_db" "$customer_profile_embeddings_table")
  execution_status=$(execute_sql_command "localhost" "$shield_pg_vector_port" "$db_user_name" "$pg_vector_db" "$customer_profile_embeddings_insert_command")

  if [ "$execution_status" == "error" ]; then
    echo "Inserting rows into customer_profile_embeddings table in PG Vector database failed. Exiting script." >&2
    exit 1
  else
    echo "Rows inserted into customer_profile_embeddings table in PG Vector database." >&2
  fi

  # Start the Gradio service
  status=$(start_gradio)
  if [ "$status" == "error" ]; then
    echo "Gradio startup failed. Exiting script."
    exit 1
  fi
}

################## Start PG Vector Gradio APP ##################
start_gradio(){
  echo -e "\n#### Starting Gradio... ####\n" >&2
  # change the current directory
  cd /opt/pgvector
  # Start the Baffle Manager service
  docker-compose up -d &

  # sleep for 10 seconds
  sleep 10
  # Check if port 7860 is open
  counter=0
  while ! netstat -tuln | grep 7860 && [ $counter -lt 10 ]; do
    echo "Port 7860 is not open. Retrying in 30 seconds..." >&2
    sleep 30
    ((counter++))
  done

 if netstat -tuln | grep 7860; then
   echo "Port 7860 is open. Gradio Service is up and running." >&2
   echo "success"
 elif [ $counter -eq 10 ]; then
   echo "Port 7860 is not open after 5 minutes. Exiting script." >&2
   echo "error"
 fi

}

################## Create PG Vector Database and Install UDF's ##################
create_pg_vector_db_install_udfs(){
  db_name=$1
 # Create database and tables
  echo "Dropping & Creating PG Vector database..." >&2
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "DROP DATABASE IF EXISTS $db_name;")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "postgres" "CREATE DATABASE $db_name;")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$db_name" "create schema baffle_udfs;")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$db_name" "GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA baffle_udfs TO $db_user_name;")
  execution_status=$(execute_sql_command "$db_host_name" "$db_port" "$db_user_name" "$db_name" "create extension if not exists vector;")
  echo "Installing RQE UDFs..."
  execution_status=$(execute_sql_file "$db_host_name" "$db_port" "$db_user_name" "$db_name" "/home/ec2-user/AE-2/rqe_base_plpgsql.sql")
  if [ "$execution_status" == "error" ]; then
    echo "Installing RQE Base UDFs failed. Exiting script." >&2
    exit 1
  fi

  execution_status=$(execute_sql_file "$db_host_name" "$db_port" "$db_user_name" "$db_name" "/home/ec2-user/AE-2/rqe_udfs_plpgsql.sql")
  if [ "$execution_status" == "error" ]; then
    echo "Installing RQE UDFs failed. Exiting script." >&2
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
  # write  if condition for workflows ALL, RLE, DLE
  if [ "$execute_workflow" == "ALL" ] || [ "$execute_workflow" == "RLE" ] || [ "$execute_workflow" == "DLE" ]; then
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

  # Get FPE Decimal Policy
  fpe_decimal_id=$(send_get_request "$jwt_token" "$fpe_decimal_url")
  if [ "$fpe_decimal_id" == "error" ]; then
    echo "FPE Decimal retrieval failed. Exiting script." >&2
    exit 1
  else
    echo "FPE Decimal ID: $fpe_decimal_id" >&2
  fi
  # Get FPE CC Policy
  fpe_cc_id=$(send_get_request "$jwt_token" "$fpe_cc_url")
  if [ "$fpe_cc_id" == "error" ]; then
    echo "FPE CC retrieval failed. Exiting script." >&2
    exit 1
  else
    echo "FPE CC ID: $fpe_cc_id" >&2
  fi
}
# Execute workflow based on execute_workflow variable. ALL, STATIC_MASK, DYNAMIC_MASK, CLE, RLE
configure_bm

if [ "$execute_workflow" == "ALL" ]; then
  configure_static_mask_database_proxy
  configure_dynamic_mask_database_proxy
  configure_cle_database_proxy
  configure_rle_database_proxy
  configure_dle_database_proxy
  configure_rqe_database_proxy
  configure_rqe_migration_database_proxy
  configure_pg_vector_database_proxy
elif [ "$execute_workflow" == "ENCRYPTION" ]; then
  configure_cle_database_proxy
  configure_rle_database_proxy
  configure_dle_database_proxy
elif [ "$execute_workflow" == "STATIC_MASK" ]; then
  configure_static_mask_database_proxy
elif [ "$execute_workflow" == "DYNAMIC_MASK" ]; then
  configure_dynamic_mask_database_proxy
elif [ "$execute_workflow" == "CLE" ]; then
  configure_cle_database_proxy
elif [ "$execute_workflow" == "RLE" ]; then
  configure_rle_database_proxy
elif [ "$execute_workflow" == "DLE" ]; then
  configure_dle_database_proxy
elif [ "$execute_workflow" == "RQE" ]; then
  configure_rqe_database_proxy
elif [ "$execute_workflow" == "RQE_MIGRATION" ]; then
  configure_rqe_migration_database_proxy
elif [ "$execute_workflow" == "PG_VECTOR" ]; then
  configure_pg_vector_database_proxy
else
  echo "Invalid workflow. Exiting script." >&2
  exit 1
fi

################## Configuration for PgAdmin ##################
# Start the pgAdmin service
status=$(start_pg_admin)
if [ "$status" == "error" ]; then
  echo "PgAdmin startup failed. Exiting script."
  exit 1
fi
