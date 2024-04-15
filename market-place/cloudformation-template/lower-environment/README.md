# Baffle Shield Lower Environment Setup

This project contains of Cloudformation Template to bring up a Baffle Shield Lower Environment Use case

### Prerequisite:

1. aws cli 
2. configure aws cli 
3. Permission needed to run the CloudFormation template


## Permission

It is advisable to run the provided CloudFormation template that creates a policy of needed permission, and group. 

Please ask the AWS admin to run the following CloudFormation and add user to that group 

`aws cloudformation create-stack --stack-name baffle-group --template-body file://create_group_policy/create_group_role_template.yaml --capabilities CAPABILITY_NAMED_IAM`

Once the group is created, grab the group name from CloudFormation output and add the needed user to the group.

`aws iam add-user-to-group --user-name {User_Name} --group-name {Group_Name_From_Above}`


## Create Baffle Shield Lower Environment stack

Run the following command with the parameters
1. MyIP: IP of user machine
2. UserEmail: User Email address to create Baffle Manager Account 
3. UserPassword: User Password to create Baffle Manager Account 
4. DBPassword: DB Password for the RDS

`aws cloudformation create-stack --stack-name lower-env --template-body file://create_baffle_lower_env_stack/create_baffle_lower_env_stack_template.yaml --capabilities CAPABILITY_NAMED_IAM --parameters ParameterKey=MyIP,ParameterValue=$(curl -s http://checkip.amazonaws.com/) ParameterKey=DBPassword,ParameterValue=Baffle-2024 ParameterKey=UserEmail,ParameterValue=admin@baffle.io ParameterKey=UserPassword,ParameterValue=Baffle-2024`

Once the template creates the stack it will output some value. The following are important
1. BaffleManagerURL - The URL for Baffle Manager
2. PGAdminWebURL - The URL for PG Admin UI
3. BaffleDBEndpoint	- The Endpoint Address for RDS
4. BaffleKeyStorageBucket	- S3 bucket that stores the Data Encryption Key
5. BaffleShieldKeyAlias	- The AWS KMS used by Baffle Shield
6. StackRegion	- The region where stack is deployed

#### * if the stack needed to be created on specific region and with specific profile, following needs to be passed on aws command
1. --region
2. --profile

For example:
`aws --region us-east-2 --profile other-profile cloudformation create-stack --stack-name lower-env --template-body file://create_baffle_lower_env_stack_template.yaml --capabilities CAPABILITY_NAMED_IAM --parameters ParameterKey=MyIP,ParameterValue=$(curl -s http://checkip.amazonaws.com/) ParameterKey=DBPassword,ParameterValue=Baffle-2024 ParameterKey=UserEmail,ParameterValue=admin@baffle.io ParameterKey=UserPassword,ParameterValue=Baffle-2024`
