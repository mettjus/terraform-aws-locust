variable "access_key" {}

variable "secret_key" {}

variable "ssh_key_name" {}

variable "target_host" {}

variable "region" {
    default = "eu-central-1"
}

variable "instance_type" {
    default = "t2.micro"
}

variable "ami" {
    default = "ami-e4988188"
}

variable "num_slaves" {
    default = 2
}

variable "cluster_name" {
	default = "testing"
}

variable "test_file" {
	default = "test.py"
}