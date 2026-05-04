# 1. Look up the existing EKS Security Group automatically
# data "aws_security_group" "eks_node_sg" {
#   filter {
#     name   = "tag:kubernetes.io/cluster/${var.cluster_name}"
#     values = ["owned", "shared"]
#   }
  
  # Or filter by name if you know it
  # name = "eks-cluster-sg-my-cluster-12345"
# }

resource "aws_security_group" "rds_sg" {
  name        = "rds-postgres-sg"
  vpc_id      = aws_vpc.main.id
  description = "RDS Security Group"
}

# PERMANENT RULE: Uses the ID found above
# resource "aws_vpc_security_group_ingress_rule" "eks_to_rds" {
#   security_group_id            = aws_security_group.rds_sg.id
#   referenced_security_group_id = data.aws_security_group.eks_node_sg.id
#   from_port                    = 5432
#   to_port                      = 5432
#   ip_protocol                  = "tcp"
#   description                  = "Allow EKS nodes to RDS"
# }

resource "aws_db_instance" "postgres" {
  # ... (rest of your RDS config from previous steps)
  identifier            = "prod-postgres"
  engine                = "postgres"
  instance_class        = "db.t3.micro"
  allocated_storage     = 50
  db_name               = "production_db"
  username              = "dbadmin"
  password              = random_password.db_pass.result
  skip_final_snapshot = true
  deletion_protection = false
  db_subnet_group_name  = aws_db_subnet_group.database.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible   = true 
}


# TEMPORARY RULE: EXTERNAL APP ACCESS
resource "aws_vpc_security_group_ingress_rule" "external_app" {
  security_group_id = aws_security_group.rds_sg.id
  cidr_ipv4         = var.external_ip
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  description       = "Temporary external access"
}
