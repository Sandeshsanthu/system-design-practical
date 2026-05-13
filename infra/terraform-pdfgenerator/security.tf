resource "aws_security_group" "rds_sg" {
  name        = "${var.cluster_name}-rds-sg"
  description = "Allow PostgreSQL access from EKS nodes"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "eks_to_rds" {
  security_group_id            = aws_security_group.rds_sg.id
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Allow PostgreSQL from EKS worker nodes"
}


#karpanter

resource "aws_ec2_tag" "cluster_primary_security_group" {
  resource_id = module.eks.cluster_primary_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

resource "aws_vpc_security_group_ingress_rule" "nodes_internal_all" {
  description                  = "Allow all internal cluster traffic between nodes"
  security_group_id            = module.eks.node_security_group_id
  referenced_security_group_id = module.eks.node_security_group_id

  ip_protocol = "-1" # Allows all protocols (TCP/UDP/ICMP)
  from_port   = 0
  to_port     = 0
}