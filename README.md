# Terraform K10EKS

***Status:** Work-in-progress. Please create issues or pull requests if you have ideas for improvement.*

# **Fully automated deploy of AWS EKS Cluster with Kasten**
Example of using Terraform to automate the deploy of an AWS EKS cluster, plus the installation and initial Kasten K10 configuration 


## Summary
This projects demostrates the process of deploying an AWS EKS cluster, plus installing and configurig Kasten K10 using Terraform for fully automation of this process.  The resources to be created include:
* VPC Resources
* IAM Policy to install and use Kasten
* EKS Cluster
    - EBS CSI Driver
    - Snapshot Controller
    - CSI Storage Class
    - Volume Snapshot Class
* AWS S3 Bucket
* Kasten
    - Token Authentication
    - Access via LoadBalancer
    - EULA agreement
    - Location Profile creation using AWS S3 Bucket
    - Policy preset samples creation
* Demo App
**NOTE**: The Demo App has been build by [Timothy Dewin](https://github.com/tdewin/stock-demo/tree/main/kubernetes)

All the automation is done using Terraform and leveraging the AWS, Kubernetes, and [Kasten K10](https://docs.kasten.io/latest/api/cli.html) APIs.

## Disclaimer
This project is an example of an deployment and meant to be used for testing and learning purposes only. Do not use in production. 


# Table of Contents

1. [Prerequisites](#Prerequisites)
2. [Installing EKS Cluster and Kasten](#Installing-EKS-Cluster-and-Kasten)



## Prerequisites
To run this project you need to have some software installed and configured: 
1. [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

Ej. using brew for macOS

```
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

2. [Helm](https://helm.sh/docs/intro/install/)
Ej. using brew for macOS

```
brew install helm
```

3. [Kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
Ej. using brew for macOS

```
brew install kubectl
```

4. [Install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
Ej. using brew for macOS

```
brew install awscli
brew install aws-iam-authenticator
```

5. Configure AWS CLI providing credentials with enough privileges to create resources in AWS.
```
aws configure 
```

6. Download all terraform files, depending on option to be used, and keep them locally, all in the same folder in your laptop :
    - [Existing VPC](Existing_VPC)
    - [New VPC](New_VPC)


## Installing EKS Cluster and Kasten
For Terraform to work, we need to provide certain information to be used as variables in the **terraform.tfvars** file.   

### AWS EKS Cluster creating a new VPC
Please provide the required data for the following variables when using the [New_VPC option](New_VPC)


| Name                    | Type     | Default value       | Description                                                    |
| ----------------------- | -------- | ------------------- | -------------------------------------------------------------- |
| `region  `              | String   | `eu-west-3`         | AWS Region where all resources will be created                 |
| `k8sversion`            | String   | `1.29`              | Kubernetes version to be deployed                              |
| `cluster_name `         | String   | `k10`               | Name of the cluster to be created.  All AWS resources will use the same name  |
| `vpc_cidr`              | String   | `10.0.0.0/16`       | CIDR for VPC to be created  |
| `owner`                 | String   | `owner@domain.com`  | Owner tag in AWS            |
| `activity`              | String   | `demo`              | Activity tag in AWS         |

NOTE: Remember that by default AWS allows for only 5 VPC per region.  If in your region you already hit this limit, use the second option for using existing VPC

### AWS EKS Cluster using an existing VPC
Please provide the required data for the following variables when using the [New_VPC option](New_VPC)


| Name                    | Type     | Default value       | Description                                                    |
| ----------------------- | -------- | ------------------- | -------------------------------------------------------------- |
| `region  `              | String   | `eu-west-3`         | AWS Region where all resources will be created                 |
| `k8sversion`            | String   | `1.29`              | Kubernetes version to be deployed                              |
| `cluster_name `         | String   | `k10`               | Name of the cluster to be created.  All AWS resources will use the same name  |
| `owner`                 | String   | `owner@domain.com`  | Owner tag in AWS            |
| `activity`              | String   | `demo`              | Activity tag in AWS         |
| `vpc_id`                | String   | `vpc-aaaaaaaaaaaaa` | ID of the VPC to be used    |
| `subnet_private_init`   | Number   | `100` | Initial number for the 3rd octet for subnet CIDR.  For example, 10.16.**100**.0/24    |
| `subnet_public_init`    | Number   | `110` | Initial number for the 3rd octet for subnet CIDR.  For example, 10.16.**110**.0/24    |


The subnet_private_init and subnet_public_init variables are used to create the required subnets without an IP conflict with existing subnets in the VPC.
For the EKS cluster we will create 1 subnet per availability zone for private access, and another subnet per AZ for public access.
For example, the VPC has a CIDR 10.16.0.0/16
With terraform we will create subnets in the format 10.16.xxx.0/24.   To third octect could be any number between 1-254, as long as isn't already used by an existing subnet.

### Building the EKS Cluster with Kasten
Once the variables are set, the only thing we need to do is to apply the Terraform files:
- By using a terminal, go to the folder containing all terraform files.
- Run the following commands
```
terraform init
terraform apply
```


## Using the AWS EKS cluster and Kasten
Once Terraform is done building the infrastructure and installing Kasten, you will get the following information:

| Name                    | Value       | Description                                                    |
| ----------------------- | ----------- | -------------------------------------------------------------- |
| `cluster_name  `        | `eks-k10-1719243246`         | Name of the AWS EKS cluster created, with a random number to prevent conflicts               |
| `demoapp_url`           | `https://147E7BBAF03BFE2E44A62870A499022C.gr7.eu-west-3.eks.amazonaws.com`              | URL to access the demo Stock app        |
| `k10url `               | `http://ad2f922ef771b4b36acc13b57237cea3-233018463.eu-west-3.elb.amazonaws.com/k10/`    | URL to access the Kasten K10 Dashboard  |
| `k10token`              | `eyJhbGciOiJSUzI1NiIsImtpZCI6IjVjODIyNTU`  | Token to be used for Kasten authentication |
| `s3_bucket_name`        | `s3-k10-1719243246`              | AWS S3 Bucket to be used as Location profile         |
| `kubeconfig`            | `aws eks --region eu-west-3 update-kubeconfig --name eks-k10-1719243246` | Command to configure the kubeconfig file and access the kubernetes cluster with kubectl  |


At this point, it's possible to run tests to backup and restore the demo App, creating policies and as an option it's also possible to use Kanister for consistent backups of the PostgreSQL database.


## Destroying the AKS Cluster with Kasten
Once you are done using the AKS cluster, you can destroy it alonside all other resources created with Terraform, by using the following command:
```
terraform destroy
```