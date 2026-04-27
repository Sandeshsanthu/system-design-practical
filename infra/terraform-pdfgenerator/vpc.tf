module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

name = "${var.cluster_name}-vpc"
cidr =  "10.0.0.0/16"

azs =  ["${var.aws_region}a"]
private_subnets = ["10.0.1.0/24"]
public_subnets  = ["10.0.101.0/24"]
database_subnets = ["10.0.201.0/24"]

enable_nat_gateway   = true
single_nat_gateway   = false
enable_dns_hostnames = true
enable_dns_support   = true


  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

