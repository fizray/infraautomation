#!/usr/bin/env bash
# ============================================================
#  testing/jury-assess.sh
#  LKS 2026 — Jury Assessment Script
#
#  Usage:
#    chmod +x testing/jury-assess.sh
#    ./testing/jury-assess.sh <nama-siswa>
#
#  Contoh:
#    ./testing/jury-assess.sh "Budi Santoso"
#
#  Script ini menilai semua komponen dan menghasilkan:
#    - Output skor real-time di terminal
#    - File laporan penilaian lengkap di /tmp/
# ============================================================
set -euo pipefail

# ── Args ────────────────────────────────────────────────────
STUDENT="${1:-UNKNOWN}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT="/tmp/jury-report-${STUDENT// /_}-$TIMESTAMP.txt"

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; NC='\033[0m'

# ── Score tracking ───────────────────────────────────────────
declare -A SECTION_SCORE
declare -A SECTION_MAX
TOTAL_SCORE=0
TOTAL_MAX=0

# ── Helpers ─────────────────────────────────────────────────
_score() {
  local section="$1" pts="$2" desc="$3" status="$4"
  SECTION_SCORE[$section]=$(( ${SECTION_SCORE[$section]:-0} + pts ))
  if [ "$status" = "pass" ]; then
    TOTAL_SCORE=$(( TOTAL_SCORE + pts ))
    echo -e "  ${GREEN}[+$pts]${NC} $desc"
    echo "  [+$pts] $desc" >> "$REPORT"
  else
    echo -e "  ${RED}[ 0]${NC} $desc — ${RED}TIDAK TERPENUHI${NC}"
    echo "  [ 0] $desc — TIDAK TERPENUHI" >> "$REPORT"
  fi
}

award()    { _score "$1" "$2" "$3" "pass"; }
no_award() { _score "$1"   0 "$3" "fail"; }

header() {
  local title="$1" max="$2" section="$3"
  SECTION_MAX[$section]=$max
  TOTAL_MAX=$(( TOTAL_MAX + max ))
  echo -e "\n${BOLD}${MAGENTA}┌─ $title (maks $max poin) ─┐${NC}"
  echo "" >> "$REPORT"
  echo "┌─ $title (maks $max) ─┐" >> "$REPORT"
}

section_summary() {
  local s="$1" title="$2"
  local got=${SECTION_SCORE[$s]:-0}
  local max=${SECTION_MAX[$s]:-0}
  echo -e "  ${BOLD}Subtotal: $got / $max${NC}"
  echo "  Subtotal: $got / $max" >> "$REPORT"
}

aws_q() { aws "$@" --output text 2>/dev/null || echo ""; }

# ── Report header ────────────────────────────────────────────
{
  echo "========================================================"
  echo "  LKS 2026 — JURY ASSESSMENT REPORT"
  echo "========================================================"
  echo "  Siswa   : $STUDENT"
  echo "  Juri    : $(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)"
  echo "  Waktu   : $(date)"
  echo "  Script  : testing/jury-assess.sh"
  echo "========================================================"
} > "$REPORT"

echo -e "\n${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║      LKS 2026 — JURY ASSESSMENT SCRIPT         ║${NC}"
echo -e "${BOLD}║  Siswa: $STUDENT${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo -e "  Report: ${CYAN}$REPORT${NC}"

# ── Terraform helper ─────────────────────────────────────────
TF_DIR="$(dirname "$0")/../terraform"
tf_out() { (cd "$TF_DIR" && terraform output -raw "$1" 2>/dev/null) || echo ""; }

VPC_ID=$(tf_out vpc_id)
MON_VPC_ID=$(tf_out monitoring_vpc_id)
PEERING_ID=$(tf_out peering_connection_id)
PEERING_STATUS=$(tf_out peering_connection_status)
ALB_DNS=$(tf_out alb_dns_name)
SG_ECS=$(tf_out sg_ecs_id)
SG_MON=$(tf_out sg_monitoring_id)
TG_FE=$(tf_out tg_fe_arn)
TG_API=$(tf_out tg_api_arn)

# ═══════════════════════════════════════════════════════════════
# A. Networking & VPC (30 poin)
# ═══════════════════════════════════════════════════════════════
header "A. Networking & VPC" 30 "A"

# lks-vpc
if [ -n "$VPC_ID" ]; then
  CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" \
    --query 'Vpcs[0].CidrBlock' --output text --region us-east-1 2>/dev/null)
  [ "$CIDR" = "10.0.0.0/16" ] \
    && award "A" 3 "lks-vpc dibuat dengan CIDR 10.0.0.0/16" \
    || no_award "A" 3 "lks-vpc CIDR salah: '$CIDR'"
else
  no_award "A" 3 "lks-vpc tidak ditemukan"
fi

# 6 subnet
SN=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=${VPC_ID:-none}" \
  --query 'length(Subnets)' --output text --region us-east-1 2>/dev/null || echo 0)
[ "$SN" = "6" ] \
  && award "A" 3 "6 subnet (2 public, 2 private, 2 isolated)" \
  || no_award "A" 3 "Jumlah subnet $SN (harus 6)"

# IGW
IGW=$(aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=${VPC_ID:-none}" \
  --query 'length(InternetGateways)' --output text --region us-east-1 2>/dev/null || echo 0)
[ "$IGW" = "1" ] \
  && award "A" 2 "Internet Gateway terpasang" \
  || no_award "A" 2 "Internet Gateway tidak ditemukan"

# NAT Gateway
NAT=$(aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=${VPC_ID:-none}" "Name=state,Values=available" \
  --query 'NatGateways[0].State' --output text --region us-east-1 2>/dev/null)
[ "$NAT" = "available" ] \
  && award "A" 2 "NAT Gateway: available" \
  || no_award "A" 2 "NAT Gateway tidak ditemukan"

# lks-monitoring-vpc
if [ -n "$MON_VPC_ID" ]; then
  MCIDR=$(aws ec2 describe-vpcs --vpc-ids "$MON_VPC_ID" \
    --query 'Vpcs[0].CidrBlock' --output text --region us-west-2 2>/dev/null)
  [ "$MCIDR" = "10.1.0.0/16" ] \
    && award "A" 3 "lks-monitoring-vpc CIDR: 10.1.0.0/16 (us-west-2)" \
    || no_award "A" 3 "lks-monitoring-vpc CIDR salah"
else
  no_award "A" 3 "lks-monitoring-vpc tidak ditemukan di us-west-2"
fi

MSN=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=${MON_VPC_ID:-none}" \
  --query 'length(Subnets)' --output text --region us-west-2 2>/dev/null || echo 0)
[ "$MSN" = "2" ] \
  && award "A" 2 "lks-monitoring-vpc: 2 private subnet" \
  || no_award "A" 2 "lks-monitoring-vpc subnet count: $MSN (harus 2)"

# VPC Peering
[ "$PEERING_STATUS" = "active" ] \
  && award "A" 5 "VPC Peering pcx-lks-2026: ACTIVE" \
  || no_award "A" 5 "VPC Peering status '$PEERING_STATUS' (harus active)"

# Route Virginia → Oregon
VA_RT=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=${VPC_ID:-none}" "Name=tag:Name,Values=lks-private-rt" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='10.1.0.0/16'] | length(@)" \
  --output text --region us-east-1 2>/dev/null || echo 0)
[ "${VA_RT:-0}" -gt 0 ] \
  && award "A" 5 "Route 10.1.0.0/16 ada di lks-private-rt (Virginia → Oregon)" \
  || no_award "A" 5 "Route 10.1.0.0/16 TIDAK ada di lks-private-rt"

# Route Oregon → Virginia
OR_RT=$(aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=${MON_VPC_ID:-none}" "Name=tag:Name,Values=lks-monitoring-rt" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='10.0.0.0/16'] | length(@)" \
  --output text --region us-west-2 2>/dev/null || echo 0)
[ "${OR_RT:-0}" -gt 0 ] \
  && award "A" 5 "Route 10.0.0.0/16 ada di lks-monitoring-rt (Oregon → Virginia)" \
  || no_award "A" 5 "Route 10.0.0.0/16 TIDAK ada di lks-monitoring-rt"

section_summary "A" "Networking & VPC"

# ═══════════════════════════════════════════════════════════════
# B. Security Groups (10 poin)
# ═══════════════════════════════════════════════════════════════
header "B. Security Groups" 10 "B"

if [ -n "$SG_ECS" ]; then
  # Port 3000 & 8080 from ALB SG
  P3000=$(aws ec2 describe-security-groups --group-ids "$SG_ECS" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`3000\`] | length(@)" \
    --output text --region us-east-1 2>/dev/null || echo 0)
  P8080=$(aws ec2 describe-security-groups --group-ids "$SG_ECS" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`8080\`] | length(@)" \
    --output text --region us-east-1 2>/dev/null || echo 0)
  [ "${P3000:-0}" -gt 0 ] && [ "${P8080:-0}" -gt 0 ] \
    && award "B" 3 "lks-sg-ecs: port 3000 dan 8080 terbuka dari ALB" \
    || no_award "B" 3 "lks-sg-ecs: port 3000 atau 8080 tidak terbuka"

  # Port 9100 from 10.1.0.0/16 (CRITICAL for Prometheus)
  P9100=$(aws ec2 describe-security-groups --group-ids "$SG_ECS" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`9100\`] \
             .IpRanges[?CidrIp=='10.1.0.0/16'].CidrIp | [0]" \
    --output text --region us-east-1 2>/dev/null)
  [ "$P9100" = "10.1.0.0/16" ] \
    && award "B" 5 "lks-sg-ecs: TCP 9100 dari 10.1.0.0/16 ← KUNCI PEERING PROMETHEUS" \
    || no_award "B" 5 "lks-sg-ecs: TCP 9100 dari 10.1.0.0/16 TIDAK ADA — Prometheus tidak bisa scrape!"
else
  no_award "B" 8 "lks-sg-ecs tidak ditemukan"
fi

# lks-sg-db exists
DB_SG=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=${VPC_ID:-none}" "Name=tag:Name,Values=lks-sg-db" \
  --query 'length(SecurityGroups)' --output text --region us-east-1 2>/dev/null || echo 0)
[ "${DB_SG:-0}" -gt 0 ] \
  && award "B" 2 "lks-sg-db: ada" \
  || no_award "B" 2 "lks-sg-db tidak ditemukan"

section_summary "B" "Security Groups"

# ═══════════════════════════════════════════════════════════════
# C. Database (10 poin)
# ═══════════════════════════════════════════════════════════════
header "C. Database Services" 10 "C"

RDS_STATUS=$(aws rds describe-db-instances \
  --db-instance-identifier lks-rds-postgres \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text --region us-east-1 2>/dev/null)
[ "$RDS_STATUS" = "available" ] \
  && award "C" 5 "RDS lks-rds-postgres: available" \
  || no_award "C" 5 "RDS tidak ditemukan atau status '$RDS_STATUS'"

DDB=$(aws dynamodb describe-table --table-name lks-sessions \
  --query 'Table.TableStatus' --output text --region us-east-1 2>/dev/null)
[ "$DDB" = "ACTIVE" ] \
  && award "C" 3 "DynamoDB lks-sessions: ACTIVE" \
  || no_award "C" 3 "DynamoDB lks-sessions tidak ada"

SSM=$(aws ssm describe-parameters \
  --parameter-filters "Key=Name,Option=BeginsWith,Values=/lks/app" \
  --query 'length(Parameters)' --output text --region us-east-1 2>/dev/null || echo 0)
[ "${SSM:-0}" -ge 2 ] \
  && award "C" 2 "SSM Parameters /lks/app/*: $SSM parameter(s)" \
  || no_award "C" 2 "SSM Parameters tidak ditemukan (harus >= 2)"

section_summary "C" "Database"

# ═══════════════════════════════════════════════════════════════
# D. ECR Repositories (5 poin)
# ═══════════════════════════════════════════════════════════════
header "D. ECR Repositories" 5 "D"

FE_ECR=$(aws ecr describe-repositories --repository-names lks-fe-app \
  --query 'repositories[0].repositoryUri' --output text --region us-east-1 2>/dev/null)
API_ECR=$(aws ecr describe-repositories --repository-names lks-api-app \
  --query 'repositories[0].repositoryUri' --output text --region us-east-1 2>/dev/null)
[ -n "$FE_ECR" ] && [ -n "$API_ECR" ] \
  && award "D" 2 "ECR lks-fe-app dan lks-api-app ada di us-east-1" \
  || no_award "D" 2 "Satu atau lebih ECR app tidak ditemukan di us-east-1"

PROM_ECR=$(aws ecr describe-repositories --repository-names lks-prometheus \
  --query 'repositories[0].repositoryUri' --output text --region us-west-2 2>/dev/null)
[ -n "$PROM_ECR" ] \
  && award "D" 2 "ECR lks-prometheus ada di us-west-2" \
  || no_award "D" 2 "ECR lks-prometheus tidak ditemukan di us-west-2"

FE_IMG=$(aws ecr list-images --repository-name lks-fe-app \
  --region us-east-1 --query 'length(imageIds)' --output text 2>/dev/null || echo 0)
API_IMG=$(aws ecr list-images --repository-name lks-api-app \
  --region us-east-1 --query 'length(imageIds)' --output text 2>/dev/null || echo 0)
[ "${FE_IMG:-0}" -gt 0 ] && [ "${API_IMG:-0}" -gt 0 ] \
  && award "D" 1 "ECR images tersedia: FE=$FE_IMG, API=$API_IMG" \
  || no_award "D" 1 "ECR images kosong — CI/CD pipeline belum berjalan"

section_summary "D" "ECR"

# ═══════════════════════════════════════════════════════════════
# E. ECS Application Services (20 poin)
# ═══════════════════════════════════════════════════════════════
header "E. ECS Application Services" 20 "E"

CS=$(aws ecs describe-clusters --clusters lks-ecs-cluster \
  --query 'clusters[0].status' --output text --region us-east-1 2>/dev/null)
[ "$CS" = "ACTIVE" ] \
  && award "E" 3 "ECS cluster lks-ecs-cluster: ACTIVE (us-east-1)" \
  || no_award "E" 3 "lks-ecs-cluster tidak ditemukan"

for SVC in lks-fe-service lks-api-service; do
  SS=$(aws ecs describe-services --cluster lks-ecs-cluster --services "$SVC" \
    --query 'services[0].status' --output text --region us-east-1 2>/dev/null)
  RC=$(aws ecs describe-services --cluster lks-ecs-cluster --services "$SVC" \
    --query 'services[0].runningCount' --output text --region us-east-1 2>/dev/null || echo 0)
  TG_ARN=$(aws ecs describe-services --cluster lks-ecs-cluster --services "$SVC" \
    --query 'services[0].loadBalancers[0].targetGroupArn' --output text --region us-east-1 2>/dev/null)

  if [ "$SS" = "ACTIVE" ] && [ "${RC:-0}" -gt 0 ]; then
    award "E" 4 "$SVC: ACTIVE, $RC task(s) running"
    [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ] \
      && award "E" 2 "$SVC: terhubung ke Target Group" \
      || no_award "E" 2 "$SVC: tidak terhubung ke Target Group"
  else
    no_award "E" 6 "$SVC: tidak running (status=$SS, running=${RC:-0})"
  fi
done

# ALB target group health
if [ -n "$TG_FE" ] && [ "$TG_FE" != "None" ]; then
  FE_HEALTH=$(aws elbv2 describe-target-health \
    --target-group-arn "$TG_FE" \
    --query 'TargetHealthDescriptions[0].TargetHealth.State' \
    --output text --region us-east-1 2>/dev/null)
  [ "$FE_HEALTH" = "healthy" ] \
    && award "E" 1 "ALB Target Group FE: healthy" \
    || no_award "E" 1 "ALB Target Group FE: $FE_HEALTH"
fi
if [ -n "$TG_API" ] && [ "$TG_API" != "None" ]; then
  API_HEALTH=$(aws elbv2 describe-target-health \
    --target-group-arn "$TG_API" \
    --query 'TargetHealthDescriptions[0].TargetHealth.State' \
    --output text --region us-east-1 2>/dev/null)
  [ "$API_HEALTH" = "healthy" ] \
    && award "E" 1 "ALB Target Group API: healthy" \
    || no_award "E" 1 "ALB Target Group API: $API_HEALTH"
fi

section_summary "E" "ECS Application"

# ═══════════════════════════════════════════════════════════════
# F. ALB & Application Functionality (20 poin)
# ═══════════════════════════════════════════════════════════════
header "F. ALB & Application Functionality" 20 "F"

if [ -n "$ALB_DNS" ]; then
  HC=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    "http://$ALB_DNS/api/health" 2>/dev/null || echo "000")
  [ "$HC" = "200" ] \
    && award "F" 3 "ALB → /api/health: HTTP 200" \
    || no_award "F" 3 "ALB → /api/health: HTTP $HC"

  FE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    "http://$ALB_DNS/" 2>/dev/null || echo "000")
  [ "$FE" = "200" ] \
    && award "F" 3 "ALB → Frontend /: HTTP 200" \
    || no_award "F" 3 "ALB → Frontend: HTTP $FE"

  # CRUD full cycle
  TS=$(date +%s)
  CR=$(curl -s --max-time 10 -X POST "http://$ALB_DNS/api/users" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Jury Test $TS\",\"email\":\"jury$TS@lks2026.id\",\"institution\":\"LKS 2026 Jury\",\"position\":\"Evaluator\"}" \
    2>/dev/null || echo "{}")
  USER_ID=$(echo "$CR" | jq -r '.id // empty' 2>/dev/null)

  if [ -n "$USER_ID" ]; then
    award "F" 4 "CRUD Create: berhasil (ID: $USER_ID)"

    RD=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
      "http://$ALB_DNS/api/users/$USER_ID" 2>/dev/null || echo "000")
    [ "$RD" = "200" ] \
      && award "F" 2 "CRUD Read: GET /api/users/$USER_ID → 200" \
      || no_award "F" 2 "CRUD Read: $RD"

    UP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
      -X PUT "http://$ALB_DNS/api/users/$USER_ID" \
      -H "Content-Type: application/json" \
      -d '{"name":"Updated by Jury","position":"Verified"}' \
      2>/dev/null || echo "000")
    [ "$UP" = "200" ] \
      && award "F" 2 "CRUD Update: PUT /api/users/$USER_ID → 200" \
      || no_award "F" 2 "CRUD Update: $UP"

    # Verify update persisted
    UPDATED_POS=$(curl -s --max-time 10 \
      "http://$ALB_DNS/api/users/$USER_ID" 2>/dev/null \
      | jq -r '.position // empty' 2>/dev/null)
    [ "$UPDATED_POS" = "Verified" ] \
      && award "F" 2 "CRUD Update: perubahan tersimpan di DB" \
      || no_award "F" 2 "CRUD Update: data tidak tersimpan dengan benar"

    DL=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
      -X DELETE "http://$ALB_DNS/api/users/$USER_ID" \
      2>/dev/null || echo "000")
    [ "$DL" = "200" ] \
      && award "F" 2 "CRUD Delete: DELETE /api/users/$USER_ID → 200" \
      || no_award "F" 2 "CRUD Delete: $DL"

    # Verify deletion
    GONE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
      "http://$ALB_DNS/api/users/$USER_ID" 2>/dev/null || echo "000")
    [ "$GONE" = "404" ] \
      && award "F" 2 "CRUD Delete: data benar-benar terhapus (404 setelah delete)" \
      || no_award "F" 2 "CRUD Delete: data masih ada setelah delete (HTTP $GONE)"
  else
    no_award "F" 14 "CRUD Create gagal — pastikan ECS API terhubung ke RDS"
  fi
else
  no_award "F" 20 "ALB DNS tidak tersedia — skip semua HTTP tests"
fi

section_summary "F" "ALB & Functionality"

# ═══════════════════════════════════════════════════════════════
# G. Prometheus + Inter-Region Peering (25 poin)
# ═══════════════════════════════════════════════════════════════
header "G. Prometheus + Inter-Region Peering" 25 "G"

MC=$(aws ecs describe-clusters --clusters lks-monitoring-cluster \
  --query 'clusters[0].status' --output text --region us-west-2 2>/dev/null)
[ "$MC" = "ACTIVE" ] \
  && award "G" 3 "lks-monitoring-cluster: ACTIVE (us-west-2)" \
  || no_award "G" 3 "lks-monitoring-cluster tidak ditemukan di us-west-2"

PS=$(aws ecs describe-services \
  --cluster lks-monitoring-cluster --services lks-prometheus-service \
  --query 'services[0].status' --output text --region us-west-2 2>/dev/null)
PR=$(aws ecs describe-services \
  --cluster lks-monitoring-cluster --services lks-prometheus-service \
  --query 'services[0].runningCount' --output text --region us-west-2 2>/dev/null || echo 0)

if [ "$PS" = "ACTIVE" ] && [ "${PR:-0}" -gt 0 ]; then
  award "G" 5 "Prometheus ECS service: ACTIVE, $PR task(s) running"

  # Get task IP
  PTASK=$(aws ecs list-tasks \
    --cluster lks-monitoring-cluster --service-name lks-prometheus-service \
    --query 'taskArns[0]' --output text --region us-west-2 2>/dev/null)

  if [ -n "$PTASK" ] && [ "$PTASK" != "None" ]; then
    PIP=$(aws ecs describe-tasks \
      --cluster lks-monitoring-cluster --tasks "$PTASK" --region us-west-2 \
      --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value | [0]' \
      --output text 2>/dev/null)

    if [ -n "$PIP" ] && [ "$PIP" != "None" ]; then
      award "G" 3 "Prometheus task private IP: $PIP (di subnet 10.1.x.x)"

      # Verify Prometheus is in Oregon subnet
      echo "$PIP" | grep -q "^10\.1\." \
        && award "G" 2 "Prometheus berjalan di lks-monitoring-vpc (10.1.x.x) ✓" \
        || no_award "G" 2 "Prometheus IP $PIP bukan di 10.1.x.x"

      # Check Prometheus targets via API
      TARGETS=$(curl -s --max-time 8 \
        "http://$PIP:9090/api/v1/targets" 2>/dev/null || echo "")

      if [ -n "$TARGETS" ]; then
        # Count healthy non-prometheus targets
        HEALTHY=$(echo "$TARGETS" | \
          jq '[.data.activeTargets[] | select(.labels.job != "prometheus") | select(.health == "up")] | length' \
          2>/dev/null || echo 0)
        UNHEALTHY=$(echo "$TARGETS" | \
          jq '[.data.activeTargets[] | select(.labels.job != "prometheus") | select(.health != "up")] | length' \
          2>/dev/null || echo 0)

        if [ "${HEALTHY:-0}" -ge 1 ]; then
          award "G" 8 "Prometheus Targets UP: $HEALTHY ECS service(s) terpantau dari Oregon ← PEERING TERBUKTI!"
          [ "${HEALTHY:-0}" -ge 2 ] \
            && award "G" 4 "Semua ECS services terpantau ($HEALTHY/2 targets UP)" \
            || no_award "G" 4 "Baru $HEALTHY/2 ECS targets yang UP"
        else
          no_award "G" 12 "Prometheus tidak bisa scrape ECS targets — cek: route table, SG port 9100, ECS task IP di prometheus.yml"
          echo -e "  ${YELLOW}[INFO]${NC} Unhealthy targets: $UNHEALTHY"
          # Partial credit if Prometheus itself is up but can't reach targets
          SELF_UP=$(echo "$TARGETS" | \
            jq '[.data.activeTargets[] | select(.labels.job == "prometheus") | select(.health == "up")] | length' \
            2>/dev/null || echo 0)
          [ "${SELF_UP:-0}" -gt 0 ] \
            && award "G" 2 "Prometheus sendiri running dan self-scraping (partial credit)" \
            || no_award "G" 2 "Prometheus tidak merespons API"
        fi
      else
        no_award "G" 12 "Tidak bisa mengakses Prometheus API di $PIP:9090"
        echo -e "  ${YELLOW}[MANUAL]${NC} Verifikasi manual: buka http://$PIP:9090/targets"
        echo "  [MANUAL] Verifikasi di: http://$PIP:9090/targets" >> "$REPORT"
      fi
    else
      no_award "G" 17 "Tidak dapat mendapatkan Prometheus task IP"
    fi
  else
    no_award "G" 17 "Tidak ada Prometheus task yang running"
  fi
else
  no_award "G" 22 "Prometheus ECS service tidak running di us-west-2"
fi

section_summary "G" "Prometheus + Peering"

# ═══════════════════════════════════════════════════════════════
# H. CI/CD Pipeline (10 poin)
# ═══════════════════════════════════════════════════════════════
header "H. CI/CD Pipeline" 10 "H"

# Check workflow file exists in repo
[ -f "$(dirname "$0")/../.github/workflows/lks-cicd.yml" ] \
  && award "H" 2 "Workflow file .github/workflows/lks-cicd.yml ada" \
  || no_award "H" 2 "Workflow file tidak ditemukan"

# Check GitHub Actions via CLI
if command -v gh &>/dev/null; then
  RUNS=$(gh run list --limit 5 --json status,conclusion \
    --jq '[.[] | select(.status == "completed" and .conclusion == "success")] | length' \
    2>/dev/null || echo 0)
  [ "${RUNS:-0}" -ge 1 ] \
    && award "H" 5 "GitHub Actions: $RUNS successful run(s) ditemukan" \
    || no_award "H" 5 "Tidak ada successful GitHub Actions run"

  # Check all 4 jobs completed
  LAST_JOBS=$(gh run list --limit 1 --json jobs \
    --jq '.[0].jobs | length' 2>/dev/null || echo 0)
  [ "${LAST_JOBS:-0}" -ge 4 ] \
    && award "H" 3 "Pipeline memiliki $LAST_JOBS jobs (harus 4)" \
    || no_award "H" 3 "Pipeline jobs: $LAST_JOBS (harus 4: install, build_ecr, upload_s3, deploy)"
else
  echo -e "  ${YELLOW}[MANUAL]${NC} gh CLI tidak terinstal — cek pipeline di GitHub secara manual"
  echo "  [MANUAL] Cek pipeline green di github.com" >> "$REPORT"
  # Check that images were pushed (indirect evidence pipeline ran)
  FE_LATEST=$(aws ecr list-images --repository-name lks-fe-app \
    --filter tagStatus=TAGGED --region us-east-1 \
    --query 'length(imageIds)' --output text 2>/dev/null || echo 0)
  [ "${FE_LATEST:-0}" -gt 0 ] \
    && award "H" 5 "ECR images ada — bukti pipeline pernah berjalan ($FE_LATEST image)" \
    || no_award "H" 5 "ECR kosong — pipeline belum berjalan"
  no_award "H" 3 "gh CLI tidak terinstal — tidak dapat verifikasi 4 jobs"
fi

section_summary "H" "CI/CD"

# ═══════════════════════════════════════════════════════════════
# Final Score
# ═══════════════════════════════════════════════════════════════
PCT=$(echo "scale=1; $TOTAL_SCORE * 100 / $TOTAL_MAX" | bc 2>/dev/null || echo "?")

if [ "$TOTAL_SCORE" -ge 95 ];     then GRADE="A"; COLOR=$GREEN
elif [ "$TOTAL_SCORE" -ge 80 ];   then GRADE="B"; COLOR=$CYAN
elif [ "$TOTAL_SCORE" -ge 65 ];   then GRADE="C"; COLOR=$YELLOW
else                                    GRADE="D"; COLOR=$RED
fi

{
  echo ""
  echo "========================================================"
  echo "  FINAL SCORE"
  echo "========================================================"
  printf "  %-30s %s / %s\n" "Total Score:" "$TOTAL_SCORE" "$TOTAL_MAX"
  printf "  %-30s %s%%\n"    "Percentage:" "$PCT"
  printf "  %-30s %s\n"      "Grade:" "$GRADE"
  echo ""
  echo "  Section breakdown:"
  for S in A B C D E F G H; do
    printf "    %s: %s / %s\n" "$S" "${SECTION_SCORE[$S]:-0}" "${SECTION_MAX[$S]:-0}"
  done
  echo ""
  echo "  Siswa    : $STUDENT"
  echo "  Juri     : $(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)"
  echo "  Waktu    : $(date)"
  echo "  Report   : $REPORT"
  echo "========================================================"
} >> "$REPORT"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║              HASIL PENILAIAN JURI               ║${NC}"
echo -e "${BOLD}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}║  Siswa  : $STUDENT${NC}"
echo -e "${BOLD}╠══════════════════════════════════════════════════╣${NC}"
for S in A B C D E F G H; do
  printf "${BOLD}║${NC}  %-2s  %-30s %3s / %-3s  ${BOLD}║${NC}\n" \
    "$S" "" "${SECTION_SCORE[$S]:-0}" "${SECTION_MAX[$S]:-0}"
done
echo -e "${BOLD}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}║  ${COLOR}TOTAL : $TOTAL_SCORE / $TOTAL_MAX poin ($PCT%)  Grade: $GRADE${NC}${BOLD}         ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo -e "  Report: ${CYAN}$REPORT${NC}\n"

cat "$REPORT"
echo -e "\nReport tersimpan: ${CYAN}$REPORT${NC}"
