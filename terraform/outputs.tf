# ── Network ───────────────────────────────────────────────
output "vpc_id" {
  description = "Application VPC ID (lks-vpc, us-east-1)"
  value       = module.vpc.vpc_id
}

output "monitoring_vpc_id" {
  description = "Monitoring VPC ID (lks-monitoring-vpc, us-west-2)"
  value       = module.monitoring_vpc.vpc_id
}

output "peering_connection_id" {
  description = "VPC Peering Connection ID - verify status is 'active'"
  value       = module.vpc_peering.peering_connection_id
}

output "peering_connection_status" {
  description = "Should be 'active' after successful apply"
  value       = module.vpc_peering.peering_connection_status
}

output "private_subnet_ids" {
  description = "Private subnet IDs - paste these into ECS Console when creating services"
  value       = module.vpc.private_subnet_ids
}

output "isolated_subnet_ids" {
  description = "Isolated subnet IDs - used by RDS DB Subnet Group"
  value       = module.vpc.isolated_subnet_ids
}

output "monitoring_subnet_ids" {
  description = "Monitoring subnet IDs - paste into ECS Console for monitoring services"
  value       = module.monitoring_vpc.subnet_ids
}

# ── Security Groups ───────────────────────────────────────
output "sg_alb_id" {
  description = "ALB Security Group ID - paste into ALB Console"
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
  description = "Monitoring Security Group ID - paste into monitoring ECS Console"
  value       = module.security.sg_monitoring_id
}

# ── ALB ───────────────────────────────────────────────────
output "alb_dns_name" {
  description = "ALB public DNS - use as VITE_API_URL in frontend .env"
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

output "tg_analytics_arn" {
  description = "Analytics Target Group ARN - paste into ECS Analytics Service Console"
  value       = module.alb.tg_analytics_arn
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

output "sg_monitoring_oregon_id" {
  description = "Monitoring Security Group ID (us-west-2 Oregon) - use for Prometheus ECS service"
  value       = module.monitoring_vpc.sg_monitoring_id
}
