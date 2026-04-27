terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.82"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.1.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "pdf-generator"
    }
  }
}
