# Baffle Data Protection API

This project contains a Cloudformation Template for setting up a Baffle Shield  Baffle Data Protection API

## Prerequisites:
* S3 Bucket to be protected
* AWS CLI installed and configured
* Permissions necessary to run CloudFormation and to create resources referenced in the template

## Steps:

### 1. Stack Creation:

* Run the below command with the parameters or use these parameters on the AWS Console:
* MyIP: IP of the user machine
* UserEmail: User Email for Baffle Manager and Pg Admin UI
* UserPassword: Password to log into Baffle Manager and Pg Admin UI
* Workflow: Standard ot BYOK

`aws cloudformation create-stack --stack-name api-cle --template-body file://create_baffle_api_service_template.yaml --capabilities CAPABILITY_NAMED_IAM --parameters ParameterKey=MyIP,ParameterValue=$(curl -s http://checkip.amazonaws.com/) ParameterKey=Workflow,ParameterValue=Standard ParameterKey=UserEmail,ParameterValue=admin@baffle.io ParameterKey=UserPassword,ParameterValue=Baffle-2024`

Once the template creates the stack it will output some value. The following are important
1. BaffleEC2SecurityGroup -  The Security Group that white list user IP
2. BaffleManagerURL - The URL for Baffle Manager
3. StackRegion	- The region where stack is deployed
4. DataProxyHealthCheck - The URL for Data Proxy health check
5. DataProxyURL - The URL for Data Proxy
6. DataProxyS3Bucket - The bucket where to store data. 


#### * if the stack needed to be created on specific region and with specific profile, following needs to be passed on aws command
1. --region
2. --profile

For example:
`aws --region us-east-1 --profile other-profile cloudformation create-stack --stack-name api-cle --template-body file://create_baffle_api_service_template.yaml --capabilities CAPABILITY_NAMED_IAM --parameters ParameterKey=MyIP,ParameterValue=$(curl -s http://checkip.amazonaws.com/) ParameterKey=Workflow,ParameterValue=Standard ParameterKey=UserEmail,ParameterValue=admin@baffle.io ParameterKey=UserPassword,ParameterValue=Baffle-2024`


## Download keypair 
The keypair for Baffle EC2 instance is stored on SSM and can be downloaded. Following link describes a process of downloading link 
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#create-key-pair-cloudformation


## 2. Testing the Data Proxy

Once the Data Proxy creation is up. Please log into Baffle Manager, check the Data Proxy cluster instance tab and check config are sync.

Please use the curl command to check the status (update the hostname with your host )

`curl -s -k https://{hostname}:8444/dataproxy/status`

### Standard Encryption

 All the file used are provided on the files directory. bucket is DataProxyS3Bucket from stack output and IP is the ip of the EC2 instances.

#### Full file

1. Upload a file
```bash
aws s3 cp kia.txt s3://bucket/kia.txt --endpoint-url=https://IP:8444 --no-verify-ssl
```
2. Download a file and verify it is encrypted (AWS CLI installed and configured with permission to get the file)
```bash
aws s3 cp s3://bucket/kia.txt  downloaded_enc_kia.txt 
```
3. Download a file and verify it can be  decrypted 
```bash
aws s3 cp s3://bucket/kia.txt  downloaded_kia.txt --endpoint-url=https://IP:8444 --no-verify-ssl
```
#### Field level file

1. Upload a csv
```bash
aws s3 cp customers.csv s3://bucket/customers.csv --endpoint-url=https://IP:8444 --no-verify-ssl
```

2. Download a csv and verify ccn field is encrypted (AWS CLI installed and configured with permission to get the file)
```bash
aws s3 cp s3://bucket/customers.csv  downloaded_enc_customers.csv
```
3. Download a csv and verify ccn field is decrypted
```bash
aws s3 cp s3://bucket/customers.csv  downloaded_customers.csv --endpoint-url=https://IP:8444 --no-verify-ssl
```

4. Upload a json
```bash
aws s3 cp john.json s3://bucket/john.json --endpoint-url=https://IP:8444 --no-verify-ssl
```

5. Download a json and verify ccn field is encrypted (AWS CLI installed and configured with permission to get the file)
```bash
aws s3 cp s3://bucket/john.json  downloaded_enc_john.json 
```

6. Download a csv and verify ccn field is decrypted
```bash
aws s3 cp s3://bucket/john.json  downloaded_john.json  --endpoint-url=https://IP:8444 --no-verify-ssl
```

### BYOK

#### Full file

1. Upload a file for Tenant T-1001
```bash
aws s3 cp kia.txt s3://bucket/T-1001-kia.txt  --endpoint-url=https://IP:8444 --no-verify-ssl
```

2. Upload a file for Tenant T-2002
```bash
aws s3 cp kia.txt s3://bucket/T-2002-kia.txt  --endpoint-url=https://IP:8444 --no-verify-ssl
```

3. Download  encrypted file for tenant T-1001 (AWS CLI installed and configured with permission to get the file)
```bash
aws s3 s3://bucket/T-1001-kia.txt enc-T-1001-kia.txt
```

4. Download  encrypted file for tenant T-2002 and verify files are different  (AWS CLI installed and configured with permission to get the file)
```bash
aws s3 cp s3://bucket/T-2002-kia.txt enc-T-2002-kia.txt
```

5. Download  decrypted file for tenant T-1001
```bash
aws s3 s3://bucket/T-1001-kia.txt T-1001-kia.txt --endpoint-url=https://IP:8444 --no-verify-ssl
```

6. Download decrypted file for tenant T-2002
```bash
aws s3 cp s3://bucket/T-2002-kia.txt T-2002-kia.txt --endpoint-url=https://IP:8444 --no-verify-ssl
```

#### Field level file

1. Upload a csv file for Tenant T-1001
```bash
aws s3 cp customers.csv  s3://bucket/T-1001-customers.csv   --endpoint-url=https://IP:8444 --no-verify-ssl
```

2. Upload a csv file for Tenant T-2002
```bash
aws s3 cp customers.csv  s3://bucket/T-2002-customers.csv   --endpoint-url=https://IP:8444 --no-verify-ssl
```

3. Download encrypted  csv file for tenant T-1001 and verify ccn field is encrypted (AWS CLI installed and configured with permission to get the file)
```bash
aws s3 s3://bucket/T-1001-customers.csv  enc-T-1001-customers.csv 
```

4. Download encrypted  csv file for tenant T-1001 and verify ccn field is encrypted with different key (AWS CLI installed and configured with permission to get the file)
```bash
aws s3 cp s3://bucket/T-2002-customers.csv  enc-T-2002-customers.csv 
```

5. Download decrypted file for tenant T-1001 and verify ccn 
```bash
aws s3 s3://bucket/T-1001-customers.csv  T-1001-customers.csv  --endpoint-url=https://IP:8444 --no-verify-ssl
```

6. Download decrypted file for tenant T-2002 and verify ccn
```bash
aws s3 cp s3://bucket/T-2002-customers.csv  T-2002-customers.csv  --endpoint-url=https://IP:8444 --no-verify-ssl
```

7. Upload a json file for Tenant T-1001 
```bash
aws s3 cp john.json  s3://bucket/T-1001-john.json   --endpoint-url=https://IP:8444 --no-verify-ssl
```

8. Upload a json file for Tenant T-2002
```bash
aws s3 cp john.json  s3://bucket/T-2002-john.json   --endpoint-url=https://IP:8444 --no-verify-ssl
```

9. Download encrypted  json file for tenant T-1001 and verify ccn field is encrypted (AWS CLI installed and configured with permission to get the file)
```bash
aws s3 s3://bucket/T-1001-john.json  enc-T-1001-john.json 
```

10. Download encrypted  json file for tenant T-1001 and verify ccn field is encrypted with different key (AWS CLI installed and configured with permission to get the file)
```bash
aws s3 cp s3://bucket/T-2002-john.json  enc-T-2002-john.json 
```

11. Download decrypted file for tenant T-1001 and verify ccn
```bash
aws s3 s3://bucket/T-1001-john.json  T-1001-john.json  --endpoint-url=https://IP:8444 --no-verify-ssl
```

12. Download decrypted file for tenant T-2002 and verify ccn
```bash
aws s3 cp s3://bucket/T-2002-john.json  T-2002-john.json  --endpoint-url=https://IP:8444 --no-verify-ssl
```

### 3. Swagger:

The Swagger UI can be found at 
``
https://{hostname}:8444/swagger-ui/index.html``
