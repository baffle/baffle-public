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
# Get DB Proxy List
get_db_proxy_list() {
  jwt_token=$1

  echo "Getting application list..."
  application_list=$(curl -k -s -w "\n%{http_code}" -X GET -H "Authorization: Bearer $jwt_token" "$db_proxy_url")

  # Extract the status code from the last line
  app_list_status_code=$(echo "$application_list" | tail -n1)

  # Remove the status code from the response
  application_list=$(echo "$application_list" | sed '$d')

  # Check if the status code is 200
  if [ "$app_list_status_code" -eq 200 ]; then
    echo "Application list retrieval successful. Application list: $application_list"
  else
    echo "Application list retrieval failed with status code: $app_list_status_code"
  fi
}
# Enroll Database
enroll_database() {
  jwt_token=$1
  database_body=$(cat <<EOF
{
  "name": "Postres",
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
  database_response=$(curl -k -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $jwt_token" -d "$database_body" "$database_url")

  # Extract the status code from the last line
  status_code=$(echo "$database_response" | tail -n1)

  # Remove the status code from the response
  database_response=$(echo "$database_response" | sed '$d')

  # Check if the status code is 200
  if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 201 ]; then
    echo "Database enrollment successful." >&2
    # Parse the id from the response
    database_id=$(echo "$database_response" | jq -r '.id')
    echo "Database ID: $database_id"  >&2
    echo "$database_id"
  else
    echo "Database enrollment failed with status code: $status_code" >&2
    echo "error"
  fi

}
# Enroll AWS KMS
enroll_aws_kms(){
   jwt_token=$1
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
    aws_kms_response=$(curl -k -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $jwt_token" -d "$aws_kms_body" "$aws_kms_url")

    # Extract the status code from the last line
    status_code=$(echo "$aws_kms_response" | tail -n1)

    # Remove the status code from the response
    aws_kms_response=$(echo "$aws_kms_response" | sed '$d')

    # Check if the status code is 200
    if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 201 ]; then
      echo "AWS KMS enrollment successful." >&2
      # Parse the id from the response
      aws_kms_id=$(echo "$aws_kms_response" | jq -r '.id')
      echo "AWS KMS ID: $aws_kms_id" >&2
      echo "$aws_kms_id"
    else
      echo "AWS KMS enrollment failed with status code: $status_code" >&2
      echo "error"
    fi
}
# Enroll KEK
enroll_kek() {
    jwt_token=$1
    kestore_id=$2
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
    kek_response=$(curl -k -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $jwt_token" -d "$kek_body" "$kek_url")

    # Extract the status code from the last line
    status_code=$(echo "$kek_response" | tail -n1)

    # Remove the status code from the response
    kek_response=$(echo "$kek_response" | sed '$d')

    # Check if the status code is 200
    if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 201 ] ; then
      echo "KEK enrollment successful." >&2
      # Parse the id from the response
      kek_id=$(echo "$kek_response" | jq -r '.id')
      echo "KEK ID: $kek_id" >&2
      echo $kek_id
    else
      echo "KEK enrollment failed with status code: $status_code" >&2
      echo "error"
    fi
}
# Enroll DEK
enroll_dek(){
  jwt_token=$1
  kek_id=$2
  random_number=$((RANDOM % 100 + 1)) # Generate a random number between 1 and 100
  dek_body=$(cat <<EOF
{
  "name": "baffle-dek-$random_number",
  "kek": {
    "id": "$kek_id"
  }
}
EOF
)
  dek_response=$(curl -k -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $jwt_token" -d "$dek_body" "$kek_url/$kek_id/deks")

  # Extract the status code from the last line
  status_code=$(echo "$dek_response" | tail -n1)

  # Remove the status code from the response
  dek_response=$(echo "$dek_response" | sed '$d')

  # Check if the status code is 200
  if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 201 ]; then
    echo "DEK enrollment successful." >&2
    # Parse the id from the response
    dek_id=$(echo "$dek_response" | jq -r '.id')
    echo "DEK ID: $dek_id" >&2
    echo "$dek_id"
  else
    echo "DEK enrollment failed with status code: $status_code" >&2
    echo "error"
  fi
}
# Enroll Data Source
enroll_data_source(){
  jwt_token=$1
  database_id=$2
  data_source_body=$(cat <<EOF
{
  "name": "customer-ssn",
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
  },
  "jsonFields": []
}
EOF
)
  data_source_response=$(curl -k -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $jwt_token" -d "$data_source_body" "$data_source_url")

  # Extract the status code from the last line
  status_code=$(echo "$data_source_response" | tail -n1)

  # Remove the status code from the response
  data_source_response=$(echo "$data_source_response" | sed '$d')

  # Check if the status code is 200
  if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 201 ]; then
    echo "Data source enrollment successful." >&2
    # Parse the id from the response
    data_source_id=$(echo "$data_source_response" | jq -r '.id')
    echo "Data source ID: $data_source_id"  >&2
    echo "$data_source_id"
  else
    echo "Data source enrollment failed with status code: $status_code" >&2
    echo "error"
  fi
}

# Get FPE Decimal Policy
get_fpe_decimal_policy() {
  jwt_token=$1
  # get fpe_decimal_id
  fpe_decimal_response=$(curl -k -s -w "\n%{http_code}" -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $jwt_token" "$fpe_decimal_url")
    # Extract the status code from the last line
  status_code=$(echo "$fpe_decimal_response" | tail -n1)

  # Remove the status code from the response
  fpe_decimal_response=$(echo "$fpe_decimal_response" | sed '$d')

  # Check if the status code is 200
  if [ "$status_code" -eq 200 ]; then
    echo "FPE Decimal retrieval successful." >&2
    # Parse the id from the response
    fpe_decimal_id=$(echo "$fpe_decimal_response" | jq -r '.id')
    echo "FPE Decimal ID: $fpe_decimal_id" >&2
    echo "$fpe_decimal_id"
  else
    echo "FPE Decimal retrieval failed with status code: $status_code" >&2
    echo "error"
  fi
}

enroll_dpp(){
  jwt_token=$1
  data_source_id=$2
  kek_id=$3
  dek_id=$4
  fpe_decimal_id=$5
  dpp_body=$(cat <<EOF
{
  "name": "ssn-fpe-policy",
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
  dpp_response=$(curl -k -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $jwt_token" -d "$dpp_body" "$dpp_url")

  # Extract the status code from the last line
  status_code=$(echo "$dpp_response" | tail -n1)

  # Remove the status code from the response
  dpp_response=$(echo "$dpp_response" | sed '$d')

  # Check if the status code is 200
  if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 201 ]; then
    echo "DPP enrollment successful." >&2
    # Parse the id from the response
    dpp_id=$(echo "$dpp_response" | jq -r '.id')
    echo "DPP ID: $dpp_id" >&2
    echo "$dpp_id"
  else
    echo "DPP enrollment failed with status code: $status_code" >&2
    echo "error"
  fi
}

enroll_db_proxy(){
  jwt_token=$1
  database_id=$2
  aws_kms_id=$3
  kek_id=$4
  db_proxy_body=$(cat <<EOF
{
  "name": "db-proxy-postgres",
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
  db_proxy_response=$(curl -k -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $jwt_token" -d "$db_proxy_body" "$db_proxy_url")

  # Extract the status code from the last line
  status_code=$(echo "$db_proxy_response" | tail -n1)

  # Remove the status code from the response
  db_proxy_response=$(echo "$db_proxy_response" | sed '$d')

  # Check if the status code is 200
  if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 201 ]; then
    echo "DB Proxy enrollment successful." >&2
    # Parse the id from the response
    db_proxy_id=$(echo "$db_proxy_response" | jq -r '.id')
    syncId=$(echo "$db_proxy_response" | jq -r '.syncId')
    echo "DB Proxy ID: $db_proxy_id" >&2
    echo "Sync ID: $syncId" >&2
    echo "$db_proxy_id $syncId"
  else
    echo "DB Proxy enrollment failed with status code: $status_code" >&2
    echo "error"
  fi
}

deploy_dpp(){
  jwt_token=$1
  db_proxy_id=$2
  dpp_id=$3
  deploy_body=$(cat <<EOF
{
  "name": "deploy-1",
  "type": "DATA_POLICIES",
  "mode": "ADD_POLICIES",
  "dataPolicies": {
    "addedDataPolicies": [
      {
        "id": "$dpp_id"
      }
    ]
  }
}
EOF
)
  deploy_response=$(curl -k -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $jwt_token" -d "$deploy_body" "$db_proxy_url/$db_proxy_id/data-policies/deploy")

  # Extract the status code from the last line
  status_code=$(echo "$deploy_response" | tail -n1)

  # Remove the status code from the response
  deploy_response=$(echo "$deploy_response" | sed '$d')

  # Check if the status code is 200
  if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 201 ]; then
    echo "Deployment successful." >&2
    # Parse the id from the response
    deployment_id=$(echo "$deploy_response" | jq -r '.id')
    echo "Deployment ID: $deployment_id" >&2
    echo "$deployment_id"
  else
    echo "Deployment failed with status code: $status_code" >&2
    echo "error"
  fi
}

check_application(){
  # Counter for the number of retries
  counter=0
  while [ $counter -lt 10 ]; do
    # Send a request to the REST API endpoint and store the HTTP status code
    status_code=$(curl -k --write-out "%{http_code}\n" --silent --output /dev/null "$checkAppUrl")
    # If the HTTP status code is 200, print a success message and exit the loop
    if [ "$status_code" -eq 200 ]; then
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

sys_admin_registration(){
  # Registration API
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
  registration_response=$(curl -k -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -d "$registration_body" "$registration_url")

  # Extract the status code from the last line
  status_code=$(echo "$registration_response" | tail -n1)

  # Remove the status code from the response
  registration_response=$(echo "$registration_response" | sed '$d')

  # Check if the status code is 200
  if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 201 ] || [ "$status_code" -eq 204 ]; then
    echo "Registration successful." >&2
    echo "success"
  else
    echo "Login failed with status code: $status_code" >&2
    echo "error"
  fi

}
# Login API
login_api() {

  login_body=$(cat <<EOF
{
  "password": "$password",
  "username": "$username"
}
EOF
)
  login_response=$(curl -k -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" -d "$login_body" "$login_url")

  # Extract the status code from the last line
  status_code=$(echo "$login_response" | tail -n1)

  # Remove the status code from the response
  login_response=$(echo "$login_response" | sed '$d')

  # Check if the status code is 200
  if [ "$status_code" -ne 200 ]; then
    echo "Login failed with status code: $status_code" >&2
    echo "error"
  fi
  # Parse the JWT token from the response
  jwt_token=$(echo "$login_response" | jq -r '.accessToken')
  echo "Login successful." >&2
  echo "$jwt_token"
}

start_postgres_proxy(){
  syncId=$1
  # Change the current directory
  cd /home/ec2-user/Baffle-Shield-Postgresql-Docker-Deploy

  # Check if BM_DB_PROXY_SYNC_ID exists in .env file
  if grep -q "BM_DB_PROXY_SYNC_ID=" .env; then
    # If it exists, replace it
    sed -i "s/^BM_DB_PROXY_SYNC_ID=.*/BM_DB_PROXY_SYNC_ID=$syncId/" .env
  else
    # If it doesn't exist, add it
    echo "BM_DB_PROXY_SYNC_ID=$syncId" >> .env
  fi

  echo "Starting Postgres Proxy Service..." >&2
  # Run docker compose
  docker-compose up -d &

  # Check if port 5432 is open
  counter=0
  while ! netstat -tuln | grep 5432 && [ $counter -lt 10 ]; do
    echo "Port 5432 is not open. Retrying in 30 seconds..." >&2
    sleep 30
    ((counter++))
  done

  if netstat -tuln | grep 5432; then
    echo "Port 5432 is open. Postgres Proxy Service is up and running." >&2
    echo "success"
  elif [ $counter -eq 10 ]; then
    echo "Port 5432 is not open after 5 minutes. Exiting script." >&2
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
      "Name": "Direct_Connection_Postgres_RDS",
      "Group": "lower-env-use-case",
      "Host": "$db_host_name",
      "Port": 5432,
      "MaintenanceDB": "postgres",
      "Username": "$db_user_name",
      "PassFile": "/pgadmin4/pgpass",
      "role": "baffle"
    },
    "2": {
      "Name": "Shield_Connection_Postgres_RDS",
      "Group": "lower-env-use-case",
      "Host": "shield",
      "Port": 5432,
      "MaintenanceDB": "postgres",
      "Username": "$db_user_name",
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
  echo "USERNAME=$username" > .env
  echo "PASSWORD=$password" >> .env
  # create servers.json
  echo "$servers_json" > servers.json
  # create PassFile
  echo "$db_host_name:5432:*:$db_user_name:$db_password" > pgpass
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

postgres_lower_env_db_creation() {
  # Database and table creation SQL commands
   echo "Creating databases and tables..." >&2
   prod_db_create_command="CREATE DATABASE sales;"
   enc_db_create_command="CREATE DATABASE sales_dev;"
   table_create_command="CREATE TABLE customers (
      customer_id SERIAL,
      first_name VARCHAR(50) NOT NULL,
      last_name VARCHAR(50) NOT NULL,
      age INT,
      email VARCHAR(100),
      country VARCHAR(100),
      postal_code VARCHAR(20),
      gender VARCHAR(50),
      ssn VARCHAR(20),
      birthdate DATE,
      entity_id VARCHAR(20) NOT NULL
  );"
  execution="success"
  # Execute the command for the 'postgres' database
  error_message=$(PGPASSWORD=$db_password psql -v ON_ERROR_STOP=1 -h $db_host_name -p 5432 -U $db_user_name -d postgres -c "$prod_db_create_command" 2>&1)
  status_code=$?
  if [ $status_code -ne 0 ]; then
    echo "Error message: $error_message" >&2
    echo "error"
  fi

  error_message=$(PGPASSWORD=$db_password psql -v ON_ERROR_STOP=1 -h $db_host_name -p 5432 -U $db_user_name -d postgres -c "$enc_db_create_command" 2>&1)
  status_code=$?
  if [ $status_code -ne 0 ]; then
    echo "Error message: $error_message" >&2
    echo "error"
  fi

  # Execute the command for the 'sales' database
  error_message=$(PGPASSWORD=$db_password psql -v ON_ERROR_STOP=1 -h $db_host_name -p 5432 -U $db_user_name -d sales -c "$table_create_command" 2>&1)
  status_code=$?
  if [ $status_code -ne 0 ]; then
    echo -e "Error message: $error_message"  >&2
    execution="error"
  fi

  # Execute the command for the 'sales_dev' database
  error_message=$(PGPASSWORD=$db_password psql -v ON_ERROR_STOP=1 -h $db_host_name -p 5432 -U $db_user_name -d sales_dev -c "$table_create_command" 2>&1)
  status_code=$?
  if [ $status_code -ne 0 ]; then
    echo -e "Error message: $error_message" >&2
    execution="error"
  fi

  # Check if all the commands were executed successfully
  if [ "$execution" == "success" ]; then
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
  echo "BM REST API service is not responding. Exiting script."
  exit 1
fi
# Register as a system admin
status=$(sys_admin_registration)
if [ "$status" == "error" ]; then
  echo "Registration failed. Exiting script."
  exit 1
fi

# Login
jwt_token=$(login_api)
if [ "$jwt_token" == "error" ]; then
  echo "Login failed. Exiting script."
  exit 1
fi


# Enroll AWS KMS
aws_kms_id=$(enroll_aws_kms $jwt_token)
# Check if the enrollment was successful before enrolling KEK
if [ "$aws_kms_id" == "error" ]; then
  echo "AWS KMS enrollment failed. Exiting script."
  exit 1
fi
# Enroll KEK
kek_id=$(enroll_kek $jwt_token $aws_kms_id)
if [ "$kek_id" == "error" ]; then
  echo "KEK enrollment failed. Exiting script."
  exit 1
fi

# Enroll DEK
dek_id=$(enroll_dek $jwt_token $kek_id)
if [ "$dek_id" == "error" ]; then
  echo "DEK enrollment failed. Exiting script."
  exit 1
fi

# Enroll Database
database_id=$(enroll_database $jwt_token)
if [ "$database_id" == "error" ]; then
  echo "Database enrollment failed. Exiting script."
  exit 1
fi

# Enroll Data Source
data_source_id=$(enroll_data_source $jwt_token $database_id)
if [ "$data_source_id" == "error" ]; then
  echo "Data source enrollment failed. Exiting script."
  exit 1
fi

# Get FPE Decimal Policy
fpe_decimal_id=$(get_fpe_decimal_policy $jwt_token)
if [ "$fpe_decimal_id" == "error" ]; then
  echo "FPE Decimal retrieval failed. Exiting script."
  exit 1
fi
# Enroll DPP
dpp_id=$(enroll_dpp $jwt_token $data_source_id $kek_id $dek_id $fpe_decimal_id)
if [ "$dpp_id" == "error" ]; then
  echo "DPP enrollment failed. Exiting script."
  exit 1
fi

# Enroll DB Proxy
read db_proxy_id syncId <<< $(enroll_db_proxy $jwt_token $database_id $aws_kms_id $kek_id)
if [ "$db_proxy_id" == "error" ]; then
  echo "DB Proxy enrollment failed. Exiting script."
  exit 1
fi

# Deploy DPP
deployment_id=$(deploy_dpp $jwt_token $db_proxy_id $dpp_id)
if [ "$deployment_id" == "error" ]; then
  echo "Deployment failed. Exiting script."
  exit 1
fi

# Start Postgres Proxy
status=$(start_postgres_proxy $syncId)
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
