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
* S3BucketName: Name of S3 Bucket to be store protected data
* UserEmail: User Email for Baffle Manager and Pg Admin UI
* UserPassword: Password to log into Baffle Manager and Pg Admin UI
* Workflow: Standard ot BYOK

`aws cloudformation create-stack --stack-name api-cle --template-body file://create_baffle_api_service_template.yaml --capabilities CAPABILITY_NAMED_IAM --parameters ParameterKey=S3BucketName,ParameterValue=data-proxy ParameterKey=MyIP,ParameterValue=$(curl -s http://checkip.amazonaws.com/) ParameterKey=Workflow,ParameterValue=Standard ParameterKey=UserEmail,ParameterValue=admin@baffle.io ParameterKey=UserPassword,ParameterValue=Baffle-2024`

Once the template creates the stack it will output some value. The following are important
1. BaffleEC2SecurityGroup -  The Security Group that white list user IP
2. BaffleManagerURL - The URL for Baffle Manager
3. StackRegion	- The region where stack is deployed
4. DataProxyHealthCheck - The URL for for Data Proxy health check
5. DataProxyURL - The URL for Data Proxy


#### * if the stack needed to be created on specific region and with specific profile, following needs to be passed on aws command
1. --region
2. --profile

For example:
`aws --region us-east-1 --profile other-profile cloudformation create-stack --stack-name api-cle --template-body file://create_baffle_api_service_template.yaml --capabilities CAPABILITY_NAMED_IAM --parameters ParameterKey=S3BucketName,ParameterValue=data-proxy ParameterKey=MyIP,ParameterValue=$(curl -s http://checkip.amazonaws.com/) ParameterKey=Workflow,ParameterValue=Standard ParameterKey=UserEmail,ParameterValue=admin@baffle.io ParameterKey=UserPassword,ParameterValue=Baffle-2024`


## Download keypair 
The keypair for Baffle EC2 instance is stored on SSM and can be downloaded. Following link describes a process of downloading link 
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#create-key-pair-cloudformation


## 2. Testing the Data Proxy

Once the Data Proxy creation is up. Please log into Baffle Manager, check the API cluster instance tab and check config are sync.

Please use the curl command to check the status (update the hostname with your host )

`curl -s -k https://{hostname}:8444/dataproxy/status`


Since, the JWT is configured. Below are 3 tokens that will be helpful 

1. encrypt-decrypt role -> `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE0MTYwLjY5ODQ1NiwiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZW5jcnlwdC1kZWNyeXB0Il19.WvO027v6qbIh26berMrtVd9bGsbEpcxteEt5Vryic0c`
2. encrypt role -> `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE1MTIxLjA2ODYyMywiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZW5jcnlwdCJdfQ.77aDWccA7ReGXN5xTnK6Ogk0MBwZ8AuKnGc8NyufTws`
3. decrypt role -> `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE1MTY5LjY1NjEzNiwiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZGVjcnlwdCJdfQ.WfEXqH1ufh_7Z-FDuD1_RUXzlADTHe_skbOAzOKshEE`


### Standard Encryption

 All the file used are provided on

#### Full file

1. Upload with encrypt role -> success
```bash
curl -i -k  -H 'Authorization:Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE1MTIxLjA2ODYyMywiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZW5jcnlwdCJdfQ.77aDWccA7ReGXN5xTnK6Ogk0MBwZ8AuKnGc8NyufTws' \
--upload-file bill.txt 'https://{hostname}:8444/api/filesvc/write/bill.txt'
```

2. Upload with decrypt role -> error
```bash
curl -i -k  -H 'Authorization:Bearer Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE1MTY5LjY1NjEzNiwiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZGVjcnlwdCJdfQ.WfEXqH1ufh_7Z-FDuD1_RUXzlADTHe_skbOAzOKshEE' \
--upload-file bill.txt 'https://{hostname}:8444/api/filesvc/write/bill.txt'
```

3. Download with decrypt role -> success
```bash
curl -s -k  -H 'Authorization:Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE1MTY5LjY1NjEzNiwiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZGVjcnlwdCJdfQ.WfEXqH1ufh_7Z-FDuD1_RUXzlADTHe_skbOAzOKshEE' \
'https://{hostname}:8444/api/filesvc/read/bill.txt'  -o download-bill.txt
```

4. Decrypt with encrypt-decrypt role -> success
```bash
curl -s -k  -H 'Authorization:Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE0MTYwLjY5ODQ1NiwiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZW5jcnlwdC1kZWNyeXB0Il19.WvO027v6qbIh26berMrtVd9bGsbEpcxteEt5Vryic0c' \
'https://{hostname}:8444/api/filesvc/read/bill.txt'  -o download-bill.txt
```

#### Field level file

1. Upload with encrypt role -> success
```bash
curl -i -k  -H 'Authorization:Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE1MTIxLjA2ODYyMywiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZW5jcnlwdCJdfQ.77aDWccA7ReGXN5xTnK6Ogk0MBwZ8AuKnGc8NyufTws' \
--upload-file employee.csv 'https://{hostname}:8444/api/filesvc/write/employee.csv'
```

2. Upload with decrypt role -> error
```bash
curl -i -k  -H 'Authorization:Bearer Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE1MTY5LjY1NjEzNiwiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZGVjcnlwdCJdfQ.WfEXqH1ufh_7Z-FDuD1_RUXzlADTHe_skbOAzOKshEE' \
--upload-file employee.csv 'https://{hostname}:8444/api/filesvc/write/employee.csv'
```

3. Download with decrypt role -> success
```bash
curl -s -k  -H 'Authorization:Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE1MTY5LjY1NjEzNiwiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZGVjcnlwdCJdfQ.WfEXqH1ufh_7Z-FDuD1_RUXzlADTHe_skbOAzOKshEE' \
'https://{hostname}:8444/api/filesvc/read/employee.csv'  -o download-employee.csv
```

4. Decrypt with encrypt-decrypt role -> success
```bash
curl -s -k  -H 'Authorization:Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE0MTYwLjY5ODQ1NiwiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZW5jcnlwdC1kZWNyeXB0Il19.WvO027v6qbIh26berMrtVd9bGsbEpcxteEt5Vryic0c' \
'https://{hostname}:8444/api/filesvc/read/employee.csv'  -o download-employee.csv
```


### BYOK

#### Full file

1. Upload with encrypt role -> success
```bash
curl -i -k  -H 'x-baffle-tenant: T-1001' -H 'Authorization:Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE1MTIxLjA2ODYyMywiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZW5jcnlwdCJdfQ.77aDWccA7ReGXN5xTnK6Ogk0MBwZ8AuKnGc8NyufTws' \
--upload-file bill.txt 'https://{hostname}:8444/api/filesvc/write/bill.txt'
```

2. Upload with decrypt role -> error
```bash
curl -i -k -H 'x-baffle-tenant: T-1001' -H 'Authorization:Bearer Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE1MTY5LjY1NjEzNiwiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZGVjcnlwdCJdfQ.WfEXqH1ufh_7Z-FDuD1_RUXzlADTHe_skbOAzOKshEE' \
--upload-file bill.txt 'https://{hostname}:8444/api/filesvc/write/bill.txt'
```

3. Download with decrypt role -> success
```bash
curl -s -k -H 'x-baffle-tenant: T-1001' -H 'Authorization:Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE1MTY5LjY1NjEzNiwiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZGVjcnlwdCJdfQ.WfEXqH1ufh_7Z-FDuD1_RUXzlADTHe_skbOAzOKshEE' \
'https://{hostname}:8444/api/filesvc/read/bill.txt'  -o download-bill.txt
```

4. Decrypt with encrypt-decrypt role -> success
```bash
curl -s -k -H 'x-baffle-tenant: T-1001' -H 'Authorization:Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE0MTYwLjY5ODQ1NiwiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZW5jcnlwdC1kZWNyeXB0Il19.WvO027v6qbIh26berMrtVd9bGsbEpcxteEt5Vryic0c' \
'https://{hostname}:8444/api/filesvc/read/bill.txt'  -o download-bill.txt
```

#### Field level file

1. Upload with encrypt role -> success
```bash
curl -i -k -H 'x-baffle-tenant: T-1001' -H 'Authorization:Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE1MTIxLjA2ODYyMywiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZW5jcnlwdCJdfQ.77aDWccA7ReGXN5xTnK6Ogk0MBwZ8AuKnGc8NyufTws' \
--upload-file employee.csv 'https://{hostname}:8444/api/filesvc/write/employee.csv'
```

2. Upload with decrypt role -> error
```bash
curl -i -k  -H 'x-baffle-tenant: T-1001' -H 'Authorization:Bearer Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE1MTY5LjY1NjEzNiwiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZGVjcnlwdCJdfQ.WfEXqH1ufh_7Z-FDuD1_RUXzlADTHe_skbOAzOKshEE' \
--upload-file employee.csv 'https://{hostname}:8444/api/filesvc/write/employee.csv'
```

3. Download with decrypt role -> success
```bash
curl -s -k -H 'x-baffle-tenant: T-1001'  -H 'Authorization:Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE1MTY5LjY1NjEzNiwiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZGVjcnlwdCJdfQ.WfEXqH1ufh_7Z-FDuD1_RUXzlADTHe_skbOAzOKshEE' \
'https://{hostname}:8444/api/filesvc/read/employee.csv'  -o download-employee.csv
```

4. Decrypt with encrypt-decrypt role -> success
```bash
curl -s -k -H 'x-baffle-tenant: T-1001' -H 'Authorization:Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJiYWZhcGkuYmFmZmxlLmlvIiwiaWF0IjoxNzE1ODE0MTYwLjY5ODQ1NiwiYXVkIjoiYmFmYXBpLmJhZmZsZS5pbyIsInN1YiI6ImJhZmFwaS5iYWZmbGUuaW8iLCJnaXZlbk5hbWUiOiJCYWZmbGUiLCJzdXJuYW1lIjoiQWRtaW4iLCJlbWFpbCI6ImFkbWluQGFwaXVzZXIuY29tIiwicm9sZXMiOlsiZW5jcnlwdC1kZWNyeXB0Il19.WvO027v6qbIh26berMrtVd9bGsbEpcxteEt5Vryic0c' \
'https://{hostname}:8444/api/filesvc/read/employee.csv'  -o download-employee.csv
```

### 3. Swagger:

The Swagger UI can be found at 
``
https://{hostname}:8444/swagger-ui/index.html``
