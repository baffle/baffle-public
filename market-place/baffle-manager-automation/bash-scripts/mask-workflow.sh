#!/bin/bash

# Input parameters
username=$USERNAME
password=$PASSWORD
# Database info
db_host_name=$DB_HOST_NAME
db_user_name=$DB_USER_NAME
db_password=$DB_PASSWORD
#Keystore info
aws_region=$KM_AWS_REGION
s3_bucket_name=$KM_S3_BUCKET_NAME
# Kek info
kek_name=$KM_KEK_NAME

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
  local body=$3
  local fields=("$@") # Capture all arguments into an array
  unset fields[0] fields[1] fields[2] # Remove the first three arguments which are jwt_token, url, and body
  # Send the POST request
  # if jwt_token is null, then no need to pass Authorization header
  if [ "$jwt_token" == "null" ]; then
    local response=$(curl -k -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -d "$body" "$url")
  else
    local response=$(curl -k -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $jwt_token" -d "$body" "$url")
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
# Get Database Body
get_database_body(){
  database_body=$(cat <<EOF
{
  "name": "PostgresSQL",
  "dbType": "POSTGRES",
  "hostname": "$db_host_name",
  "port": 5432,
  "dbUsername": "$db_user_name",
  "dbPassword": {
    "secretStoreType": "CLEAR",
    "secretValue": "$db_password"
  }
}
EOF
)
  echo "$database_body"
}

# Get AWS KMS Body
get_aws_kms_body(){
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
  aws_kms_body=$(cat <<EOF
{
  "name": "aws-kms",
  "kmsType": "AWS_KMS",
  "awsRegion": "$aws_region",
  "dekStoreType": "S3",
  "s3StorePayload": {
    "sseSupported": false,
    "bucketName": "$s3_bucket_name"
  },
  "authenticationMethod": "IAM_ROLE"
}
EOF
)
  echo "$aws_kms_body"
}

# Get KEK Body
get_kek_body(){
  kestore_id=$1
  kek_body=$(cat <<EOF
{
  "name": "$kek_name",
  "keystore": {
    "id": "$kestore_id"
  },
  "createNewDek": false,
  "dekFilePrefix": "baffle-"
}
EOF
)
  echo "$kek_body"
}

# Get DEK Body
get_dek_body(){
  kek_id=$1
  random_number=$((RANDOM % 1000 + 1)) # Generate a random number between 1 and 100
  dek_body=$(cat <<EOF
{
  "name": "baffle-dek-$random_number",
  "kek": {
    "id": "$kek_id"
  }
}
EOF
)
  echo "$dek_body"
}

# GET SSN Data Source Body
get_ssn_ds_body(){
  database_id=$1
  ssn_ds_body=$(cat <<EOF
{
  "name": "ssn",
  "type": "DB_COLUMN",
  "dbColumn": {
    "databaseRef": {
      "id": "$database_id"
    },
    "databases": [
      {
        "name": "sales_dev",
        "schemas": [
          {
            "name": "public",
            "tables": [
              {
                "name": "customers",
                "columns": [
                  {
                    "name": "ssn",
                    "datatype": "varchar(20)",
                    "objectType": "TABLE",
                    "verified": true
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
EOF
)
  echo "$ssn_ds_body"
}

# GET CCN Data Source Body
get_ccn_ds_body(){
  database_id=$1
  ccn_ds_body=$(cat <<EOF
{
  "name": "ccn",
  "type": "DB_COLUMN",
  "dbColumn": {
    "databaseRef": {
      "id": "$database_id"
    },
    "databases": [
      {
        "name": "sales_dev",
        "schemas": [
          {
            "name": "public",
            "tables": [
              {
                "name": "customers",
                "columns": [
                  {
                    "name": "ccn",
                    "datatype": "varchar(20)",
                    "objectType": "TABLE",
                    "verified": true
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
EOF
)
  echo "$ccn_ds_body"
}
# Get User Group Body
get_user_group_body() {
  local name=$1
  local users=("$@") # Capture all arguments into an array
  unset users[0] # Remove the first argument which is the name

  # Convert the array into a JSON array
  local json_users=$(printf '"%s",' "${users[@]}")
  json_users="[${json_users%,}]"

  user_group_body=$(cat <<EOF
{
  "name": "$name",
  "users": $json_users
}
EOF
)
  echo "$user_group_body"
}
# Get ssn data protection policy body
get_ssn_dpp_body(){
  data_source_id=$1
  kek_id=$2
  dek_id=$3
  fpe_decimal_id=$4
  support_user_group_id=$5
  hr_user_group_id=$6

  ssn_access_dpp_body=$(cat <<EOF
{
  "name": "ssn-fpe-decimal",
  "dataSources": [
    {
      "id": "$data_source_id",
      "name": "user-pii"
    }
  ],
  "encryption": {
    "encryptionType": "FPE",
    "encryptionKeyMode": "GLOBAL",
    "fpeEncryption": {
        "fpeFormats": [
          {
            "id": "$fpe_decimal_id",
            "format": "fpe-decimal",
            "datatype": "varchar"
          }
        ],
        "globalKey": {
          "kek": {
            "id": "$kek_id"
          },
          "dek": {
            "id": "$dek_id"
          }
        }
    }
  }
}
EOF
)
  echo "$ssn_access_dpp_body"
}

# Get ccn data protection policy body
get_ccn_dpp_body(){
  data_source_id=$1
  kek_id=$2
  dek_id=$3
  fpe_cc_id=$4
  support_user_group_id=$5
  ccn_access_dpp_body=$(cat <<EOF
{
  "name": "ccn-fpe-cc",
  "dataSources": [
    {
      "id": "$data_source_id",
      "name": "user-pii"
    }
  ],
  "encryption": {
    "encryptionType": "FPE",
    "encryptionKeyMode": "GLOBAL",
    "fpeEncryption": {
        "fpeFormats": [
          {
            "id": "$fpe_cc_id",
            "format": "fpe-cc",
            "datatype": "varchar"
          }
        ],
        "globalKey": {
          "kek": {
            "id": "$kek_id"
          },
          "dek": {
            "id": "$dek_id"
          }
        }
    }
  }
}
EOF
)
  echo "$ccn_access_dpp_body"
}

# Get ssn data protection with access policy body
get_ssn_access_dpp_body(){
  data_source_id=$1
  kek_id=$2
  dek_id=$3
  fpe_decimal_id=$4
  support_user_group_id=$5
  hr_user_group_id=$6

  ssn_access_dpp_body=$(cat <<EOF
{
  "name": "ssn-fpe-decimal-access",
  "dataSources": [
    {
      "id": "$data_source_id",
      "name": "user-pii"
    }
  ],
  "encryption": {
    "encryptionType": "FPE",
    "encryptionKeyMode": "GLOBAL",
    "fpeEncryption": {
        "fpeFormats": [
          {
            "id": "$fpe_decimal_id",
            "format": "fpe-decimal",
            "datatype": "varchar"
          }
        ],
        "globalKey": {
          "kek": {
            "id": "$kek_id"
          },
          "dek": {
            "id": "$dek_id"
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
           "id": "$support_user_group_id"
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
           "id": "$hr_user_group_id"
         },
         "permission": "READ",
         "masks": []
       }
     ]
   }
  }
}
EOF
)
  echo "$ssn_access_dpp_body"
}
# Get ccn data protection with access policy body
get_ccn_access_dpp_body(){
  data_source_id=$1
  kek_id=$2
  dek_id=$3
  fpe_cc_id=$4
  support_user_group_id=$5
  ccn_access_dpp_body=$(cat <<EOF
{
  "name": "ccn-fpe-cc-access",
  "dataSources": [
    {
      "id": "$data_source_id",
      "name": "user-pii"
    }
  ],
  "encryption": {
    "encryptionType": "FPE",
    "encryptionKeyMode": "GLOBAL",
    "fpeEncryption": {
        "fpeFormats": [
          {
            "id": "$fpe_cc_id",
            "format": "fpe-cc",
            "datatype": "varchar"
          }
        ],
        "globalKey": {
          "kek": {
            "id": "$kek_id"
          },
          "dek": {
            "id": "$dek_id"
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
           "id": "$support_user_group_id"
         },
         "permission": "MASK",
         "masks": [
           {
             "datatype": "varchar",
             "type": "PATTERN",
             "value": "XXXX-XXXX-XXXX-vvvv"
           }
         ]
       }
     ]
   }
  }
}
EOF
)
  echo "$ccn_access_dpp_body"
}

# Get DB Proxy Body
get_db_proxy_body(){
  name=$1
  database_id=$2
  aws_kms_id=$3
  kek_id=$4
  db_proxy_access_body=$(cat <<EOF
{
  "name": "$name",
  "database": {
    "id": "$database_id"
  },
  "keystore": {
    "id": "$aws_kms_id"
  },
  "kek": {
    "id": "$kek_id"
  },
  "encryption": true
}
EOF
)
  echo "$db_proxy_access_body"
}

# Get RBAC Body
get_rbac_port_change_body(){
  rbac_port_change_body=$(cat <<EOF
{
  "name": "RBAC-Port-change",
  "debugLevel": "NONE",
  "rbacConfig": {
    "mode": "SUPPORTED",
    "userDetermination": "SESSION",
    "enabled": true
  },
  "advancedConfig": {
     "baffleshield.clientPort": 5433
  }
}
EOF
)
  echo "$rbac_port_change_body"
}

# get Deployment Body
get_deploy_body(){
  name=$1
  ssn_access_dpp_id=$2
  ccn_access_dpp_id=$3
  deploy_body=$(cat <<EOF
{
  "name": "$name",
  "type": "DATA_POLICIES",
  "mode": "ADD_POLICIES",
  "dataPolicies": {
    "addedDataPolicies": [
      {
        "id": "$ssn_access_dpp_id"
      },
      {
        "id": "$ccn_access_dpp_id"
      }
    ]
  }
}
EOF
)
  echo "$deploy_body"
}

# Get system admin registration body
get_registration_body(){
  registration_body=$(cat <<EOF
{
 "initPassword":"baffle123",
 "orgName": "baffle",
 "allowedDomains": ["baffle.io"],
 "email": "$username",
 "firstName": "admin",
 "lastName": "t",
 "password": "$password"
}
EOF
)
  echo "$registration_body"
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

# Get Login Body
get_login_body(){
  login_body=$(cat <<EOF
{
  "password": "$password",
  "username": "$username"
}
EOF
)
  echo "$login_body"
}




start_postgres_proxy(){
  access_syncId=$1
  folder_path=$2
  port=$3
  # Change the current directory
  cd /home/ec2-user/$folder_path

  # Check if BM_DB_PROXY_SYNC_ID exists in .env file
  if grep -q "BM_DB_PROXY_SYNC_ID=" .env; then
    # If it exists, replace it
    sed -i "s/^BM_DB_PROXY_SYNC_ID=.*/BM_DB_PROXY_SYNC_ID=$access_syncId/" .env
  else
    # If it doesn't exist, add it
    echo "BM_DB_PROXY_SYNC_ID=$access_syncId" >> .env
  fi

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

start_bm(){
  # change the current directory
  cd /opt/baffle
  # Start the Baffle Manager service
  docker-compose up -d &
}

start_pg_admin(){
  # change the current directory
  cd /home/ec2-user/pg-admin
  # Create servers.json file
  servers_json=$(cat <<EOF
{
  "Servers": {
    "1": {
      "Name": "direct@baffle",
      "Group": "static-mask",
      "Host": "$db_host_name",
      "Port": 5432,
      "MaintenanceDB": "postgres",
      "Username": "$db_user_name",
      "PassFile": "/pgadmin4/pgpass",
      "role": "baffle"
    },
    "2": {
      "Name": "shield@baffle",
      "Group": "static-mask",
      "Host": "shield_static_mask",
      "Port": 5432,
      "MaintenanceDB": "postgres",
      "Username": "$db_user_name",
      "PassFile": "/pgadmin4/pgpass",
      "role": "baffle"
    },
    "3": {
      "Name": "direct@baffle",
      "Group": "dynamic-mask",
      "Host": "$db_host_name",
      "Port": 5432,
      "MaintenanceDB": "postgres",
      "Username": "$db_user_name",
      "PassFile": "/pgadmin4/pgpass",
      "role": "baffle"
    },
    "4": {
      "Name": "shield@baffle",
      "Group": "dynamic-mask",
      "Host": "shield_dynamic_mask",
      "Port": 5433,
      "MaintenanceDB": "postgres",
      "Username": "$db_user_name",
      "PassFile": "/pgadmin4/pgpass",
      "role": "baffle"
    },
   "5": {
     "Name": "Shield@harry_HR",
     "Group": "dynamic-mask",
     "Host": "shield_dynamic_mask",
     "Port": 5433,
     "MaintenanceDB": "postgres",
     "Username": "harry",
     "PassFile": "/pgadmin4/pgpass",
     "role": "baffle"
   },
   "6": {
      "Name": "Shield@sally_support",
      "Group": "dynamic-mask",
      "Host": "shield_dynamic_mask",
      "Port": 5433,
      "MaintenanceDB": "postgres",
      "Username": "sally",
      "PassFile": "/pgadmin4/pgpass",
      "role": "baffle"
  },
  "7": {
    "Name": "Shield@ron_remote",
    "Group": "dynamic-mask",
    "Host": "shield_dynamic_mask",
    "Port": 5433,
    "MaintenanceDB": "postgres",
    "Username": "ron",
    "PassFile": "/pgadmin4/pgpass",
    "role": "baffle"
  }
}
}
EOF
)
  echo  "Starting pgAdmin..." >&2
  # remove .env, servers.json and pgpass  files if they exist
  rm -f servers.json pgpass .env
  # create .env file with username and password
cat << EOF > .env
USERNAME=$username
PASSWORD=$password
EOF
  # create servers.json
  echo "$servers_json" > servers.json
  # create PassFile
cat << EOF > pgpass
$db_host_name:5432:*:$db_user_name:$db_password
shield:5432:*:$db_user_name:$db_password
shield:5433:*:$db_user_name:$db_password
shield:5433:*:harry:harry
shield:5433:*:sally:sally
shield:5433:*:ron:ron
EOF

  chmod 644 pgpass
  # Start pgAdmin
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
  database=$1
  command=$2
  error_message=$(PGPASSWORD=$db_password psql -v ON_ERROR_STOP=1 -h $db_host_name -p 5432 -U $db_user_name -d "$database" -c "$command" 2>&1)
  ssn_status_code=$?
  if [ $ssn_status_code -ne 0 ]; then
    echo "Error message: $error_message" >&2
    echo "error"
  else
    echo "success"
  fi
}
postgres_lower_env_db_creation() {
  # Database and table creation SQL commands
   echo "Creating databases and tables..." >&2
   prod_db_create_command="CREATE DATABASE sales;"
   enc_db_create_command="CREATE DATABASE sales_dev;"
   table_create_command="CREATE TABLE customers (
      uuid VARCHAR(40),
      first_name VARCHAR(50),
      ccn VARCHAR(50),
      ssn VARCHAR(50)

  );"
  alter_table_replica_full_identity="ALTER TABLE customers REPLICA IDENTITY FULL;"
  create_user_harry="CREATE USER harry PASSWORD 'harry';"
  create_user_sally="CREATE USER sally PASSWORD 'sally';"
  create_user_ron="CREATE USER ron WITH PASSWORD 'ron';"
  grant_usage_harry="GRANT USAGE ON SCHEMA public TO harry;"
  grant_select_harry="GRANT SELECT ON TABLE customers TO harry;"
  grant_usage_sally="GRANT USAGE ON SCHEMA public TO sally;"
  grant_select_sally="GRANT SELECT ON TABLE customers TO sally;"
  grant_usage_ron="GRANT USAGE ON SCHEMA public TO ron;"
  grant_select_ron="GRANT SELECT ON TABLE customers TO ron;"
  execution_status="success"
  # Execute the command for the 'postgres' database
  execution_status=$(execute_sql_command "postgres" "$prod_db_create_command")
  execution_status=$(execute_sql_command "postgres" "$enc_db_create_command")
  execution_status=$(execute_sql_command "sales" "$table_create_command")
  execution_status=$(execute_sql_command "sales" "$alter_table_replica_full_identity")
  execution_status=$(execute_sql_command "sales_dev" "$table_create_command")
  execution_status=$(execute_sql_command "sales_dev" "$create_user_harry")
  execution_status=$(execute_sql_command "sales_dev" "$create_user_sally")
  execution_status=$(execute_sql_command "sales_dev" "$create_user_ron")
  execution_status=$(execute_sql_command "sales_dev" "$grant_usage_harry")
  execution_status=$(execute_sql_command "sales_dev" "$grant_select_harry")
  execution_status=$(execute_sql_command "sales_dev" "$grant_usage_sally")
  execution_status=$(execute_sql_command "sales_dev" "$grant_select_sally")
  execution_status=$(execute_sql_command "sales_dev" "$grant_usage_ron")
  execution_status=$(execute_sql_command "sales_dev" "$grant_select_ron")
  # Check if all the commands were executed successfully
  if [ "$execution_status" == "success" ]; then
    echo "Database and table creation successful." >&2
    echo "success"
  else
    echo "Database and table creation failed." >&2
    echo "error"
  fi

}
# Start the Baffle Manager service
start_bm
# Check if the BM REST API service is up and running
status=$(check_application)
if [ "$status" == "error" ]; then
  echo "BM REST API service is not responding. Exiting script." >&2
  exit 1
fi

# Get Registration Body
registration_body=$(get_registration_body)
# Register the system admin
status=$(send_post_request "null" "$registration_url" "$registration_body")
if [ "$status" == "error" ]; then
  echo "System admin registration failed. Exiting script."  >&2
  exit 1
else
  echo "System admin registration successful." >&2
fi


# Get Login Body
login_body=$(get_login_body)
# Login as the system admin
jwt_token=$(send_post_request "null" "$login_url" "$login_body" "accessToken")
if [ "$jwt_token" == "error" ]; then
  echo "Login failed. Exiting script." >&2
  exit 1
else
  echo "JWT Token: $jwt_token" >&2
  echo "Login successful." >&2
fi

# Get AWS KMS Body
aws_kms_body=$(get_aws_kms_body)
# Enroll AWS KMS
aws_kms_id=$(send_post_request "$jwt_token" "$aws_kms_url" "$aws_kms_body" "id")
if [ "$aws_kms_id" == "error" ]; then
  echo "AWS KMS enrollment failed. Exiting script." >&2
  exit 1
else
  echo "AWS KMS ID: $aws_kms_id" >&2
fi

# Get KEK Body
kek_body=$(get_kek_body "$aws_kms_id")
# Enroll KEK
kek_id=$(send_post_request "$jwt_token" "$kek_url" "$kek_body" "id")
if [ "$kek_id" == "error" ]; then
  echo "KEK enrollment failed. Exiting script." >&2
  exit 1
else
  echo "KEK ID: $kek_id" >&2
fi

# Get DEK Body
dek_body=$(get_dek_body "$kek_id")
# Enroll DEK
dek_id=$(send_post_request "$jwt_token" "$kek_url/$kek_id/deks" "$dek_body" "id")
if [ "$dek_id" == "error" ]; then
  echo "DEK enrollment failed. Exiting script." >&2
  exit 1
else
  echo "DEK ID: $dek_id" >&2
fi


# Get Database Body
database_body=$(get_database_body)
# Enroll Database
database_id=$(send_post_request "$jwt_token" "$database_url" "$database_body" "id")
if [ "$database_id" == "error" ]; then
  echo "Database enrollment failed. Exiting script." >&2
  exit 1
else
  echo "Database ID: $database_id" >&2
fi


# Get SSN Data Source Body
ssn_ds_body=$(get_ssn_ds_body "$database_id")
# Enroll SSN data source
ssn_ds_id=$(send_post_request "$jwt_token" "$data_source_url" "$ssn_ds_body" "id")
if [ "$ssn_ds_id" == "error" ]; then
  echo "SSN Data Source enrollment failed. Exiting script." >&2
  exit 1
else
  echo "SSN Data Source ID: $ssn_ds_id" >&2
fi

# Get CCN Data Source Body
ccn_ds_body=$(get_ccn_ds_body "$database_id")
# Enroll CCN data source
ccn_ds_id=$(send_post_request "$jwt_token" "$data_source_url" "$ccn_ds_body" "id")
if [ "$ccn_ds_id" == "error" ]; then
  echo "CCN Data Source enrollment failed. Exiting script." >&2
  exit 1
else
  echo "CCN Data Source ID: $ccn_ds_id" >&2
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

# Get HR User Group Body
hr_user_group_body=$(get_user_group_body "human_resources" "harry")
# Enroll HR User Group
hr_user_group_id=$(send_post_request "$jwt_token" "$user_group_url" "$hr_user_group_body" "id")
if [ "$hr_user_group_id" == "error" ]; then
  echo "HR User Group enrollment failed. Exiting script." >&2
  exit 1
else
  echo "HR User Group ID: $hr_user_group_id" >&2
fi

# Get Support User Group Body
support_user_group_body=$(get_user_group_body "support" "sally")
# Enroll Support User Group
support_user_group_id=$(send_post_request "$jwt_token" "$user_group_url" "$support_user_group_body" "id")
if [ "$support_user_group_id" == "error" ]; then
  echo "Support User Group enrollment failed. Exiting script." >&2
  exit 1
else
  echo "Support User Group ID: $support_user_group_id" >&2
fi

# Get Remote User Group Body
remote_user_group_body=$(get_user_group_body "remote" "ron")
# Enroll Remote User Group
remote_user_group_id=$(send_post_request "$jwt_token" "$user_group_url" "$remote_user_group_body" "id")
if [ "$remote_user_group_id" == "error" ]; then
  echo "Remote User Group enrollment failed. Exiting script." >&2
  exit 1
else
  echo "Remote User Group ID: $remote_user_group_id"  >&2
fi

# Get SSN DPP Body
ssn_dpp_body=$(get_ssn_dpp_body "$ssn_ds_id" "$kek_id" "$dek_id" "$fpe_decimal_id" "$support_user_group_id" "$hr_user_group_id")
# Enroll SSN DPP
ssn_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$ssn_dpp_body" "id")
if [ "$ssn_dpp_id" == "error" ]; then
  echo "SSN DPP enrollment failed. Exiting script." >&2
  exit 1
else
  echo "SSN DPP ID: $ssn_dpp_id" >&2
fi

# Get CCN DPP Body
ccn_dpp_body=$(get_ccn_dpp_body "$ccn_ds_id" "$kek_id" "$dek_id" "$fpe_cc_id" "$support_user_group_id")
# Enroll CCN DPP
ccn_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$ccn_dpp_body" "id")
if [ "$ccn_dpp_id" == "error" ]; then
  echo "CCN DPP enrollment failed. Exiting script." >&2
  exit 1
else
  echo "CCN DPP ID: $ccn_dpp_id" >&2
fi

# Get SSN ACCESS DPP Body
ssn_access_dpp_body=$(get_ssn_access_dpp_body "$ssn_ds_id" "$kek_id" "$dek_id" "$fpe_decimal_id" "$support_user_group_id" "$hr_user_group_id")
# Enroll SSN ACCESS DPP
ssn_access_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$ssn_access_dpp_body" "id")
if [ "$ssn_access_dpp_id" == "error" ]; then
  echo "SSN_ACCESS DPP enrollment failed. Exiting script." >&2
  exit 1
else
  echo "SSN_ACCESS DPP ID: $ssn_access_dpp_id" >&2
fi

# Get CCN ACCESS DPP Body
ccn_access_dpp_body=$(get_ccn_access_dpp_body "$ccn_ds_id" "$kek_id" "$dek_id" "$fpe_cc_id" "$support_user_group_id")
# Enroll CCN ACCESS DPP
ccn_access_dpp_id=$(send_post_request "$jwt_token" "$dpp_url" "$ccn_access_dpp_body" "id")
if [ "$ccn_access_dpp_id" == "error" ]; then
  echo "CCN_ACCESS DPP enrollment failed. Exiting script." >&2
  exit 1
else
  echo "CCN_ACCESS DPP ID: $ccn_access_dpp_id" >&2
fi

db_proxy_static_mask_body=$(get_db_proxy_body "proxy_static_mask" "$database_id" "$aws_kms_id" "$kek_id")
# Enroll DB Proxy
read db_proxy_static_mask_id static_mask_syncId <<< $(send_post_request "$jwt_token" "$db_proxy_url" "$db_proxy_static_mask_body" "id" "syncId")
if [ "$db_proxy_static_mask_id" == "error" ]; then
  echo "DB Proxy enrollment failed. Exiting script." >&2
  exit 1
else
  echo "DB Proxy ID: $db_proxy_static_mask_id" >&2
  echo "Sync ID: $static_mask_syncId" >&2
fi

# Deploy DPP
deploy_enc_body=$(get_deploy_body "add_encryption_policies" "$ssn_dpp_id" "$ccn_dpp_id")
deployment_enc_id=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_static_mask_id/data-policies/deploy" "$deploy_enc_body" "id")
if [ "$deployment_enc_id" == "error" ]; then
  echo "Deployment failed. Exiting script." >&2
  exit 1
else
  echo "Deployment ID: $deployment_enc_id" >&2
fi

# Start Postgres Proxy
status=$(start_postgres_proxy "$static_mask_syncId" "Baffle-Shield-Postgresql-Static-Mask" 5432)
if [ "$status" == "error" ]; then
  echo "Postgres Proxy startup failed. Exiting script."
  exit 1
fi

# Get DB Proxy Body
db_proxy_access_body=$(get_db_proxy_body "proxy_dynamic_mask" "$database_id" "$aws_kms_id" "$kek_id")
# Enroll DB Proxy
read db_proxy_access_id access_syncId <<< $(send_post_request "$jwt_token" "$db_proxy_url" "$db_proxy_access_body" "id" "syncId")
if [ "$db_proxy_access_id" == "error" ]; then
  echo "DB Proxy enrollment failed. Exiting script." >&2
  exit 1
else
  echo "DB Proxy ID: $db_proxy_access_id" >&2
  echo "Sync ID: $access_syncId" >&2
fi

# Get RBAC and Port change Body
rbac_port_change_body=$(get_rbac_port_change_body)
# Enable RBAC
rbac_name=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_access_id/configurations" "$rbac_port_change_body" "name")
if [ "$rbac_name" == "error" ]; then
  echo "Enabling RBAC failed. Exiting script." >&2
  exit 1
else
  echo "Enabled RBAC" >&2
fi

# Get Deployment Body
deploy_body=$(get_deploy_body "add_encryption_access_policies" "$ssn_access_dpp_id" "$ccn_access_dpp_id")
# Deploy DPP
deployment_id=$(send_post_request "$jwt_token" "$db_proxy_url/$db_proxy_access_id/data-policies/deploy" "$deploy_body" "id")
if [ "$deployment_id" == "error" ]; then
  echo "Deployment failed. Exiting script." >&2
  exit 1
else
  echo "Deployment ID: $deployment_id" >&2
fi

# Start Postgres Proxy
status=$(start_postgres_proxy "$access_syncId" "Baffle-Shield-Postgresql-Dynamic-Mask" 5433)
if [ "$status" == "error" ]; then
  echo "Postgres Proxy startup failed. Exiting script."
  exit 1
fi

# create databases and tables
status=$(postgres_lower_env_db_creation)
if [ "$status" == "error" ]; then
  echo "Database and table creation failed. Exiting script."
  exit 1
fi
# Start the pgAdmin service
status=$(start_pg_admin)
if [ "$status" == "error" ]; then
  echo "PgAdmin startup failed. Exiting script."
  exit 1
fi
