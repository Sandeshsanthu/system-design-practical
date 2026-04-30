# 1. Generate a secure random password
resource "random_password" "db_password" {
  special = true
  length  = 32
  # Exclude characters that can sometimes cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# 2. Create the Secrets Manager Secret Container
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.cluster_name}-db-credentials"
  description = "Database credentials for the PDF Generator EKS cluster"
  
  # Best practice: Allow deletion without recovery for dev, 
  # but remove this line for true production to prevent accidental loss.
  recovery_window_in_days = 0 
}

# 3. Store the credentials JSON in the secret
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = module.db.db_instance_address
    port     = module.db.db_instance_port
    dbname   = var.db_name
  })
}

# 4. The RDS Instance (Fixed Versions)
module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.cluster_name}-postgres"

  # FIX: Using major version '15' allows AWS to select the latest available minor version
  engine               = "postgres"
  engine_version       = "15" 
  family               = "postgres15"
  major_engine_version = "15" 
  
  instance_class       = "db.t3.medium"
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  port     = 5432

  # High Availability
  multi_az               = true
  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Maintenance & Backups
  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name = "${var.cluster_name}-postgres"
    Environment = "production"
  }
}

# 5. RDS Security Group
resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds-sg"
  description = "Security group for RDS allowing access from EKS private subnets"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "PostgreSQL from EKS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # Restrict to your private subnet range
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-rds-sg"
  }
}
