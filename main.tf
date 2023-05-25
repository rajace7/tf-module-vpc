// Create VPC using terraform

resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
}