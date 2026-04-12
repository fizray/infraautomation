variable "vpc_id"              { type = string }
variable "isolated_subnet_ids" { type = list(string) }
variable "private_subnet_ids"  { type = list(string) }
variable "security_group_id"   { type = string }
variable "db_name"             { type = string }
variable "db_username"         { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "sqs_queue_name" { type = string }
variable "dlq_name"       { type = string }
variable "dynamo_table"   { type = string }
