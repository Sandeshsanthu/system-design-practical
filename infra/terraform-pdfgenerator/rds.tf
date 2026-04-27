resource "random_password" "db_password" {
   special = true
   length  = 32
}

resource "aws_secretsmanager_secret" "db_credentials" {
   name = "${var.cluster_name}-db-credentials"
}

resource "aws_secretsmanager_secret_version" "db_credenitals" {
    secret_id = aws_secretsmanager_secret.db_credentials.id
    secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = module.db.db_instance_address
    port     = module.db.db_instance_port
    dbname   = var.db_name
  })

}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"
  identifier = "${var.cluster_name}-postgres"
  engine               = "postgres"
  engine_version       = "15.4"
  family              = "postgres15"
  major_engine_version = "15"
  instance_class       = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_encrypted     = true
  db_name = var.db_name
  username = var.db_username
  password = random_password.db_password.result
  port     = 5432
  multi_az               = true
  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 7
  skip_final_snapshot     = false
  deletion_protection     = true

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  tags = {
    Name = "${var.cluster_name}-postgres"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = module.vpc.vpc_id
  ingress {
    description = "PostgreSQL from EKS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}