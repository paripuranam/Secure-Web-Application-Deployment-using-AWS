#!/bin/bash
# Enforce IMDSv2 on all EC2 instances in the account
# Fixes: ec2_imdsv2_enabled Prowler finding

set -euo pipefail

AWS_PROFILE="${1:-default}"
AWS_REGION="${2:-ap-southeast-1}"

echo "[+] Enforcing IMDSv2 on all EC2 instances..."
echo "[+] Profile: $AWS_PROFILE | Region: $AWS_REGION"

# Get all running instance IDs
INSTANCES=$(aws ec2 describe-instances \
  --profile "$AWS_PROFILE" \
  --region "$AWS_REGION" \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)

if [ -z "$INSTANCES" ]; then
  echo "[-] No running instances found"
  exit 0
fi

for INSTANCE_ID in $INSTANCES; do
  echo "[*] Enforcing IMDSv2 on: $INSTANCE_ID"
  aws ec2 modify-instance-metadata-options \
    --profile "$AWS_PROFILE" \
    --region "$AWS_REGION" \
    --instance-id "$INSTANCE_ID" \
    --http-tokens required \
    --http-endpoint enabled \
    --http-put-response-hop-limit 1
  echo "[+] Done: $INSTANCE_ID"
done

echo "[+] IMDSv2 enforced on all instances"
