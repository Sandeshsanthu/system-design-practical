resource "random_password" "redis_password" {
  length  = 32
  special = false
}

resource "aws_security_group" "redis_sg" {
  name        = "redis-production-sg"
  vpc_id      = aws_vpc.main.id
  description = "Allow Redis traffic"
}

resource "aws_vpc_security_group_ingress_rule" "redis_external" {
  security_group_id = aws_security_group.redis_sg.id
  cidr_ipv4         = var.external_ip
  from_port         = 6379
  to_port           = 6379
  ip_protocol       = "tcp"
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "pdf-gen-redis-public"
  description                = "Redis cluster for local and EKS access"
  node_type                  = "cache.t3.micro"
  num_cache_clusters         = 1
  port                       = 6379
  parameter_group_name       = "default.redis7"
  
  # Correctly referencing the Redis Subnet Group
  subnet_group_name          = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids         = [aws_security_group.redis_sg.id]
  
  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  auth_token                 = random_password.redis_password.result
}
