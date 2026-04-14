# ── lks-vpc: Application VPC (us-west-2) ───────────────────

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}


resource "aws_vpc" "this-west" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "lks-monitoring-vpc" }
}


resource "aws_subnet" "private-2a" {
  vpc_id            = aws_vpc.this-west.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "us-west-2a"
  tags = { Name = "lks-monitoring-private-1a" }
}

resource "aws_subnet" "private-2b" {
  vpc_id            = aws_vpc.this-west.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = "us-west-2b"
  tags = { Name = "lks-monitoring-private-1b" }
}

resource "aws_vpc_peering_connection_accepter" "west-peer" {
  vpc_peering_connection_id = aws_vpc_peering_connection.peer-east.id
  auto_accept               = true
  tags = {
    Name = "pcx-lks-2026"
  }
}
