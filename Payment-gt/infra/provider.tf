# filename: providers.tf

terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

# 1. Fetch cluster details dynamically (Always reads directly from the live AWS API)
data "aws_eks_cluster" "current" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "current" {
  name = module.eks.cluster_name
}
# 2. Reference the cluster resource outputs directly (Assuming you use the official EKS module)
provider "kubernetes" {
  host                   = data.aws_eks_cluster.current.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.current.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--region",
      var.aws_region,
      "--cluster-name",
      module.eks.cluster_name
    ]
  }
}
