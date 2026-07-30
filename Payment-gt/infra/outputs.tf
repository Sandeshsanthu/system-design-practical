output "cluster_name" {
  description = "The deployed Kubernetes cluster identifier string"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API Endpoint connection URL link"
  value       = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Execution terminal command to connect local environment to the cluster"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${module.eks.cluster_name}"
}
output "aws_secret_name" {
  description = "The exact lookup string key your application pods must call in Secrets Manager"
  # Fixed the resource reference here by removing the underscores:
  value = aws_secretsmanager_secret.db_secret.name
}

