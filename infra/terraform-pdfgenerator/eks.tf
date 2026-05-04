module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"

  # Networking
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Endpoint Access (Production best practice: Private access enabled)
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # IAM Roles for Service Accounts (IRSA)
  enable_irsa = true

  # Encryption at rest for Secrets
  create_kms_key = true
  cluster_encryption_config = {
    resources = ["secrets"]
  }

  # Node Groups (Managed)
  eks_managed_node_groups = {
    production = {
      instance_types = ["t3.medium"]
      min_size     = 1
      max_size     = 2
      desired_size = 1

      # Production nodes should be in private subnets
      subnet_ids = module.vpc.private_subnets


      # Use Bottlerocket or Amazon Linux 2023
      ami_type = "AL2023_x86_64_STANDARD"
    }
  }

  # Enable Access Entry (Standard for EKS v20+)
  enable_cluster_creator_admin_permissions = true
}




