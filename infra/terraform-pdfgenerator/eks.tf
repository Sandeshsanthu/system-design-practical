module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.34"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # CRITICAL: Prevent cluster replacement
  bootstrap_self_managed_addons            = false
  enable_cluster_creator_admin_permissions = true

  enable_irsa = true


  access_entries = {
    admin_user = {
      principal_arn     = data.aws_caller_identity.current.arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    general = {
      desired_size   = 1
      min_size       = 1
      max_size       = 1
      instance_types = ["t2.medium"] # t3 is highly recommended over t2 for EKS
      capacity_type  = "ON_DEMAND"

      # 🟢 FIX 2: Ensure CNI policy is attached so nodes become 'Ready'
      iam_role_additional_policies = {
        AmazonEKS_CNI_Policy = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      }

      labels = { role = "general" }
    }

    workers = {
      desired_size   = 1
      min_size       = 1
      max_size       = 1
      instance_types = ["t2.medium"]
      capacity_type  = "SPOT"

      iam_role_additional_policies = {
        AmazonEKS_CNI_Policy = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
      }

      labels = { role = "worker" }

      taints = [{
        key    = "workload"
        value  = "worker"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  tags = {
    Environment = "production"
    Project     = "pdf-generator"
  }
}

# 🟢 Add this data source at the top or bottom of your file
# to automatically detect your current IAM ARN
data "aws_caller_identity" "current" {}
