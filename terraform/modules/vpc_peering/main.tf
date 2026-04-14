# ── lks-vpc: Application VPC (us-east-1) ───────────────────

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_vpc_peering_connection" "peer-east" {
  peer_vpc_id   = aws_vpc.this-west.id
  vpc_id        = aws_vpc.this.id
  peer_region   = "us-west-2"
}
