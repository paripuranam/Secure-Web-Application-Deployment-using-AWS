# AWS 3-Tier Architecture with Terraform

This repository contains **Infrastructure as Code (IaC)** using Terraform to deploy a production-grade, highly available, and secure three-tier web architecture on AWS.

It automates the creation of a Virtual Private Cloud (VPC), Application Load Balancer (ALB) protected by WAF, Auto Scaling EC2 instances, and a Multi-AZ RDS database.

## 🏗 Architecture Overview

This Terraform configuration deploys the following resources:

  * **Networking**: A custom VPC with Public and Private subnets across 2 Availability Zones.
  * **Security**:
      * **AWS WAF** (Web Application Firewall) attached to the ALB.
      * **Security Groups** with strict chaining (ALB -\> App -\> DB).
      * **Bastion Host** for secure SSH access to private instances.
  * **Compute (App Tier)**: An Auto Scaling Group (ASG) of EC2 instances running Amazon Linux 2023, located in private subnets.
  * **Database (Data Tier)**: Amazon RDS MySQL in a Multi-AZ deployment for high availability.
  * **Load Balancing**: An Application Load Balancer (ALB) handling traffic distribution and health checks.
  * **DNS**: Automated Route 53 record creation (via `dns.tf`).
  * **Monitoring**: IAM roles configured for CloudWatch logging.

## 📂 Repository Structure

| File | Description |
| :--- | :--- |
| `provider.tf` | Configures the AWS Provider. |
| `vpc.tf` | Creates VPC, Subnets, Internet Gateway, NAT Gateways, and Route Tables. |
| `security_groups.tf`| Defines Security Groups and rules for traffic flow control. |
| `waf.tf` | Sets up the Web Application Firewall and associates it with the ALB. |
| `alb.tf` | Configures the Application Load Balancer, Target Groups, and Listeners. |
| `compute.tf` | Defines the Bastion Host, Launch Templates, and Auto Scaling Group. |
| `database.tf` | Provisions the RDS MySQL Multi-AZ instance. |
| `iam.tf` | Sets up IAM roles for EC2 to communicate with CloudWatch. |
| `cloudwatch.tf` | Creates Log Groups for application logging. |
| `dns.tf` | **(Included)** Manages Route 53 DNS records for the domain. |
| `variables.tf` | Declares input variables used across the project. |
| `outputs.tf` | Defines useful outputs (ALB DNS name, Bastion IP, etc.) displayed after deployment. |

## 🚀 Getting Started

### Prerequisites

  * [Terraform](https://www.terraform.io/downloads.html) v1.0+ installed.
  * [AWS CLI](https://aws.amazon.com/cli/) installed and configured with appropriate permissions.
  * An active AWS Account.
  * A registered domain name in **AWS Route 53** (required for `dns.tf`).

### 1\. Clone the Repository

```bash
[git clone https://github.com/paripuranam/Secure-Web-Application-Deployment-using-AWS.git
cd aws-terraform-3tier
```

### 2\. Configure Variables (`terraform.tfvars`)

Create a file named `terraform.tfvars` in the root directory to store your custom configurations and secrets.

> **⚠️ Security Warning:** Never commit `terraform.tfvars` to version control if it contains real passwords or keys.

**Example `terraform.tfvars`:**

```hcl
# Region to deploy into
aws_region    = "us-east-1" 

# Your personal Public IP (CIDR format) for secure SSH access
# You can find this by searching "what is my ip" on Google
my_ip_address = "YOUR_PUBLIC_IP"

# Database Credentials
db_username   = "adminuser"
db_password   = "ChangeThisToAStrongPassword123!"

# Route 53 Configuration
# Ensure this domain exists in your Route 53 Hosted Zones
domain_name   = "yourdomain.com"
```

### 3\. Initialize Terraform

Download the required providers and initialize the backend.

```bash
terraform init
```

### 4\. Review the Plan

Generate a specific plan to see exactly what resources will be created.

```bash
terraform plan -out=tfplan
```

### 5\. Deploy Infrastructure

Apply the plan to create resources in AWS.

```bash
terraform apply tfplan
```

*Type `yes` if prompted (unless using the plan file directly).*

## 🔍 Verifying the Deployment

Once the `apply` is complete, Terraform will output the following values:

  * `alb_dns_name`: The raw URL of your Load Balancer.
  * `bastion_public_ip`: The IP address to SSH into the Bastion Host.
  * `rds_endpoint`: The internal address of your database.

**To test the web application:**

1.  Wait 3-5 minutes for the Auto Scaling Group to launch instances and for Health Checks to pass.
2.  Open your browser and navigate to `http://www.example.com` (configured in `dns.tf`) or the `alb_dns_name`.
3.  You should see the "Hello from App Tier" welcome message.

## 🧹 Clean Up

To avoid ongoing charges for resources (NAT Gateways, EC2, RDS), destroy the infrastructure when you are finished.

```bash
terraform destroy
```

## ⚠️ Important Notes

  * **Costs:** This architecture uses resources that fall outside the AWS Free Tier (e.g., NAT Gateways, Multi-AZ RDS). **You will be charged** for these resources while they are running.
  * **State Management:** By default, the state file (`terraform.tfstate`) is stored locally. For production use, configure a remote backend (like S3 + DynamoDB).
  * **Security:** The provided user data script installs a basic Apache server for demonstration. In a real scenario, use a hardened AMI or configuration management tool (Ansible/Chef).
