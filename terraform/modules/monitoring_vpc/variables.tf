variable "vpc_name"           { type = string }
variable "vpc_cidr"           { type = string }
variable "subnet_cidrs"       { type = list(string) }
variable "availability_zones" { type = list(string) }

# Inter-region: monitoring VPC lives in us-west-2 (Oregon)
# This variable is passed from root and used for all resource creation
variable "aws_region" {
  description = "Region for the monitoring VPC - must be different from the app VPC region"
  type        = string
  default     = "us-west-2"
}
