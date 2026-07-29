terraform {
  required_version = ">= 1.5.7" # Modern local compilation engine validation

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Targets AWS Provider v5 line
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Pull live credentials directly from the generated cluster to log into Kubernetes
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
