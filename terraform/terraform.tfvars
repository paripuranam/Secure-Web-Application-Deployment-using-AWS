# terraform.tfvars
aws_region    = "us-east-1" # preferred region
my_ip_address = "YOUR.PUBLIC.IP.ADDRESS/32" # e.g., 123.45.67.89/32. Find it by Googling "what is my ip"

db_username   = "adminuser"
db_password   = "StrongSecretPassw0rd123!" # Make this strong

# Optional: If you use dns.tf
domain_name = "yourdomain.com."
