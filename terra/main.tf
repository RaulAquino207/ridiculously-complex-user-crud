data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "default" {
  id = tolist(data.aws_subnets.default.ids)[0]
}

resource "aws_security_group" "web" {
  name        = "tf-web-sg"
  description = "HTTP e SSH para teste"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # opcional porta 3001 para apps de teste
  ingress {
    description = "App 3001"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "tf-web-sg" }
}

resource "aws_instance" "test" {
  ami                         = "ami-01f4efc1232d1c30d"
  instance_type               = "t3.micro"
  subnet_id                   = data.aws_subnet.default.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  # user data só para provar que está servindo algo na porta 80
  user_data = <<-EOF
              #!/bin/bash
              set -euxo pipefail
              dnf -y update
              dnf -y install busybox ec2-instance-connect
              echo "hello terraform" > /var/www.html
              nohup busybox httpd -f -p 80 -h / &
              EOF

  tags = { Name = "tf-ec2-test" }
}

output "public_ip"  { value = aws_instance.test.public_ip }
output "public_dns" { value = aws_instance.test.public_dns }
