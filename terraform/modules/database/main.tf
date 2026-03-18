# ── Database, Storage & Messaging ──────────────────────────

# RDS Subnet Group
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
resource "aws_db_subnet_group" "this" {
  name       = "lks-db-subnet-group"
  subnet_ids = var.isolated_subnet_ids
  tags       = { Name = "lks-db-subnet-group" }
}

# RDS PostgreSQL
resource "aws_db_instance" "this" {
  identifier        = "lks-rds-postgres"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  backup_retention_period = 7

  tags = { Name = "lks-rds-postgres" }
}

# DynamoDB — sessions
resource "aws_dynamodb_table" "sessions" {
  name         = var.dynamo_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "sessionId"
  range_key    = "createdAt"

  attribute {
    name = "sessionId"
    type = "S"
  }
  attribute {
    name = "createdAt"
    type = "N"
  }
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }
  point_in_time_recovery { enabled = true }
  tags = { Name = var.dynamo_table }
}

# SQS Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  name = var.dlq_name
  tags = { Name = var.dlq_name }
}

# SQS Main Queue
resource "aws_sqs_queue" "this" {
  name                       = var.sqs_queue_name
  visibility_timeout_seconds = 30

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
  tags = { Name = var.sqs_queue_name }
}

# S3 — Terraform state bucket
# This bucket is created BEFORE terraform apply (in Step 1 of jury-deploy.sh
# or manually by the contestant). Use data source to reference it without
# recreating — avoids BucketAlreadyExists error on re-apply.
data "aws_s3_bucket" "tfstate" {
  bucket = var.tfstate_bucket_name
}

# S3 — App assets bucket (Terraform manages this one)
resource "aws_s3_bucket" "assets" {
  bucket        = var.assets_bucket_name
  force_destroy = true
  tags          = { Name = var.assets_bucket_name }
}
resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration { status = "Enabled" }
}

# SSM Parameters
resource "aws_ssm_parameter" "db_host" {
  name  = "/lks/app/db_host"
  type  = "SecureString"
  value = aws_db_instance.this.address
  tags  = { Name = "lks-ssm-db-host" }
}
resource "aws_ssm_parameter" "db_password" {
  name  = "/lks/app/db_password"
  type  = "SecureString"
  value = var.db_password
  tags  = { Name = "lks-ssm-db-password" }
}
resource "aws_ssm_parameter" "sqs_url" {
  name  = "/lks/app/sqs_url"
  type  = "String"
  value = aws_sqs_queue.this.url
  tags  = { Name = "lks-ssm-sqs-url" }
}
resource "aws_ssm_parameter" "dynamo_table" {
  name  = "/lks/app/dynamodb_table"
  type  = "String"
  value = aws_dynamodb_table.sessions.name
  tags  = { Name = "lks-ssm-dynamo-table" }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "fe" {
  name              = "/ecs/lks-fe-app"
  retention_in_days = 7
}
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/lks-api-app"
  retention_in_days = 7
}
resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/ecs/lks-prometheus"
  retention_in_days = 7
}
