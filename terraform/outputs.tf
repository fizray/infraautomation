# ── Network ───────────────────────────────────────────────
output "vpc_id" {
  description = "Application VPC ID (lks-vpc, us-east-1)"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs - used by ALB"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs - paste into ECS Console when creating services"
  value       = module.vpc.private_subnet_ids
}

output "isolated_subnet_ids" {
  description = "Isolated subnet IDs - used by RDS DB Subnet Group"
  value       = module.vpc.isolated_subnet_ids
}

# ── Security Groups ───────────────────────────────────────
output "sg_alb_id" {
  description = "ALB Security Group ID"
  value       = module.security.sg_alb_id
}

output "sg_ecs_id" {
  description = "ECS Security Group ID - paste into ECS Task Definition Console"
  value       = module.security.sg_ecs_id
}

output "sg_db_id" {
  description = "Database Security Group ID - used by RDS"
  value       = module.security.sg_db_id
}

output "sg_monitoring_id" {
  description = "Monitoring Security Group ID"
  value       = module.security.sg_monitoring_id
}

# ── ALB ───────────────────────────────────────────────────
output "alb_dns_name" {
  description = "ALB public DNS - access the application here"
  value       = module.alb.alb_dns_name
}

output "tg_fe_arn" {
  description = "Frontend Target Group ARN - paste into ECS FE Service Console"
  value       = module.alb.tg_fe_arn
}

output "tg_api_arn" {
  description = "API Target Group ARN - paste into ECS API Service Console"
  value       = module.alb.tg_api_arn
}

# ── Database ─────────────────────────────────────────────
output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint - also stored in SSM /lks/app/db_host"
  value       = module.database.rds_endpoint
  sensitive   = true
}

output "sqs_queue_url" {
  description = "SQS event queue URL"
  value       = module.database.sqs_queue_url
}

output "dynamodb_table_name" {
  description = "DynamoDB sessions table name"
  value       = module.database.dynamodb_table_name
}

# ── S3 ────────────────────────────────────────────────────
output "tfstate_bucket_name" {
  description = "S3 bucket for CI/CD deployment metadata"
  value       = module.s3.tfstate_bucket_name
}

output "assets_bucket_name" {
  description = "S3 assets bucket name"
  value       = module.s3.assets_bucket_name
}
