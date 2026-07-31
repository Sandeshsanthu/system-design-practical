# 1. Generate an automated, strong random string for the password
resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# 2. Deploy a customer-managed KMS key to encrypt the secret value
resource "aws_kms_key" "secrets_key" {
  description             = "KMS Key for Payment Gateway RDS credentials vault"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Environment = var.environment
  }
}

# 3. Create the AWS Secrets Manager container object
# 3. Create the AWS Secrets Manager container object (Fixed naming)
resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "${var.environment}-${var.cluster_name}-rds-secret"
  kms_key_id              = aws_kms_key.secrets_key.key_id
  recovery_window_in_days = 0 # Forces immediate deletion if running a destroy plan

  tags = {
    Environment = var.environment
  }
}

# 4. Inject the generated credentials securely into the Secrets Manager payload (Fixed naming)
resource "aws_secretsmanager_secret_version" "db_secret_val" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = 5432
    db_name  = "payment_gateway"
  })
}


# 5. Create a dedicated Security Group for the RDS Database Instance
resource "aws_security_group" "rds_sg" {
  name        = "${var.environment}-${var.cluster_name}-rds-sg"
  description = "Controls isolated private database access network rules"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name        = "${var.environment}-${var.cluster_name}-rds-sg"
    Environment = var.environment
  }
}

# 6. Strict Security Rule: Allow incoming traffic ONLY from the EKS Node Security Group
resource "aws_vpc_security_group_ingress_rule" "allow_eks_to_rds" {
  security_group_id            = aws_security_group.rds_sg.id
  description                  = "Accept connection requests strictly from active Kubernetes worker nodes"
  referenced_security_group_id = module.eks.node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# 7. Explicit Subnet Group mapping the database to private-isolated network pools
resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "${var.environment}-${var.cluster_name}-rds-subnet-group"
  subnet_ids  = module.vpc.private_subnets
  description = "Restricts database instances to private isolated VPC subnets"

  tags = {
    Name = "${var.environment}-${var.cluster_name}-rds-subnet-group"
  }
}

# 8. Production RDS Instance Setup using the dynamically generated password
resource "aws_db_instance" "postgres" {
  identifier        = "${var.environment}-payment-db"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = "db.t3.micro" # AWS Free Tier Eligible
  allocated_storage = 20            # AWS Free Tier Eligible
  storage_type      = "gp3"

  db_name  = "payment_gateway"
  username = var.db_username
  password = random_password.db_password.result # Directly inputs the secure generated data string

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false
  

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
