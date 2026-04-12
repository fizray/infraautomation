# ── Terraform settings ─────────────────────────────────────
# Do NOT add provider blocks here.
# All providers are configured in main.tf
terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
