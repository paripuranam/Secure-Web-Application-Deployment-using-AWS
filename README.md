# Secure-Web-Application-Deployment-using-AWS

Reference architecture for a highly available, scalable, and secure three-tier web application on AWS. Features a custom VPC with public/private subnet isolation, AWS WAF, Application Load Balancing (ALB), Auto Scaling EC2 compute tier, and Multi-AZ RDS.
---
# Detailed AWS Scalable & Secure Web Architecture

[<img width="2816" height="1536" alt="Arch-aws" src="https://github.com/user-attachments/assets/8c732b22-c32c-49e9-bcd6-8fb88f8ee866" />
](https://github.com/paripuranam/Secure-Web-Application-Deployment-using-AWS/blob/main/Arch-aws.png)

## 1. Executive Summary

This infrastructure is designed to host a mission-critical web application. It decouples the public interface from the application logic and the data storage layer. By leveraging multiple Availability Zones (AZs) and managed services like RDS and Auto Scaling, the architecture ensures that the application can sustain the loss of an entire data center or a sudden spike in user traffic without downtime.

---

## 2. Network Infrastructure (VPC & Subnets)

The foundation is a **Virtual Private Cloud (VPC)** configured with the CIDR block `10.0.0.0/16`, providing a private, isolated network environment within the AWS cloud.

### A. Multi-AZ Design for High Availability
Although not explicitly labeled as "Zone A" and "Zone B," the architecture implies the use of at least two **Availability Zones (AZs)**. AZs are physically separate data centers within a single AWS Region.
* *Private Subnet 1* resides in AZ 1.
* *Private Subnet 2* resides in AZ 2.
By spreading resources across these subnets, the application survives if one AZ fails.

### B. Subnet Segregation Strategy
The network is divided into public and private tiers to minimize the attack surface.

#### **Public Subnet (The "DMZ")**
* **Purpose:** Hosts resources that *must* be directly reachable from the internet.
* **Connectivity:** This subnet has an associated Route Table containing a route to an **Internet Gateway (IGW)** (implicit in the diagram).
* **Resources:**
    * **Bastion Host:** The single, secured entry point for system administrators.
    * **(Implicit) Load Balancer Nodes:** The Application Load Balancer places network interfaces in the public subnets to accept incoming traffic.
    * **(Implicit) NAT Gateway:** Although not drawn, a production architecture would include a NAT Gateway here to allow private instances outbound internet access for OS updates or external API calls.

#### **Private Subnets (The "Trusted Zone")**
* **Purpose:** Hosts the core application logic and databases. These subnets have **zero** direct ingress paths from the public internet.
* **Connectivity:** Their Route Tables do *not* have a route to an IGW. They can only be reached via the ALB (for web traffic) or the Bastion Host (for administration).
* **Resources:**
    * **EC2 Instances (App Tier):** Servers running the application code.
    * **RDS Instances (Data Tier):** The databases.

---

## 3. Traffic Ingress & Security Flow (Layer 7)

The "Front Door" of the application handles DNS, security filtering, and traffic distribution before requests ever touch an application server.

### Step 1: DNS Resolution (Route 53)
**Amazon Route 53** acts as the highly available DNS service. It translates the user's friendly domain name (e.g., `www.myapp.com`) into the DNS name of the Application Load Balancer.

### Step 2: Edge Security (AWS WAF)
Before reaching the load balancer, traffic is inspected by the **AWS Web Application Firewall (WAF)**.
* **Function:** WAF operates at Layer 7 (Application Layer). It inspects incoming HTTP/HTTPS requests against defined rules.
* **Protection:** It blocks malicious traffic patterns such as SQL Injection (SQLi), Cross-Site Scripting (XSS), and known bad bot IP addresses.
* **Integration:** The WAF is associated directly with the Application Load Balancer.

### Step 3: Traffic Distribution (Application Load Balancer - ALB)
The **ALB** is the single point of entry for legitimate user traffic.
* **SSL Termination:** The ALB typically handles HTTPS decryption, offloading this CPU-intensive task from the backend EC2 instances.
* **Routing:** It distributes incoming requests evenly across healthy EC2 instances in both Private Subnet 1 and Private Subnet 2.
* **Health Checks:** The ALB continuously pings the backend EC2 instances on a specific port/path. If an instance fails a check, the ALB stops sending it traffic.

---

## 4. The Compute Tier (Auto Scaling)

The application layer is designed to be stateless and elastic.

### Auto Scaling Group (ASG)
The box labeled "Auto Scaling Group" that spans both private subnets is the engine for elasticity and self-healing.
* **Spanning AZs:** The ASG is configured to launch instances into both Private Subnet 1 and Private Subnet 2, ensuring capacity is balanced across data centers.
* **Dynamic Scaling (Elasticity):**
    * *Scale Out:* CloudWatch alarms monitor metrics (e.g., Average CPU utilization hits 70%). The ASG is triggered to launch new EC2 instances and automatically register them with the ALB to handle the load.
    * *Scale In:* When demand drops (e.g., CPU drops below 30%), the ASG terminates excess instances to save costs.
* **Self-Healing:** If an EC2 instance crashes due to hardware failure or software error, the ASG detects the health check failure and automatically launches a replacement instance.

---

## 5. The Data Persistence Tier (RDS)

The database layer uses **Amazon RDS (Relational Database Service)** for managed, highly available storage.

### RDS Multi-AZ Deployment
The diagram shows RDS icons in both private subnets connected by arrows. This represents a **Multi-AZ deployment**.
* **Primary Instance:** In one subnet (e.g., Subnet 1), there is the Primary RDS instance which handles all Read and Write traffic.
* **Standby Replica:** In the other subnet (e.g., Subnet 2), there is a synchronous Standby replica. **No application traffic goes here normally.**
* **Automatic Failover:** If the Primary instance fails or its AZ goes offline, RDS automatically fails over to the Standby replica, promoting it to Primary within a minute or two, usually without requiring changes to the application connection string.

---

## 6. Operational Management & Monitoring

### Secure Administration (Bastion Host)
Because the application servers are private, administrators cannot SSH/RDP directly to them.
* **The Jump Box:** The Bastion Host is a hardened EC2 instance in the Public Subnet. Admins first establish a secure connection to the Bastion, and from there, they "jump" to the private EC2 or RDS instances using internal IP addresses.
* **Security Best Practice:** The Bastion's Security Group should only allow inbound SSH/RDP traffic from specific, whitelisted administrator IP addresses (like a corporate VPN office IP).

### Monitoring & Observability (CloudWatch)
**Amazon CloudWatch** is the central nervous system for collecting data.
* **WAF Logs:** WAF sends logs of allowed and blocked requests to CloudWatch for security analysis.
* **EC2 & System Logs:** The EC2 instances (likely via the CloudWatch Agent) send OS logs and application logs to CloudWatch Logs for centralized troubleshooting.
* **Metrics:** CloudWatch collects numerical data (CPU, Memory, Network I/O, Database connections) from EC2, RDS, and the ALB to drive dashboards and trigger Auto Scaling alarms.

---

## 7. Critical Implicit Security (Security Groups)

While not explicitly drawn as boxes, this architecture relies heavily on **Security Groups (virtual stateful firewalls)** to enforce tight control between components. The flow works via "chaining":

1.  **ALB Security Group:** Allows Inbound HTTPS (443) from the Internet (`0.0.0.0/0`).
2.  **App Tier (EC2) Security Group:** Allows Inbound HTTP (e.g., port 80 or 8080) **only** from the *ALB Security Group ID*. (It does not allow internet traffic directly).
3.  **Data Tier (RDS) Security Group:** Allows Inbound DB traffic (e.g., port 3306 for MySQL) **only** from the *App Tier Security Group ID*.

---

## 8. Deployment via Terraform (Infrastructure as Code)
This entire architecture is defined as code in the terraform/ directory. You can deploy this exact infrastructure to your AWS account in minutes using the provided Terraform scripts.

Quick Start Guide
1. Navigate to the Terraform Directory:

```
cd terraform
```
2. Configure Secrets: Create a terraform.tfvars file (do not commit this) to set your sensitive variables:
```
# terraform.tfvars
aws_region    = "us-east-1"
my_ip_address = "YOUR_PUBLIC_IP/32" # For Bastion SSH access
db_password   = "YourStrongPassword!"
Initialize and Deploy:
```
```
# Initialize the working directory
terraform init

# Preview the changes
terraform plan -out=tfplan

# Apply the changes to AWS
terraform apply tfplan
```
For a detailed breakdown of the .tf files and input variables, please refer to the Terraform https://github.com/paripuranam/Secure-Web-Application-Deployment-using-AWS/blob/main/terraform/README.md located inside the terraform folder.
