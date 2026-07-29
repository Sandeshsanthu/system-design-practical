module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.environment}-${var.cluster_name}"
  cluster_version = "1.30" # Standard stable long-term support release version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true # Allows easy management access from your local machine

  # Production Best Practice: Self-assign admin permission to the creator
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    # The key below becomes part of the node group name automatically.
    # Do NOT pass a nested "name" property here.
    low_cost_workers = {
      instance_types = var.instance_types

      min_size     = 1
      max_size     = 3
      desired_size = 2

      capacity_type = "SPOT" # Significantly lowers compute operational costs
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}
