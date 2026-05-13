module "karpenter_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                          = "KarpenterController-${var.cluster_name}"
  attach_karpenter_controller_policy = true

  karpenter_controller_cluster_name       = module.eks.cluster_name
  karpenter_controller_node_iam_role_arns = [module.karpenter.node_iam_role_arn]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:karpenter"]
    }
  }
}



module "worker_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-pdf-app-role"

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "pdf-gen:pdf-app-sa",
        "pdf-gen:pdf-worker-sa"
      ]
    }
  }

  role_policy_arns = {
    secrets_access = aws_iam_policy.secrets_policy.arn
    s3_access      = aws_iam_policy.s3_policy.arn
  }
}