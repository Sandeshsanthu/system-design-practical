resource "aws_elasticache_subnet_group" "redis" {
   name       = "${var.cluster_name}-redis-subnet"
  subnet_ids =  module.vpc.private_subnets
}
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.cluster_name}-redis"

  engine             = "redis"
  engine_version     = "7.0"
  node_type          = "cache.t3.medium"
  num_cache_clusters = 2
  port               = 6379
  description        = "Redis for PDF Generator" # Keep this one

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]

  automatic_failover_enabled = true
  multi_az_enabled          = true

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  snapshot_retention_limit = 5
  snapshot_window         = "03:00-05:00"

  maintenance_window = "mon:05:00-mon:07:00"

  tags = {
    Name = "${var.cluster_name}-redis"
  }
}

resource "aws_security_group" "redis" {
  name        = "${var.cluster_name}-redis-sg"
  description = "Security group for Redis"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Redis from EKS"
    from_port   = 6379
    to_port     = 6379
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