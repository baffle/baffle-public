# Baffle Shield Lower Environment Setup

This project contains a Cloudformation Template for setting up a Baffle Shield Lower Environment Use case.

## Prerequisites:
* AWS CLI installed and configured
* Permissions necessary to run CloudFormation and to create resources referenced in the template

## Steps:

### 1. Stack Creation:

* Run the below command with the parameters or use these parameters on the AWS Console:
* MyIP: IP of the user machine
* UserEmail: User Email for Baffle Manager and Pg Admin UI
* UserPassword: Password to log into Baffle Manager and Pg Admin UI
* DBPassword: Password for the RDS

`aws cloudformation create-stack --stack-name lower-env --template-body file://create_baffle_lower_env_stack/create_baffle_lower_env_stack_template.yaml --capabilities CAPABILITY_NAMED_IAM --parameters ParameterKey=MyIP,ParameterValue=$(curl -s http://checkip.amazonaws.com/) ParameterKey=DBPassword,ParameterValue=Baffle-2024 ParameterKey=UserEmail,ParameterValue=admin@baffle.io ParameterKey=UserPassword,ParameterValue=Baffle-2024`

Once the template creates the stack it will output some value. The following are important
1. BaffleEC2SecurityGroup -  The Security Group that white list user IP 
2. DMSMigrationTaskURL - The URL for DMS Migration task for easy navigation
3. BaffleManagerURL - The URL for Baffle Manager
4. PGAdminWebURL - The URL for PG Admin UI
5. StackRegion	- The region where stack is deployed
6. StartMigrationTask - The CLI command to start the migration task
7. StopMigrationTask - The CLI command to stop the migration task

#### * if the stack needed to be created on specific region and with specific profile, following needs to be passed on aws command
1. --region
2. --profile

For example:
`aws --region us-east-2 --profile other-profile cloudformation create-stack --stack-name lower-env --template-body file://create_baffle_lower_env_stack_template.yaml --capabilities CAPABILITY_NAMED_IAM --parameters ParameterKey=MyIP,ParameterValue=$(curl -s http://checkip.amazonaws.com/) ParameterKey=DBPassword,ParameterValue=Baffle-2024 ParameterKey=UserEmail,ParameterValue=admin@baffle.io ParameterKey=UserPassword,ParameterValue=Baffle-2024`


## Download keypair 
The keypair for Baffle EC2 instance is stored on SSM and can be downloaded. Following link describes a process of downloading link 
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#create-key-pair-cloudformation
