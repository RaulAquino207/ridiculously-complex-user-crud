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

data "aws_ssm_parameter" "ubuntu_2404_amd64" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "this" {
  key_name   = "${var.name}-kp"
  public_key = file(var.ssh_public_key_path)
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
      node_env       = "production"
    }
    test = {
      image_tag      = "test"
      container_port = 3001
      host_port      = 3001
      open_port      = 3001
      health_int     = "10s"
      retries        = 10
      node_env       = "testing"
    }
  }

  ssh_cidr = "0.0.0.0/0"
}

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
  ami                    = data.aws_ssm_parameter.ubuntu_2404_amd64.value
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.app[each.key].id]
  key_name               = aws_key_pair.this.key_name

  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/user_data.sh", {
    APP_NAME          = "${var.name}-${each.key}"
    COMPOSE_B64       = base64encode(yamlencode({
      version  = "3.8"
      services = {
        app = {
          container_name = "${var.name}-${each.key}-app"
          image          = "${var.registry}/${var.image_name}:${each.value.image_tag}"
          environment    = [
            "NODE_ENV=${each.value.node_env}",
            "PORT=${each.value.container_port}",
          ]
          ports = [
            "${each.value.host_port}:${each.value.container_port}",
          ]
          healthcheck = {
            test         = ["CMD-SHELL", "node -e \"require('net').connect(process.env.PORT||${each.value.container_port},'127.0.0.1').on('connect',()=>process.exit(0)).on('error',()=>process.exit(1))\" "]
            interval     = each.value.health_int
            timeout      = "5s"
            retries      = each.value.retries
            start_period = "10s"
          }
          restart = "unless-stopped"
        }
      }
    }))
    REGISTRY          = var.registry
    USE_ECR           = tostring(var.use_ecr)
    REGISTRY_USERNAME = var.registry_username
    REGISTRY_PASSWORD = var.registry_password
  })

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
