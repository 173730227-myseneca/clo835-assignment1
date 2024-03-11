provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}