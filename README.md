# Phoenix Application Solution
This is my custom solution to the [Phoenix Application problem](https://github.com/xpeppers/cloud-phoenix-kata).

This project is 100% Open Source and licensed under the [APACHE2](LICENSE).

## Requirements to run the project

- **AWS Account** You should have an AWS account
- **Route53 Domain** You should have at least one DNS domain managed within AWS Route53
- **VPC** You should have an existing VPC where you can have an already present Linux instance that will be able to SSH into new EC2 instances created by Elastic Beanstalk
- **Docker Daemon** You should run a Docker daemon to build the container application image
- **Terraform** You should have the Terraform cli locally installed

## General info

- **IaC code** Iac code has been wrote in [`Terraform`](https://www.terraform.io/) and tested with version 0.13.4 (the latest at the time of writing).
- **Database Layer** MongoDB instance will be created by using [`AWS DocumentDB`](https://aws.amazon.com/documentdb/)
- **Application Layer** Node.js application will be created by using a Docker container within [`AWS Elastic Beanstalk`](https://aws.amazon.com/it/elasticbeanstalk/)
- **Backups** Database backups will be managed by **AWS DocumentDB** and Application Logs backups will be stored within [`AWS CloudWatch`](https://aws.amazon.com/it/cloudwatch/)
- **Email Notifications** Email notifications are sent via AWS SNS. Once the IaC code is executed, you will get an email with subject "AWS Notification - Subscription Confirmation" in which you have to click the link "Confirm subscription" if you want to be able to receive the email notifications

## Problem Requirements that have been solved

1. Automate the creation of the infrastructure and the setup of the application. **Solved**
2. Recover from crashes. Implement a method autorestart the service on crash **Solved, with Elastic Beanstalk the docker container that runs the application is restarted automatically whenever it crashes**
3. Backup the logs and database with rotation of 7 days **Solved, with DocumentDB and Elastic Beanstalk CloudWatch Logs retention periods**
4. Notify any CPU peak **Solved, with SNS (current configuration with emails) High CPU Usage are notified, like other important events that happens to the running application**
5. Implements a CI/CD pipeline for the code **Solved, with CodeBuild and CodePipeline**
6. Scale when the number of request are greater than 10 req /sec **Solved, but with autoscaling is monitored every minute not every second**

## Instructions

- Ensure that your AWS cli config/credentials or ENV variables have been configured to access your existing AWS account

- Clone the [Phoenix Application Solution](https://github.com/valeriodelsarto/valerio-cloud-phoenix-kata) git repo locally

```bash
git clone https://github.com/valeriodelsarto/valerio-cloud-phoenix-kata.git
```

- Go into the valerio-cloud-phoenix-kata project folder and initialize the Terraform environment

```bash
cd valerio-cloud-phoenix-kata/

terraform init
```

- Customize the terraform.tfvars file by changing the values of all the variables that needs to be adapted to your local AWS account. Important variables that needs to be surely adapted are: **dns_zone_id** and **dns_domain** (they should match your local DNS Domain managed by Route53) and **peered_vpc**, **peered_vpc_cidr** and **peered_vpc_route_table_id** that should match an already existing VPC within your AWS account. This VPC will be connected to the new VPC created by Terraform by VPC Peering, and you will be able to login via SSH from an already present Linux instance to the new EC2 instances that will be created by Elastic Beanstalk, for debug porposes.

- Customize also the Dockerrun.aws.json file by changing the URI **YOUR_AWS_ACCOUNT_ID**.dkr.ecr.**AWS_REGION**.amazonaws.com, it will be used by Elastic Beanstalk in order to pull the correct Docker image and create the application containers

- Validate the Terraform code and the variable customizations

```bash
terraform validate
```

- Create the infrastructure with Terraform (say **yes** at the interactive prompt if the Terraform plan seems ok, otherwise double check wherever needed)

```bash
terraform apply
```

- Done! Check Terraform results and then, after a few minutes (there is a CodePipeline that runs) see your application running at http://app-valerio-cloud-phoenix-kata.**YOUR_DNS_DOMAIN**!

## Local Docker image troubleshooting, if needed

- Clone also the [Phoenix Application problem](https://github.com/xpeppers/cloud-phoenix-kata) git repo locally

```bash
git clone https://github.com/xpeppers/cloud-phoenix-kata.git
```

- copy the `Dockerfile_local` from valerio-cloud-phoenix-kata/ to cloud-phoenix-kata/ and rename it to `Dockerfile`

```bash
cp valerio-cloud-phoenix-kata/Dockerfile_local cloud-phoenix-kata/Dockerfile
```

- Go into the cloud-phoenix-kata project folder and build the Docker image locally

```bash
cd cloud-phoenix-kata/

docker build -t valerio/cloud-phoenix-kata .
```

- Tag the newly created Docker image, then get the Docker credentials to the ECR registry that meanwhile have probably already been created by Terraform from AWS, then push your Docker image into your local ECR

```bash
docker tag $(docker images valerio/cloud-phoenix-kata -q) **YOUR_AWS_ACCOUNT_ID**.dkr.ecr.**AWS_REGION**.amazonaws.com/valerio-cloud-phoenix-kata

aws ecr get-login-password --region **AWS_REGION** | docker login --username AWS --password-stdin **YOUR_AWS_ACCOUNT_ID**.dkr.ecr.**AWS_REGION**.amazonaws.com

docker push **YOUR_AWS_ACCOUNT_ID**.dkr.ecr.**AWS_REGION**.amazonaws.com/valerio-cloud-phoenix-kata
```

(If you are using a Windows 10 OS, use the following PowerShell command to login to your ECR registry from your local Docker daemon)
```powershell
(Get-ECRLoginCommand -Region **AWS_REGION**).Password | docker login --username AWS --password-stdin **YOUR_AWS_ACCOUNT_ID**.dkr.ecr.**AWS_REGION**.amazonaws.com
```

## Possible improvements

1. Implement a multi-stage (eg. dev-staging-prod) CI/CD, maybe with different (or different branches of the same) GitHub repo(s), both for the application and for the IaC code
2. Add Unit Tests, Integration Tests, Static Code Analysis and Docker Images Vulnerability Scan (ECR can be used for that, too)
3. Switch from HTTP to HTTPS by managing also SSL/TLS Certificates (ELB can be used for that, too)
4. Secure the network infrastructure by restricting access to Security Groups only from CIDR and Ports that are really needed
5. Extract the DB_CONNECTION_STRING from the Dockerfile and pass the value during the build stage of the Docker image
6. Add AWS Data-at-rest Encryption wherever is possible (EBS volumes, S3, etc) by using KMS
7. Restrict AWS IAM policies and permissions where needed following the Principle of Least Privilege
8. Future development... if more services will be needed, switch to a new modern micro-services architecture by using K8s (EKS with ECS or Fargate) and the GitOps flow

Happy coding!

...And don't forget to clean all the cloud resources that have been created when you are satisfied with your tests! (say **yes** at the interactive prompt if you want to destroy all that we have created till now on your AWS account)

```bash
terraform destroy
```

PS: At the end for the "destroy" action you should manually remove the S3 bucket named valerio-cloud-phoenix-kata, since it have been modified by CodeBuild and CodePipeline by adding a few objects and Terraform stops its deletion in order to not delete objects not managed by itself.

## License

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

See [LICENSE](LICENSE) for full details.

```text
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

  https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
```