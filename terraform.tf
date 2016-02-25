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

resource "template_file" "master-unit" {
    template = "${file("templates/master-locust.service")}"
    vars = {
        target_host = "${var.target_host}"
        locust_file = "${base64encode(file("${var.test_file}"))}"
    }
}

resource "template_file" "slave-unit" {
	template = "${file("templates/slave-locust.service")}"
	vars = {
		target_host = "${var.target_host}"
		locust_file = "${base64encode(file("${var.test_file}"))}"
		master_host = "${aws_instance.master.private_ip}"
	}
}

resource "aws_instance" "master" {
    ami = "${var.ami}"
    instance_type = "${var.master_instance_type}"
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

    user_data = "${file("templates/coreos.yaml")}"
}

resource "aws_instance" "slave" {
    ami = "${var.ami}"
    instance_type = "${var.slave_instance_type}"
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

    user_data = "${file("templates/coreos.yaml")}"
}

resource "null_resource" "master" {
    triggers {
        id = "${element(aws_instance.master.*.id,0)}"
    }
    connection {
        host = "${element(aws_instance.master.*.public_ip,0)}"
        user = "core"
        agent = true
    }
    provisioner "remote-exec" {
        inline = [
            "cat <<EOF > /tmp/locustfile.py\n${file("${var.test_file}")}\nEOF",
            "sudo mv /tmp/locustfile.py /etc/locustfile.py",
            "cat <<EOF > /tmp/locust.service\n${template_file.master-unit.rendered}\nEOF",
            "sudo mv /tmp/locust.service /etc/systemd/system/locust.service",
            "sudo systemctl daemon-reload",
            "sudo systemctl restart locust"
        ]
    }
}

resource "null_resource" "slave" {
    triggers {
        id = "${join(",",aws_instance.slave.*.id)}"
    }
    count = "${var.num_slaves}"
    connection {
        host = "${element(aws_instance.slave.*.public_ip,count.index)}"
        user = "core"
        agent = true
    }
    provisioner "remote-exec" {
        inline = [
            "cat <<EOF > /tmp/locustfile.py\n${file("${var.test_file}")}\nEOF",
            "sudo mv /tmp/locustfile.py /etc/locustfile.py",
            "cat <<EOF > /tmp/locust.service\n${template_file.slave-unit.rendered}\nEOF",
            "sudo mv /tmp/locust.service /etc/systemd/system/locust.service",
            "sudo systemctl daemon-reload",
            "sudo systemctl restart locust"
        ]
    }
}