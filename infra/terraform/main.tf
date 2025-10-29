terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

data "aws_vpc" "default" {
  default = true
}
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_key_pair" "this" {
  key_name   = "${var.name}-kp"
  public_key = file(var.ssh_public_key_path)
}

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role" "ecr_pull_role" {
  count              = var.use_ecr ? 1 : 0
  name               = "${var.name}-ecr-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}
resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  count      = var.use_ecr ? 1 : 0
  role       = aws_iam_role.ecr_pull_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_instance_profile" "ecr_profile" {
  count = var.use_ecr ? 1 : 0
  name  = "${var.name}-ecr-profile"
  role  = aws_iam_role.ecr_pull_role[0].name
}

locals {
  envs = {
    prod = {
      image_tag      = "prod"
      container_port = 3000
      host_port      = 80
      open_port      = 80
      health_int     = "30s"
      retries        = 5
    }
    test = {
      image_tag      = "test"
      container_port = 3001
      host_port      = 3001
      open_port      = 3001
      health_int     = "30s"
      retries        = 10
    }
  }

  ssh_cidr = "0.0.0.0/0"
}

# Security Groups por ambiente
resource "aws_security_group" "app" {
  for_each    = local.envs
  name        = "${var.name}-${each.key}-sg"
  description = "SG for ${var.name} ${each.key}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.ssh_cidr]
  }

  ingress {
    from_port   = each.value.open_port
    to_port     = each.value.open_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app" {
  for_each               = local.envs
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.app[each.key].id]
  key_name               = aws_key_pair.this.key_name
  iam_instance_profile   = var.use_ecr ? aws_iam_instance_profile.ecr_profile[0].name : null

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    exec > >(tee -a /var/log/user-data.log) 2>&1

    dnf makecache -y
    dnf update -y
    dnf install -y docker docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    if ${var.use_ecr}; then
      aws ecr get-login-password --region ${var.region} \
        | docker login --username AWS --password-stdin ${var.registry}
    else
      if [ -n "${var.registry_username}" ] && [ -n "${var.registry_password}" ]; then
        echo "${var.registry_password}" \
          | docker login ${var.registry} --username ${var.registry_username} --password-stdin
      fi
    fi

    mkdir -p /opt/app
    cat > /opt/app/docker-compose.yml <<'YAML'
    name: ${var.name}-${each.key}
    services:
      app:
        container_name: ${var.name}-${each.key}-app
        image: ${var.registry}/${var.image_name}:${each.value.image_tag}
        environment:
          - NODE_ENV=${each.key}
          - PORT=${each.value.container_port}
        ports:
          - "${each.value.host_port}:${each.value.container_port}"
        healthcheck:
          test: ["CMD-SHELL", "node -e \\"require('net').connect(process.env.PORT||${each.value.container_port},'127.0.0.1').on('connect',()=>process.exit(0)).on('error',()=>process.exit(1))\\" "]
          interval: ${each.value.health_int}
          timeout: 5s
          retries: ${each.value.retries}
          start_period: 10s
        restart: unless-stopped
    YAML

    cd /opt/app
    docker compose pull
    docker compose up -d

    cat >/etc/systemd/system/app-compose.service <<'UNIT'
    [Unit]
    Description=Docker Compose App ${var.name}-${each.key}
    After=docker.service
    Requires=docker.service

    [Service]
    Type=oneshot
    WorkingDirectory=/opt/app
    ExecStart=/usr/bin/docker compose up -d
    ExecStop=/usr/bin/docker compose down
    RemainAfterExit=yes
    TimeoutStartSec=0

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable app-compose.service
    systemctl start app-compose.service
  EOF

  tags = {
    Name = "${var.name}-${each.key}"
    Env  = each.key
  }
}

output "public_ip" {
  value = { for k, v in aws_instance.app : k => v.public_ip }
}
output "public_dns" {
  value = { for k, v in aws_instance.app : k => v.public_dns }
}
