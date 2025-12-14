# Subnet group for RDS to know which subnets to use
resource "aws_db_subnet_group" "default" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private_db[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "default" {
  identifier             = "${var.project_name}-rds"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp3"
  db_name                = "myappdb"
  username               = var.db_username
  password               = var.db_password
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.default.name
  multi_az               = true  # Enables HA mirroring to standby in different AZ
  skip_final_snapshot    = true  # set to false for prod

  tags = {
    Name = "${var.project_name}-rds-multi-az"
  }
}
