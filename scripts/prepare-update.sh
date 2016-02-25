#!/bin/bash
num_slaves=$(terraform show | grep -c "aws_instance.slave.")
terraform taint null_resource.master
for (( i = 0; i < $num_slaves; i++ )); do
	terraform taint null_resource.slave.${i}
done