# Secure Web Application Deployment on AWS

Defense-in-depth, three-tier AWS architecture with WAF-enforced access 
control, SSL/TLS termination, automated security assessment, 
and full monitoring pipeline — infrastructure as code with Terraform.

![Architecture](Arch-aws.png)

---

## Architecture
Internet
│
▼
AWS WAF (Web ACL)
├── Rule 1: Block non-India geolocation
├── Rule 2: Block DELETE, PUT methods
└── Rule 3: Rate limit — 2000 req/5min per IP
│
▼
Application Load Balancer (HTTPS:443 only)
│   ACM SSL Certificate (paripoornam.tech)
│   Route 53 DNS → ALB
│
▼
EC2 Instances (Private Subnet)
│   Amazon Linux 2023 / t2.micro
│   Apache httpd, no public IP
│
▼
Bastion Host (Public Subnet)
│   SSH access only from admin IP
│   Port 22 restricted to specific CIDR
│
▼
Security Monitoring
├── AWS GuardDuty    — threat detection
├── AWS Inspector    — vulnerability scanning
└── CloudWatch Logs  — WAF + ALB access logs

---

## Security Design Decisions

| Decision | Implementation | Reason |
|---|---|---|
| No direct EC2 internet access | Private subnets only | Eliminates direct attack surface |
| Single ingress point | ALB only | All traffic inspected by WAF before reaching app |
| HTTPS enforcement | ACM + ALB listener redirect HTTP→HTTPS | Encrypts data in transit, eliminates downgrade attacks |
| Geolocation filtering | WAF rule: Allow IN only | Reduces attack surface to expected user geography |
| HTTP method filtering | WAF rule: Allow GET/POST, Block DELETE/PUT | Prevents API abuse and destructive operations |
| Rate limiting | WAF: 2000 requests/5min per IP | Mitigates DDoS and brute-force attempts |
| Bastion host pattern | SSH only via bastion, key-pair auth | No password auth, auditable access path |
| Security posture scanning | ScoutSuite + Prowler on deploy | Automated CIS benchmark validation post-provisioning |

---

## WAF Rules Implemented

### Rule 1 — Geolocation Filtering
Allows only traffic from India (IN). All other countries blocked.

```json
{
  "Name": "AllowIndiaOnly",
  "Priority": 1,
  "Action": { "Block": {} },
  "Statement": {
    "NotStatement": {
      "Statement": {
        "GeoMatchStatement": {
          "CountryCodes": ["IN"]
        }
      }
    }
  },
  "VisibilityConfig": {
    "SampledRequestsEnabled": true,
    "CloudWatchMetricsEnabled": true,
    "MetricName": "AllowIndiaOnly"
  }
}
```

### Rule 2 — HTTP Method Restriction
Allows GET and POST. Blocks DELETE, PUT, PATCH.

```json
{
  "Name": "BlockDestructiveMethods",
  "Priority": 2,
  "Action": { "Block": {} },
  "Statement": {
    "OrStatement": {
      "Statements": [
        {
          "ByteMatchStatement": {
            "SearchString": "DELETE",
            "FieldToMatch": { "Method": {} },
            "TextTransformations": [{ "Priority": 0, "Type": "NONE" }],
            "PositionalConstraint": "EXACTLY"
          }
        },
        {
          "ByteMatchStatement": {
            "SearchString": "PUT",
            "FieldToMatch": { "Method": {} },
            "TextTransformations": [{ "Priority": 0, "Type": "NONE" }],
            "PositionalConstraint": "EXACTLY"
          }
        }
      ]
    }
  }
}
```

### WAF Block Evidence (Real Log)
Actual WAF log showing a DELETE request blocked in production:

```json
{
  "timestamp": 1732538254916,
  "terminatingRuleId": "blocked_DELETE_PUT",
  "action": "BLOCK",
  "httpRequest": {
    "clientIp": "14.195.33.10",
    "country": "IN",
    "httpMethod": "DELETE",
    "uri": "/"
  }
}
```
*DELETE request from 14.195.33.10 (India) — blocked by Rule 2 at the WAF layer before reaching ALB.*

---

## Security Assessment

### ScoutSuite — AWS Misconfiguration Detection
```bash
# Install
git clone https://github.com/nccgroup/ScoutSuite.git
cd ScoutSuite && pip install -r requirements.txt

# Run against your AWS account
python scout.py aws --profile <your-aws-profile>

# Output: HTML report in scoutsuite-report/
```

### Prowler — CIS Benchmark Scanning
```bash
# Install
git clone https://github.com/prowler-cloud/prowler
cd prowler

# Run all CIS checks
./prowler aws --profile <your-aws-profile> \
  --compliance cis_aws_2.0 \
  --output-formats html,csv \
  --output-directory ./prowler-report

# Run specific checks
./prowler aws -c check11,check12,check13
```

### Key Findings Remediated

| Finding | Severity | Remediation |
|---|---|---|
| S3 bucket public access enabled | HIGH | Enabled S3 Block Public Access |
| Security group allows 0.0.0.0/0 on SSH | HIGH | Restricted to bastion host IP only |
| EC2 instance metadata IMDSv1 enabled | MEDIUM | Enforced IMDSv2 (session-oriented) |
| CloudTrail not enabled in all regions | MEDIUM | Enabled multi-region trail |
| Root account MFA not enabled | CRITICAL | Enabled MFA on root |
| EBS volumes not encrypted | MEDIUM | Enabled EBS default encryption |

---

## SSL/TLS Configuration

- **Certificate:** AWS Certificate Manager (ACM) — public certificate
- **Domain:** paripoornam.tech
- **DNS:** Route 53 hosted zone → ALB A record
- **Protocol:** TLS 1.2 minimum (ALB security policy)
- **Validation:** Qualys SSL Labs — Grade A
ALB Listener: HTTPS:443 → Forward to Target Group
ALB Listener: HTTP:80  → Redirect to HTTPS:443 (301)

---

## Monitoring Stack

| Service | What It Monitors | Alert Condition |
|---|---|---|
| AWS WAF + CloudWatch | WAF rule matches, blocked requests | >100 blocks/5min |
| Amazon GuardDuty | Threats: port scans, C2 traffic, crypto mining | Any HIGH/CRITICAL finding |
| AWS Inspector | EC2 CVEs, network exposure | CRITICAL CVE detected |
| CloudWatch Logs | ALB access logs, WAF full logs | Error rate >5% |

---

## Terraform Deployment

```bash
# Clone the repo
git clone https://github.com/paripuranam/Secure-Web-Application-Deployment-using-AWS
cd Secure-Web-Application-Deployment-using-AWS/terraform

# Initialise
terraform init

# Preview changes
terraform plan -var-file="terraform.tfvars"

# Deploy
terraform apply -var-file="terraform.tfvars"

# Destroy when done
terraform destroy -var-file="terraform.tfvars"
```

### Resources Provisioned by Terraform
- VPC with public/private subnets across 2 AZs
- Internet Gateway + NAT Gateway
- Security Groups (ALB, EC2, Bastion, RDS)
- Network ACLs (private subnet lockdown)
- Application Load Balancer + Target Group
- WAF Web ACL with 3 rules (geo, method, rate-limit)
- CloudWatch Log Group for WAF logs
- GuardDuty detector
- AWS Inspector assessment target

---

## Repository Structure
├── terraform/              Infrastructure as Code
│   ├── main.tf             Provider, backend config
│   ├── vpc.tf              VPC, subnets, IGW, NAT GW
│   ├── security-groups.tf  SG rules for ALB, EC2, bastion
│   ├── alb.tf              ALB, target group, listeners
│   ├── waf.tf              WAF Web ACL and rules
│   ├── cloudwatch.tf       Log groups, alarms
│   ├── variables.tf        Input variables
│   └── outputs.tf          Output values
├── waf-rules/              WAF rule JSON definitions
├── security-assessment/    ScoutSuite + Prowler scripts
│   └── remediation/        Automated remediation scripts
├── monitoring/             CloudWatch alarm definitions
├── docs/                   Evidence, design decisions
└── Manual_deployment/      Step-by-step console guide

---

## Skills Demonstrated

- **Defense-in-depth architecture** — layered security at network, application, and data layers
- **AWS WAF** — custom rules for geolocation, HTTP method filtering, rate limiting
- **IaC with Terraform** — entire infrastructure provisioned as code
- **CSPM** — ScoutSuite + Prowler CIS benchmark scanning with finding remediation
- **SSL/TLS** — ACM certificate, HTTPS enforcement, Route 53 DNS
- **Security monitoring** — GuardDuty, Inspector, CloudWatch integrated pipeline
- **Security engineering judgment** — design decisions documented with reasoning

---
