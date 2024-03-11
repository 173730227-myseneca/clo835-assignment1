data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

resource "aws_instance" "assignment1_ec2" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.medium"

  root_block_device {
    volume_size = 16
  }

  user_data = <<-EOF
    #!/bin/bash
    set -ex
    sudo yum update -y
    sudo yum install docker -y
    sudo systemctl start docker
    sudo usermod -a -G docker ec2-user
  EOF

  vpc_security_group_ids = [
    module.ec2_http_sg.security_group_id,
    module.ec2_ssh_sg.security_group_id
  ]
  iam_instance_profile = "LabInstanceProfile"

  tags = {
    name = "assignment1-ec2"
    course = "clo835",
    assignment = 1
  }

  key_name                = "assignment1"
  monitoring              = true
  disable_api_termination = false
  ebs_optimized           = true
}

resource "aws_key_pair" "a1_key" {
  key_name   = "assignment1"
  public_key = file("${path.module}/assignment1.pub")
}

module "ec2_http_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "ec2_sg"
  description = "Security group for ec2_sg"
  vpc_id      = data.aws_vpc.default.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-8080-tcp"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 8081
      to_port     = 8083
      protocol    = "tcp"
      description = "Host ports for my_app"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

module "ec2_ssh_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "ec2_sg"
  description = "Security group for ec2_sg"
  vpc_id      = data.aws_vpc.default.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp"]
  egress_rules        = ["all-all"]
}

resource "aws_ecr_repository" "webapp" {
  name                 = "webapp"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "mysql" {
  name                 = "mysql"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}