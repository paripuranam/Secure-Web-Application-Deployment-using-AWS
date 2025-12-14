variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project identifier for resource naming"
  type        = string
  default     = "aws-ha-webapp"
}

variable "environment" {
  description = "Environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

// *** SENSITIVE/SPECIFIC VARIABLES - MUST BE SET IN tfvars ***

variable "my_ip_address" {
  description = "Your public IP address in CIDR format for SSH access to Bastion (e.g., 1.2.3.4/32)"
  type        = string
  # No default for security reasons.
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  sensitive   = true
  # No default for security reasons.
}

variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
  # No default for security reasons.
}

variable "domain_name" {
  description = "Existing Route53 Domain Name to create the A record in (e.g., example.com)"
  type        = string
  # Leave blank if you don't use dns.tf
}
