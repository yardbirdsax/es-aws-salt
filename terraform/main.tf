provider "aws" {
  version = "~> 2.0"
  region = "us-east-1"
}

locals {
  tagName = "es-lab"
  keyName = "${local.tagName}-keyPair"
}

resource aws_vpc "vpc" {
  cidr_block = var.cidrBlock
  tags = {
    name = local.tagName
  }
  enable_dns_hostnames = true
}

resource aws_subnet "es-labSubnet" {
  cidr_block = var.cidrBlock
  vpc_id = aws_vpc.vpc.id
  tags = {
    name = local.tagName
  }
}

resource aws_security_group "es-labSG" {
  
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource aws_internet_gateway "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    name = local.tagName
  }
}

data aws_ami "ubuntu" {
  most_recent = true

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
  owners = ["099720109477"]
}

resource aws_key_pair "es-labKeyPair" {
  key_name = local.keyName
  public_key = file(var.sshPubKeyFilePath)
}

data template_cloudinit_config "esInit" {
  count = var.esNodeCount
  part {
    content = <<EOF
#!/bin/bash
wget -O - http://bootstrap.saltstack.org | sh
apt-get update -y
EOF
    content_type = "text/x-shellscript"
  }

  part {
    content = <<EOF
#cloud-config
---
hostname: "${local.tagName}-${count.index}"
EOF
    content_type = "text/cloud-config"
  }

    part {
    content = <<EOF
#cloud-config
---
write_files:
  - content: |
      base:
        '*':
          - elasticsearch
    path: /srv/salt/top.sls
    permissions: '0644'
  - content: |
      java:
        pkg.installed:
          - pkgs:
            - openjdk-8-jre  
      elasticsearch:
          pkg.installed:
            - sources:
                - elasticsearch: https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/deb/elasticsearch/2.4.5/elasticsearch-2.4.5.deb
          service.running:
            - enable: true
    path: /srv/salt/elasticsearch.sls
    permissions: '0644'
EOF
    content_type = "text/cloud-config"
  }

  part {
    content = <<EOF
#!/bin/bash
salt-call --local state.highstate -l debug
EOF
    content_type = "text/x-shellscript"
  }
}

resource aws_instance "es-lab" {
  
  ami = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.small"
  tags = {
    Name = "${local.tagName}-${count.index}"
  }
  count = var.esNodeCount
  subnet_id = aws_subnet.es-labSubnet.id
  vpc_security_group_ids = [aws_security_group.es-labSG.id]
  key_name = local.keyName
  user_data = data.template_cloudinit_config.esInit[count.index].rendered
}

resource aws_eip "es-labElasticIp" {
  vpc = true
  count = var.esNodeCount
  instance = aws_instance.es-lab[count.index].id
}

resource aws_route_table "es-labRouteTable" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }  
  tags = {
    Name = "${local.tagName}-RouteTable"
  }
}

resource aws_route_table_association "es-labRouteTableAssociation" {
  route_table_id = aws_route_table.es-labRouteTable.id
  subnet_id = aws_subnet.es-labSubnet.id
}

output "dnsNames" {
  value = join(",", aws_eip.es-labElasticIp.*.public_dns)
}