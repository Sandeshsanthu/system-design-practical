output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.db.db_instance_address
}

output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "worker_role_arn" {
  description = "IAM role ARN for worker pods"
  value       = aws_iam_role.worker.arn
}

output "s3_bucket_name" {
  description = "S3 bucket for PDFs"
  value       = aws_s3_bucket.pdf_storage.id
}

output "configure_kubectl" {
  description = "Configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
