# terraform-aws-locust
Deploy a locust.io stress test cluster on AWS based on CoreOS/Docker

## WARNING!!!

This is going to create  more-or-less a distributed denial-of-service attack in a fancy package and, therefore, if you point `target_host` at any server you don’t own you will behaving *unethically*, have your Amazon Web Services account *locked-out*, and be *liable* in a court of law for any downtime you cause.

Also keep in mind AWS Pricing for used EC2 instances will be applied.

You have been warned.

## Requirements

* Terraform
* AWS Account

## Usage

Create a file named `terraform.tfvars` and specify custom variables. Example:

    ssh_key_name = "<aws-ssh-key-name>"
    access_key = "<aws-access-key>"
    secret_key = "<aws-secret-key>"
    target_host = "http://example.com"
    instance_type = "t2.small"
    num_slaves = 3
    ...

Refer to `variables.tf` to know what variables are available for overwrite.

## Update test configuration

- modify target host via tf variable in terraform.tfvars
- modify test.py
- update by running `make prepare-update && make apply` (taints necessary tf resources, re-uploads test file)