# filename: vpc.tf

locals {
  full_cluster_name = var.cluster_name
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.environment}-${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = [cidrsubnet(var.vpc_cidr, 4, 0), cidrsubnet(var.vpc_cidr, 4, 1), cidrsubnet(var.vpc_cidr, 4, 2)]
  public_subnets  = [cidrsubnet(var.vpc_cidr, 4, 4), cidrsubnet(var.vpc_cidr, 4, 5), cidrsubnet(var.vpc_cidr, 4, 6)]

  enable_nat_gateway   = true
  single_nat_gateway   = true 
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                           = "1"
    "kubernetes.io/cluster/${local.full_cluster_name}" = "shared"
  }
  
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                  = "1"
    "kubernetes.io/cluster/${local.full_cluster_name}" = "shared"
  }
}

