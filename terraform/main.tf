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

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

resource "aws_lb_target_group" "tg_app" {
 name     = "target-group-webapp"
 port     = 8080
 protocol = "HTTP"
 vpc_id   = data.aws_vpc.default.id
}

resource "aws_lb_target_group_attachment" "tg_attachment_blue" {
 target_group_arn = aws_lb_target_group.tg_app.arn
 target_id        = aws_instance.assignment1_ec2.id
 port             = 8081
}

resource "aws_lb_target_group_attachment" "tg_attachment_pink" {
 target_group_arn = aws_lb_target_group.tg_app.arn
 target_id        = aws_instance.assignment1_ec2.id
 port             = 8082
}

resource "aws_lb_target_group_attachment" "tg_attachment_lime" {
 target_group_arn = aws_lb_target_group.tg_app.arn
 target_id        = aws_instance.assignment1_ec2.id
 port             = 8083
}

resource "aws_lb" "app_alb" {
 name               = "app-alb"
 internal           = false
 load_balancer_type = "application"
 security_groups    = [module.ec2_http_sg.security_group_id, module.ec2_ssh_sg.security_group_id]
 subnets            = [for s in data.aws_subnet.default : s.id]
}

resource "aws_lb_listener" "alb_listener" {
 load_balancer_arn = aws_lb.app_alb.arn
 port              = "8080"
 protocol          = "HTTP"

 default_action {
   type             = "forward"
   target_group_arn = aws_lb_target_group.tg_app.arn
 }
}