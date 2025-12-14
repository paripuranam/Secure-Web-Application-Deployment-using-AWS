This README provides a step-by-step guide to deploying the architecture manually using the **AWS Management Console**. This is excellent for educational purposes or for users who prefer "ClickOps" over Infrastructure as Code.

-----

# Manual Deployment Guide (AWS Management Console)

This guide walks you through building the **Secure 3-Tier Web Architecture** manually using the AWS Console. This process helps you understand how the components (VPC, ALB, ASG, RDS, WAF) connect to each other.

## 📋 Prerequisites

  * An active AWS Account.
  * Region: Select **US East (N. Virginia) us-east-1** (or your preferred region) in the top right corner.
  * Time required: Approx. 45-60 minutes.

-----

## Step 1: Network Foundation (VPC)

1.  Navigate to the **VPC Dashboard**.
2.  Click **Create VPC**.
3.  Select **VPC and more** (this is the "VPC Wizard").
      * **Name tag:** `aws-ha-webapp`
      * **IPv4 CIDR block:** `10.0.0.0/16`
      * **Availability Zones (AZs):** Select **2** (e.g., us-east-1a, us-east-1b).
      * **Number of public subnets:** **2**
      * **Number of private subnets:** **4** (2 for App Tier, 2 for DB Tier).
      * **NAT gateways:** **1 per AZ** (Select "2 AZs" for High Availability).
      * **VPC endpoints:** None.
4.  Click **Create VPC**.
      * *Note: This automatically creates the Internet Gateway, NAT Gateways, and Route Tables shown in the architecture diagram.*

-----

## Step 2: Security Groups (The Firewall)

Go to **VPC \> Security Groups** and create the following groups. **Create them in this order** so you can reference them.

### 1\. ALB Security Group

  * **Name:** `ALB-SG`
  * **VPC:** Select `aws-ha-webapp-vpc`
  * **Inbound Rules:**
      * Type: **HTTP** | Source: **Anywhere-IPv4** (`0.0.0.0/0`)
  * **Outbound Rules:** Leave default (Allow All).

### 2\. Bastion Security Group

  * **Name:** `Bastion-SG`
  * **Inbound Rules:**
      * Type: **SSH** | Source: **My IP** (Select "My IP" from the dropdown to auto-fill your IP).

### 3\. App Tier Security Group

  * **Name:** `App-Tier-SG`
  * **Inbound Rules:**
      * Type: **HTTP** | Source: Custom -\> Select **ALB-SG**.
      * Type: **SSH** | Source: Custom -\> Select **Bastion-SG**.

### 4\. Database Security Group

  * **Name:** `DB-SG`
  * **Inbound Rules:**
      * Type: **MySQL/Aurora** | Source: Custom -\> Select **App-Tier-SG**.
      * Type: **MySQL/Aurora** | Source: Custom -\> Select **Bastion-SG**.

-----

## Step 3: Data Tier (RDS Database)

1.  Navigate to **RDS \> Subnet groups**.
      * Create a new group named `db-subnet-group`.
      * Select your VPC.
      * Add the **two Private DB subnets** created in Step 1 (usually the last two in the list).
2.  Navigate to **RDS \> Databases \> Create database**.
      * **Creation method:** Standard create.
      * **Engine:** MySQL.
      * **Template:** Production (or Dev/Test to save money).
      * **Availability & durability:** Select **Multi-AZ DB instance** (This creates the standby replica).
      * **Settings:**
          * DB identifier: `webapp-db`
          * Username: `admin`
          * Password: *[Create a strong password]*
      * **Instance configuration:** Select `Burstable classes` -\> `db.t3.micro`.
      * **Connectivity:**
          * VPC: `aws-ha-webapp-vpc`
          * Subnet group: `db-subnet-group`
          * Public access: **No**
          * Security group: Choose existing -\> Select **DB-SG**.
3.  Click **Create database**.

-----

## Step 4: Compute Tier (Launch Template & ASG)

### A. Create Launch Template

1.  Navigate to **EC2 \> Launch Templates \> Create launch template**.
2.  **Name:** `App-Launch-Template`.
3.  **AMI:** Select **Amazon Linux 2023**.
4.  **Instance type:** `t3.micro`.
5.  **Key pair:** Select an existing key (or create one).
6.  **Network settings:**
      * **Security groups:** Select **App-Tier-SG**.
7.  **Advanced details \> User Data:** Paste the following script to simulate the app:
    ```bash
    #!/bin/bash
    dnf update -y
    dnf install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from the Secure App Tier!</h1>" > /var/www/html/index.html
    ```
8.  Click **Create launch template**.

### B. Create Auto Scaling Group (ASG)

1.  Navigate to **EC2 \> Auto Scaling Groups \> Create Auto Scaling group**.
2.  **Name:** `App-ASG`.
3.  **Launch Template:** Select `App-Launch-Template`.
4.  **Network:**
      * VPC: `aws-ha-webapp-vpc`
      * Subnets: Select the **two Private App subnets**.
5.  **Load Balancing:**
      * Select **Attach to a new load balancer**.
      * Type: **Application Load Balancer**.
      * Load balancer name: `Web-ALB`.
      * Scheme: **Internet-facing**.
      * Subnets: Select the **two Public subnets** (Important\!).
      * Listeners: Create a listener on Port 80.
      * Default Action: Create a target group named `App-Target-Group`.
6.  **Group size:**
      * Desired: 2 | Minimum: 2 | Maximum: 4
7.  **Scaling policies:** Select "Target tracking scaling policy" (Target CPU 50%).
8.  Review and click **Create Auto Scaling group**.

-----

## Step 5: Edge Security (WAF)

1.  Navigate to **WAF & Shield \> Web ACLs**.
2.  Click **Create web ACL**.
      * **Name:** `Web-Protection-ACL`.
      * **Resource type:** Regional resources.
      * **Region:** us-east-1.
      * **Associated AWS resources:** Click "Add AWS resources" and select the **Web-ALB** created in Step 4.
3.  **Add rules:**
      * Select **Add managed rule groups**.
      * Vendor: AWS managed rule groups.
      * Add **Core rule set** (protects against common vulnerabilities).
      * Add **SQL database** (protects against SQL injection).
4.  Finish the wizard (Default Action: Allow).

-----

## Step 6: Bastion Host (Optional)

1.  Navigate to **EC2 \> Instances \> Launch instances**.
2.  **Name:** `Bastion-Host`.
3.  **OS:** Amazon Linux 2023.
4.  **Network settings:**
      * Network: `aws-ha-webapp-vpc`
      * Subnet: Select a **Public Subnet**.
      * Auto-assign Public IP: **Enable**.
      * Security Group: Select **Bastion-SG**.
5.  Launch.

-----

## Step 7: Verify the Deployment

1.  Go to **EC2 \> Load Balancers**.
2.  Select `Web-ALB`.
3.  Copy the **DNS name** (e.g., `Web-ALB-12345.us-east-1.elb.amazonaws.com`).
4.  Paste it into your browser.
5.  **Result:** You should see **"Hello from the Secure App Tier\!"**.

**Congratulations\!** You have manually deployed a secure, scalable, multi-AZ architecture on AWS.
