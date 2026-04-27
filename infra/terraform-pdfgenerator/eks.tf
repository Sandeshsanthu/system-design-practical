module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~>  20.0"

  cluster_name = var.cluster_name
  cluster_version = "1.28"
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true


  enable_irsa = true

  eks_managed_node_groups = {
    general = {
      desired_size = 1
      min_size     = 1
      max_size     = 2
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      labels = {
        role = "general"
      }

      tags = {
        NodeGroup = "general"
      }
    }

    workers = {
      desired_size = 1
      min_size = 1
      max_size = 2
      instance_types = ["t3.large"]
      capacity_type  = "SPOT"

    labels ={
      role = "worker"
    }
    taints = [{
        key    = "workload"
        value  = "worker"
        effect = "NoSchedule"
      }]
     tags = {
        NodeGroup = "workers"
      }

    }

  }
}



