variable "aws_region" {
  description = "Primary region - application VPC (us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "monitoring_region" {
  description = "Secondary region - monitoring VPC (us-west-2 Oregon)"
  type        = string
  default     = "us-west-2"
}

variable "aws_account_id" {
  description = "12-digit AWS account ID"
  type        = string
}

variable "student_name" {
  description = "Your name - used in S3 bucket names to ensure global uniqueness"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag injected by CI/CD pipeline"
  type        = string
  default     = "latest"
}

# ── Networking — lks-vpc (us-east-1) ─────────────────────────
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "isolated_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.5.0/24", "10.0.6.0/24"]
}

variable "availability_zones" {
  description = "AZs in us-east-1"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ── Networking — lks-monitoring-vpc (us-west-2) ───────────────
variable "monitoring_vpc_cidr" {
  description = "Must NOT overlap with vpc_cidr"
  type        = string
  default     = "10.1.0.0/16"
}

variable "monitoring_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "monitoring_availability_zones" {
  description = "AZs in us-west-2"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

# ── Database ──────────────────────────────────────────────────
variable "db_name" {
  type    = string
  default = "lksdb"
}

variable "db_username" {
  type    = string
  default = "lksadmin"
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "LKS@Secure2026!"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
