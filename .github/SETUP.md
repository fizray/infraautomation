# Repository Setup Guide — LKS 2026

Two AWS regions:
- **us-east-1 (N. Virginia)** — Application VPC, ECS app cluster, RDS, ALB
- **us-west-2 (Oregon)** — Monitoring VPC, Prometheus + Grafana ECS services

---

## How you get this repository

Fork this repository to your own GitHub account:

1. Go to [https://github.com/handipradana/infraautomation](https://github.com/handipradana/infraautomation)
2. Click **Fork** → Create fork (keep it public)
3. Clone your fork:

```bash
git clone https://github.com/<YOUR_USERNAME>/infraautomation.git
cd infraautomation
```

---

## What the CI/CD pipeline does

The 3-job pipeline runs on every push to `main`:

| Job | What it does |
|---|---|
| 1 — install | Install Python dependencies, run import smoke tests |
| 2 — build_and_push_ecr | Build Docker images for frontend + API, push to ECR us-east-1 |
| 3 — upload_to_s3 | Upload deployment metadata JSON to S3 |

**Terraform is NOT part of the pipeline.** You must run `terraform apply` manually from your terminal after fixing the bugs.

---

## Step 1 — Configure GitHub Secrets

In your repository: Settings → Secrets and Variables → Actions → New repository secret

| Secret Name | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | From AWS Academy → AWS Details |
| `AWS_SECRET_ACCESS_KEY` | From AWS Academy → AWS Details |
| `AWS_SESSION_TOKEN` | From AWS Academy — **update every session** |
| `AWS_REGION` | `us-east-1` |
| `MONITORING_REGION` | `us-west-2` |
| `AWS_ACCOUNT_ID` | 12-digit account ID |
| `ECR_REGISTRY` | `<ID>.dkr.ecr.us-east-1.amazonaws.com` |
| `TF_STATE_BUCKET` | `lks-tfstate-yourname-2026` |
| `STUDENT_NAME` | Your name (used in S3 bucket naming) |

---

## Step 2 — Fix Terraform bugs and apply manually

The Terraform modules in `terraform/modules/` contain intentional bugs.
Find and fix all bugs. See `terraform/TROUBLESHOOTING.md`.

After fixing, run Terraform manually from your terminal:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your account ID and student name

terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```

This creates all infrastructure including the S3 bucket used by the CI/CD
pipeline. Run `terraform output` to get the subnet IDs, security group IDs,
and ALB Target Group ARNs needed for the next steps.

---

## Step 3 — Push to GitHub to trigger CI/CD

```bash
git add .
git commit -m "Fix Terraform bugs"
git push origin main
```

This triggers the 3-job CI/CD pipeline. All jobs should go green.
The pipeline builds Docker images and pushes them to ECR.


---

## Step 4 — Verify

```bash
# Peering status
aws ec2 describe-vpc-peering-connections \
  --filters Name=tag:Name,Values=pcx-lks-2026 \
  --region us-east-1 \
  --query 'VpcPeeringConnections[0].Status.Code'
# Expected: "active"

# Application health
curl http://$(cd terraform && terraform output -raw alb_dns_name)/api/health
# Expected: {"status":"ok","db":"connected"}

# Ping from Oregon bastion to Virginia ECS task
aws ssm send-command --region us-west-2 \
  --instance-ids <BASTION_INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters '{"commands":["ping -c 4 <ECS_PRIVATE_IP>"]}'
# Expected: 4 packets transmitted, 4 received, 0% packet loss
```
