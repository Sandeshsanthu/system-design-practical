# --- DATA LOOKUPS ---
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "oidc_provider" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

data "aws_caller_identity" "current" {}

# --- POLICIES ---
resource "aws_iam_policy" "secrets_policy" {
  name        = "EKSSecretsManagerRead"
  description = "Allows EKS to read DB credentials"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:prod/db/postgres-credentials-v-*"
      }
    ]
  })
}

# --- IRSA MODULE ---
module "worker_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "pdf-generator-worker-role"

  oidc_providers = {
    main = {
      provider_arn               = data.aws_iam_openid_connect_provider.oidc_provider.arn
      namespace_service_accounts = ["default:pdf-worker-sa","pdf-gen:pdf-worker-sa","kube-system:csi-secrets-store-provider-aws"]
    }
  }

  role_policy_arns = {
    s3_access      = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    secrets_access = aws_iam_policy.secrets_policy.arn
  }
}
