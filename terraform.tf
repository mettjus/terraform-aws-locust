provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.region}"
}

resource "aws_vpc" "locust" {
    cidr_block = "172.20.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags {
        Name = "locust-${var.cluster_name}"
    }
}

resource "aws_subnet" "locust" {
    vpc_id = "${aws_vpc.locust.id}"
    cidr_block = "172.20.250.0/24"

    tags {
        Name = "locust-${var.cluster_name}"
    }
}

resource "aws_route_table" "locust" {
    vpc_id = "${aws_vpc.locust.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.locust.id}"
    }
    tags {
        Name = "locust-${var.cluster_name}"
    }
}

resource "aws_internet_gateway" "locust" {
    vpc_id = "${aws_vpc.locust.id}"
    tags {
        Name = "locust-${var.cluster_name}"
    }
}

resource "aws_route_table_association" "locust" {
    subnet_id = "${aws_subnet.locust.id}"
    route_table_id = "${aws_route_table.locust.id}"
}

resource "aws_security_group" "locust" {
    name = "locust-${var.cluster_name}"
    vpc_id = "${aws_vpc.locust.id}"

    tags {
        Name = "locust-${var.cluster_name}"
    }
}

resource "aws_security_group_rule" "allow_ssh" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.locust.id}"
}

resource "aws_security_group_rule" "allow_all_cluster" {
    type = "ingress"
    from_port = 0
    to_port = 65535
    protocol = "-1"
    source_security_group_id = "${aws_security_group.locust.id}"
    security_group_id = "${aws_security_group.locust.id}"
}

resource "aws_security_group_rule" "allow_all_egress" {
    type = "egress"
    from_port = 0
    to_port = 65535
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = "${aws_security_group.locust.id}"
}

resource "aws_security_group_rule" "allow_locust" {
    type = "ingress"
    from_port = 8089
    to_port = 8089
    protocol = "tcp"
    cidr_blocks = ["${file("public_ip.txt")}/32"]
    security_group_id = "${aws_security_group.locust.id}"
}

resource "template_file" "master" {
	template = "${file("master.yaml")}"
	vars = {
		target_host = "${var.target_host}"
		locust_file = "${base64encode(file("${var.test_file}"))}"
	}
}

resource "template_file" "slave" {
	template = "${file("slave.yaml")}"
	vars = {
		target_host = "${var.target_host}"
		locust_file = "${base64encode(file("${var.test_file}"))}"
		master_host = "${aws_instance.master.private_ip}"
	}
}

resource "aws_instance" "master" {
    ami = "${var.ami}"
    instance_type = "${var.instance_type}"
    security_groups = [ "${aws_security_group.locust.id}" ]
    subnet_id = "${aws_subnet.locust.id}"
    associate_public_ip_address = true
    key_name = "${var.ssh_key_name}"

    connection {
        user = "core"
        agent = true
    }

    tags {
        Name = "locust-${var.cluster_name}-master"
        Cluster = "${var.cluster_name}"
        Role = "master"
    }

    user_data = "${template_file.master.rendered}"
}

resource "aws_instance" "slave" {
    ami = "${var.ami}"
    instance_type = "${var.instance_type}"
    count = "${var.num_slaves}"
    security_groups = [ "${aws_security_group.locust.id}" ]
    subnet_id = "${aws_subnet.locust.id}"
    associate_public_ip_address = true
    key_name = "${var.ssh_key_name}"

    connection {
        user = "core"
        agent = true
    }

    tags {
        Name = "locust-${var.cluster_name}-slave"
        Cluster = "${var.cluster_name}"
        Role = "slave"
    }

    user_data = "${template_file.slave.rendered}"
}