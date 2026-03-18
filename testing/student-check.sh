#!/usr/bin/env bash
# ============================================================
#  testing/student-check.sh
#  LKS 2026 — Self-Check Script untuk Siswa
#
#  Jalankan setelah semua task selesai:
#    chmod +x testing/student-check.sh
#    ./testing/student-check.sh
#
#  Semua bagian harus PASS sebelum memanggil juri.
# ============================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

PASS=0; FAIL=0; WARN=0
REPORT_FILE="/tmp/lks2026-student-$(date +%Y%m%d-%H%M%S).txt"

pass()  { echo -e "  ${GREEN}[PASS]${NC} $1"; ((PASS++));  echo "[PASS] $1" >> "$REPORT_FILE"; }
fail()  { echo -e "  ${RED}[FAIL]${NC} $1"; ((FAIL++));   echo "[FAIL] $1" >> "$REPORT_FILE"; }
warn()  { echo -e "  ${YELLOW}[WARN]${NC} $1"; ((WARN++)); echo "[WARN] $1" >> "$REPORT_FILE"; }
info()  { echo -e "  ${CYAN}[INFO]${NC} $1";               echo "[INFO] $1" >> "$REPORT_FILE"; }
header(){ echo -e "\n${BOLD}${BLUE}── $1 ──${NC}";         echo -e "\n── $1 ──" >> "$REPORT_FILE"; }

aws_q() {
  # aws_q REGION SERVICE ARGS... --query QUERY
  aws "$@" --output text 2>/dev/null || echo ""
}

echo "LKS 2026 Student Self-Check | $(date)" > "$REPORT_FILE"
echo "======================================" >> "$REPORT_FILE"

echo -e "\n${BOLD}╔════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   LKS 2026 — Student Self-Check       ║${NC}"
echo -e "${BOLD}║   Pastikan semua PASS sebelum selesai  ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════╝${NC}"
echo -e "  Report: ${CYAN}$REPORT_FILE${NC}"

# ── Terraform helper ─────────────────────────────────────────
TF_DIR="$(dirname "$0")/../terraform"
tf_out() { (cd "$TF_DIR" && terraform output -raw "$1" 2>/dev/null) || echo ""; }

# ─────────────────────────────────────────────────────────────
header "A. AWS Credentials"
# ─────────────────────────────────────────────────────────────
IDENTITY=$(aws sts get-caller-identity --output json 2>/dev/null || echo "{}")
ACCT=$(echo "$IDENTITY" | jq -r '.Account // empty' 2>/dev/null)
[ -n "$ACCT" ] \
  && pass "Credentials valid — Account: $ACCT" \
  || fail "Credentials tidak valid atau expired — perbarui secrets di environment"

REGION=$(aws configure get region 2>/dev/null || echo "")
[ "$REGION" = "us-east-1" ] \
  && pass "Default region: us-east-1" \
  || warn "Default region '$REGION' — seharusnya us-east-1"

# ─────────────────────────────────────────────────────────────
header "B. Terraform Outputs"
# ─────────────────────────────────────────────────────────────
VPC_ID=$(tf_out vpc_id)
MON_VPC_ID=$(tf_out monitoring_vpc_id)
PEERING_ID=$(tf_out peering_connection_id)
PEERING_STATUS=$(tf_out peering_connection_status)
ALB_DNS=$(tf_out alb_dns_name)
SG_ECS=$(tf_out sg_ecs_id)
SG_MON=$(tf_out sg_monitoring_id)
TG_FE=$(tf_out tg_fe_arn)
TG_API=$(tf_out tg_api_arn)

[ -n "$VPC_ID" ]      && pass "lks-vpc: $VPC_ID"                       || fail "lks-vpc tidak ada di Terraform output"
[ -n "$MON_VPC_ID" ]  && pass "lks-monitoring-vpc: $MON_VPC_ID"        || fail "lks-monitoring-vpc tidak ada"
[ -n "$PEERING_ID" ]  && pass "VPC Peering ID: $PEERING_ID"             || fail "VPC Peering belum dibuat"
[ "$PEERING_STATUS" = "active" ] \
  && pass "VPC Peering status: active" \
  || fail "VPC Peering status '$PEERING_STATUS' — harus 'active'"
[ -n "$ALB_DNS" ]     && pass "ALB DNS: $ALB_DNS"                       || fail "ALB belum ada"
[ -n "$SG_ECS" ]      && pass "lks-sg-ecs: $SG_ECS"                     || fail "lks-sg-ecs tidak ada"
[ -n "$TG_FE" ]       && pass "Target Group FE: ada"                    || fail "Target Group lks-tg-fe tidak ada"
[ -n "$TG_API" ]      && pass "Target Group API: ada"                   || fail "Target Group lks-tg-api tidak ada"

# ─────────────────────────────────────────────────────────────
header "C. VPC & Networking"
# ─────────────────────────────────────────────────────────────
if [ -n "$VPC_ID" ]; then
  CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" \
    --query 'Vpcs[0].CidrBlock' --output text --region us-east-1 2>/dev/null)
  [ "$CIDR" = "10.0.0.0/16" ] \
    && pass "lks-vpc CIDR: 10.0.0.0/16" \
    || fail "lks-vpc CIDR salah: '$CIDR'"

  SN=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'length(Subnets)' --output text --region us-east-1 2>/dev/null)
  [ "$SN" = "6" ] \
    && pass "lks-vpc: 6 subnet" \
    || fail "lks-vpc: $SN subnet (harus 6)"

  IGW=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query 'length(InternetGateways)' --output text --region us-east-1 2>/dev/null)
  [ "$IGW" = "1" ] \
    && pass "Internet Gateway terpasang" \
    || fail "Internet Gateway tidak ditemukan"

  NAT=$(aws ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
    --query 'NatGateways[0].State' --output text --region us-east-1 2>/dev/null)
  [ "$NAT" = "available" ] \
    && pass "NAT Gateway: available" \
    || fail "NAT Gateway tidak available"
fi

if [ -n "$MON_VPC_ID" ]; then
  MCIDR=$(aws ec2 describe-vpcs --vpc-ids "$MON_VPC_ID" \
    --query 'Vpcs[0].CidrBlock' --output text --region us-west-2 2>/dev/null)
  [ "$MCIDR" = "10.1.0.0/16" ] \
    && pass "lks-monitoring-vpc CIDR: 10.1.0.0/16" \
    || fail "lks-monitoring-vpc CIDR salah: '$MCIDR'"

  MSN=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$MON_VPC_ID" \
    --query 'length(Subnets)' --output text --region us-west-2 2>/dev/null)
  [ "$MSN" = "2" ] \
    && pass "lks-monitoring-vpc: 2 subnet" \
    || fail "lks-monitoring-vpc: $MSN subnet (harus 2)"
fi

# ─────────────────────────────────────────────────────────────
header "D. Inter-Region VPC Peering"
# ─────────────────────────────────────────────────────────────
if [ -n "$PEERING_ID" ]; then
  # Route Virginia → Oregon
  VA_RT=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=lks-private-rt" \
    --query "RouteTables[0].Routes[?DestinationCidrBlock=='10.1.0.0/16'] | length(@)" \
    --output text --region us-east-1 2>/dev/null)
  [ "${VA_RT:-0}" -gt 0 ] \
    && pass "Route 10.1.0.0/16 ada di lks-private-rt (Virginia)" \
    || fail "Route 10.1.0.0/16 TIDAK ada di lks-private-rt — Prometheus tidak bisa scrape"

  # Route Oregon → Virginia
  OR_RT=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$MON_VPC_ID" "Name=tag:Name,Values=lks-monitoring-rt" \
    --query "RouteTables[0].Routes[?DestinationCidrBlock=='10.0.0.0/16'] | length(@)" \
    --output text --region us-west-2 2>/dev/null)
  [ "${OR_RT:-0}" -gt 0 ] \
    && pass "Route 10.0.0.0/16 ada di lks-monitoring-rt (Oregon)" \
    || fail "Route 10.0.0.0/16 TIDAK ada di lks-monitoring-rt"

  # Security Group rule: TCP 9100 from 10.1.0.0/16
  if [ -n "$SG_ECS" ]; then
    RULE=$(aws ec2 describe-security-groups \
      --group-ids "$SG_ECS" \
      --query "SecurityGroups[0].IpPermissions[?FromPort==\`9100\`] \
               .IpRanges[?CidrIp=='10.1.0.0/16'].CidrIp | [0]" \
      --output text --region us-east-1 2>/dev/null)
    [ "$RULE" = "10.1.0.0/16" ] \
      && pass "lks-sg-ecs: TCP 9100 inbound dari 10.1.0.0/16 ✓" \
      || fail "lks-sg-ecs: TIDAK ada rule TCP 9100 dari 10.1.0.0/16 — Prometheus TIDAK bisa scrape!"
  fi
fi

# ─────────────────────────────────────────────────────────────
header "E. ECR Repositories"
# ─────────────────────────────────────────────────────────────
for REPO in lks-fe-app lks-api-app; do
  URI=$(aws ecr describe-repositories \
    --repository-names "$REPO" --region us-east-1 \
    --query 'repositories[0].repositoryUri' --output text 2>/dev/null)
  if [ -n "$URI" ] && [ "$URI" != "None" ]; then
    CNT=$(aws ecr list-images --repository-name "$REPO" \
      --region us-east-1 \
      --query 'length(imageIds)' --output text 2>/dev/null || echo 0)
    [ "${CNT:-0}" -gt 0 ] \
      && pass "ECR $REPO (us-east-1): $CNT image(s)" \
      || warn "ECR $REPO: repository ada tapi KOSONG — jalankan CI/CD"
  else
    fail "ECR $REPO tidak ditemukan di us-east-1 — buat manual"
  fi
done

PURI=$(aws ecr describe-repositories \
  --repository-names lks-prometheus --region us-west-2 \
  --query 'repositories[0].repositoryUri' --output text 2>/dev/null)
if [ -n "$PURI" ] && [ "$PURI" != "None" ]; then
  PCNT=$(aws ecr list-images --repository-name lks-prometheus \
    --region us-west-2 \
    --query 'length(imageIds)' --output text 2>/dev/null || echo 0)
  [ "${PCNT:-0}" -gt 0 ] \
    && pass "ECR lks-prometheus (us-west-2): $PCNT image(s)" \
    || warn "ECR lks-prometheus: kosong — jalankan CI/CD untuk build image"
else
  fail "ECR lks-prometheus tidak ditemukan di us-west-2 — buat manual"
fi

# ─────────────────────────────────────────────────────────────
header "F. ECS Application Cluster (us-east-1)"
# ─────────────────────────────────────────────────────────────
CS=$(aws ecs describe-clusters --clusters lks-ecs-cluster --region us-east-1 \
  --query 'clusters[0].status' --output text 2>/dev/null)
[ "$CS" = "ACTIVE" ] \
  && pass "lks-ecs-cluster: ACTIVE" \
  || fail "lks-ecs-cluster tidak ditemukan atau tidak ACTIVE"

for SVC in lks-fe-service lks-api-service; do
  SS=$(aws ecs describe-services \
    --cluster lks-ecs-cluster --services "$SVC" \
    --query 'services[0].status' --output text --region us-east-1 2>/dev/null)
  RC=$(aws ecs describe-services \
    --cluster lks-ecs-cluster --services "$SVC" \
    --query 'services[0].runningCount' --output text --region us-east-1 2>/dev/null)
  TGH=$(aws ecs describe-services \
    --cluster lks-ecs-cluster --services "$SVC" \
    --query 'services[0].loadBalancers[0].targetGroupArn' --output text --region us-east-1 2>/dev/null)
  if [ "$SS" = "ACTIVE" ] && [ "${RC:-0}" -gt 0 ]; then
    pass "$SVC: ACTIVE, $RC task(s) running"
    [ -n "$TGH" ] && [ "$TGH" != "None" ] \
      && pass "$SVC: terhubung ke Target Group" \
      || warn "$SVC: tidak terhubung ke Target Group — cek listener rules"
  elif [ "$SS" = "ACTIVE" ]; then
    fail "$SVC: ACTIVE tapi 0 task running — cek Task Definition, image, dan logs"
  else
    fail "$SVC tidak ditemukan — buat manual di AWS Console"
  fi
done

# ─────────────────────────────────────────────────────────────
header "G. ALB & Full CRUD Test"
# ─────────────────────────────────────────────────────────────
if [ -n "$ALB_DNS" ]; then
  # Health check API
  HC=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    "http://$ALB_DNS/api/health" 2>/dev/null || echo "000")
  [ "$HC" = "200" ] \
    && pass "ALB → /api/health: HTTP 200" \
    || fail "ALB → /api/health: HTTP $HC"

  # Frontend
  FE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
    "http://$ALB_DNS/" 2>/dev/null || echo "000")
  [ "$FE" = "200" ] \
    && pass "ALB → Frontend /: HTTP 200" \
    || fail "ALB → Frontend /: HTTP $FE"

  # CRUD flow
  TS=$(date +%s)
  CR=$(curl -s --max-time 10 -X POST "http://$ALB_DNS/api/users" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Test Siswa $TS\",\"email\":\"siswa$TS@lks2026.id\",\"institution\":\"SMK LKS\",\"position\":\"Contestant\"}" \
    2>/dev/null || echo "{}")
  USER_ID=$(echo "$CR" | jq -r '.id // empty' 2>/dev/null)
  if [ -n "$USER_ID" ]; then
    pass "CRUD Create: berhasil (ID: $USER_ID)"
    RD=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://$ALB_DNS/api/users/$USER_ID" 2>/dev/null || echo "000")
    [ "$RD" = "200" ] && pass "CRUD Read: 200" || fail "CRUD Read: $RD"
    UP=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -X PUT "http://$ALB_DNS/api/users/$USER_ID" \
      -H "Content-Type: application/json" -d '{"name":"Updated","position":"Winner"}' 2>/dev/null || echo "000")
    [ "$UP" = "200" ] && pass "CRUD Update: 200" || fail "CRUD Update: $UP"
    DL=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -X DELETE "http://$ALB_DNS/api/users/$USER_ID" 2>/dev/null || echo "000")
    [ "$DL" = "200" ] && pass "CRUD Delete: 200" || fail "CRUD Delete: $DL"
  else
    fail "CRUD Create gagal: $CR"
  fi
else
  fail "ALB DNS tidak tersedia — skip HTTP tests"
fi

# ─────────────────────────────────────────────────────────────
header "H. Prometheus & Inter-Region Monitoring (us-west-2)"
# ─────────────────────────────────────────────────────────────
MC=$(aws ecs describe-clusters --clusters lks-monitoring-cluster --region us-west-2 \
  --query 'clusters[0].status' --output text 2>/dev/null)
[ "$MC" = "ACTIVE" ] \
  && pass "lks-monitoring-cluster (us-west-2): ACTIVE" \
  || fail "lks-monitoring-cluster tidak ditemukan di us-west-2"

PS=$(aws ecs describe-services \
  --cluster lks-monitoring-cluster --services lks-prometheus-service \
  --query 'services[0].status' --output text --region us-west-2 2>/dev/null)
PR=$(aws ecs describe-services \
  --cluster lks-monitoring-cluster --services lks-prometheus-service \
  --query 'services[0].runningCount' --output text --region us-west-2 2>/dev/null)

if [ "$PS" = "ACTIVE" ] && [ "${PR:-0}" -gt 0 ]; then
  pass "lks-prometheus-service: ACTIVE, $PR task(s) running"

  # Get task IP
  PTASK=$(aws ecs list-tasks \
    --cluster lks-monitoring-cluster --service-name lks-prometheus-service \
    --query 'taskArns[0]' --output text --region us-west-2 2>/dev/null)
  if [ -n "$PTASK" ] && [ "$PTASK" != "None" ]; then
    PIP=$(aws ecs describe-tasks --cluster lks-monitoring-cluster \
      --tasks "$PTASK" --region us-west-2 \
      --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value | [0]' \
      --output text 2>/dev/null)
    info "Prometheus private IP: ${PIP:-tidak tersedia}"

    # Try to hit Prometheus API (only works if runner has network access)
    if [ -n "${PIP:-}" ] && [ "$PIP" != "None" ]; then
      TH=$(curl -s --max-time 5 \
        "http://$PIP:9090/api/v1/targets" 2>/dev/null \
        | jq -r '[.data.activeTargets[] | select(.labels.job != "prometheus") | .health] | unique | .[]' \
        2>/dev/null | paste -sd ',' || echo "")
      if echo "$TH" | grep -q "up"; then
        pass "Prometheus targets UP — INTER-REGION PEERING TERBUKTI BERFUNGSI!"
      else
        info "Tidak dapat mengakses Prometheus API dari luar VPC"
        info "Verifikasi manual: buka http://$PIP:9090/targets di browser"
        info "Semua target harus berstatus UP"
        warn "Prometheus berjalan tapi target belum bisa diverifikasi otomatis dari luar VPC"
      fi
    fi
  fi
else
  fail "lks-prometheus-service belum running — deploy ke lks-monitoring-cluster us-west-2"
fi

# ─────────────────────────────────────────────────────────────
header "I. GitHub Actions"
# ─────────────────────────────────────────────────────────────
if command -v gh &>/dev/null; then
  LAST=$(gh run list --limit 1 \
    --json status,conclusion,displayTitle \
    --jq '.[0] | "\(.displayTitle) | \(.status) | \(.conclusion)"' 2>/dev/null || echo "N/A")
  info "Last run: $LAST"
  echo "$LAST" | grep -q "completed.*success" \
    && pass "GitHub Actions: last run succeeded" \
    || warn "GitHub Actions: $LAST"
else
  warn "gh CLI tidak terinstal — cek pipeline di github.com/$(git remote get-url origin 2>/dev/null | sed 's|.*github.com/||' | sed 's|\.git||')"
fi

# ─────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL + WARN))
{
  echo ""; echo "=============================="
  echo "PASS: $PASS | FAIL: $FAIL | WARN: $WARN | TOTAL: $TOTAL"
} >> "$REPORT_FILE"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${NC}"
printf "${BOLD}║${NC}  %-36s${BOLD}║${NC}\n" "PASS : $PASS / $TOTAL"
printf "${BOLD}║${NC}  ${RED}%-36s${BOLD}║${NC}\n" "FAIL : $FAIL"
printf "${BOLD}║${NC}  ${YELLOW}%-36s${BOLD}║${NC}\n" "WARN : $WARN"
echo -e "${BOLD}╠══════════════════════════════════════╣${NC}"
if [ "$FAIL" -eq 0 ]; then
  echo -e "${BOLD}║  ${GREEN}SIAP — Panggil juri sekarang! ✓       ${BOLD}║${NC}"
else
  echo -e "${BOLD}║  ${RED}Ada $FAIL masalah — perbaiki dulu!      ${BOLD}║${NC}"
fi
echo -e "${BOLD}╚══════════════════════════════════════╝${NC}"
echo -e "  Report: ${CYAN}$REPORT_FILE${NC}\n"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
