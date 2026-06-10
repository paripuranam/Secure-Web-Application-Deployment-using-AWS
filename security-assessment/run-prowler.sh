#!/bin/bash
# Prowler CIS Benchmark Assessment Script
# Run after every infrastructure deployment

set -euo pipefail

AWS_PROFILE="${1:-default}"
OUTPUT_DIR="./prowler-report"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "[+] Starting Prowler CIS assessment on profile: $AWS_PROFILE"

mkdir -p "$OUTPUT_DIR"

# Run CIS AWS Foundations Benchmark v2.0
prowler aws \
  --profile "$AWS_PROFILE" \
  --compliance cis_aws_2.0 \
  --output-formats html,csv,json \
  --output-directory "$OUTPUT_DIR" \
  --output-filename "prowler_cis_$TIMESTAMP"

# Run specific high-priority checks
echo "[+] Running critical security checks..."
prowler aws \
  --profile "$AWS_PROFILE" \
  --checks \
    iam_root_mfa_enabled \
    s3_bucket_public_access_block \
    ec2_imdsv2_enabled \
    cloudtrail_multi_region_enabled \
    guardduty_is_enabled \
    securityhub_enabled \
  --output-formats json \
  --output-directory "$OUTPUT_DIR" \
  --output-filename "prowler_critical_$TIMESTAMP"

echo "[+] Report saved to $OUTPUT_DIR"
echo "[+] Open prowler_cis_$TIMESTAMP.html in browser to review findings"
