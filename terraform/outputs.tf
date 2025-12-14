output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "bastion_public_ip" {
  description = "Public IP of the Bastion Host"
  value       = aws_instance.bastion.public_ip
}

output "rds_endpoint" {
  description = "RDS Endpoint address"
  value       = aws_db_instance.default.address
}
