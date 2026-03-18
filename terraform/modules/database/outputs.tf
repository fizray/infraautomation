output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.this.address
  sensitive   = true
}
output "sqs_queue_url" {
  value = aws_sqs_queue.this.url
}
output "dlq_url" {
  value = aws_sqs_queue.dlq.url
}
output "dynamodb_table_name" {
  value = aws_dynamodb_table.sessions.name
}
output "tfstate_bucket_name" {
  value = data.aws_s3_bucket.tfstate.bucket
}
output "assets_bucket_name" {
  value = aws_s3_bucket.assets.bucket
}
