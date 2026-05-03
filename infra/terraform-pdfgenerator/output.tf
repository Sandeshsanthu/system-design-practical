output "rds_hostname" {
  description = "RDS instance hostname"
  value       = split(":", aws_db_instance.postgres.endpoint)[0]
}

output "rds_username" {
  description = "RDS instance root username"
  value       = aws_db_instance.postgres.username
}

output "rds_password" {
  description = "RDS instance root password"
  value       = aws_db_instance.postgres.password
  sensitive   = true
}

output "rds_db_name" {
  description = "RDS database name"
  value       = aws_db_instance.postgres.db_name
}

# This generates the exact URL needed for your DATABASE_URL env var
output "docker_database_url" {
  description = "Copy this directly into your docker-compose environment"
  value       = "postgresql://${aws_db_instance.postgres.username}:${aws_db_instance.postgres.password}@${aws_db_instance.postgres.endpoint}/${aws_db_instance.postgres.db_name}"
  sensitive   = true
}

output "redis_host" {
  value = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_password" {
  value     = random_password.redis_password.result
  sensitive = true
}


