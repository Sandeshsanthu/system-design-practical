terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    bucket       = "fintech-bucket-all"
    key          = "pdf-generator/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" {
  region = var.region
}


