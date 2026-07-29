# 1. IAM Policy that permits reading strictly our specific RDS secret
resource "aws_iam_policy" "pod_secret_policy" {
  name        = "${var.environment}-${var.cluster_name}-pod-secret-policy"
  description = "Allows EKS database pods to retrieve credentials securely from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [aws_secrets_manager_secret.db_secret.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [aws_kms_key.secrets_key.arn]
      }
    ]
  })
}

# 2. Production Trust Relationship matching the EKS Cluster's OIDC Provider
data "aws_iam_policy_document" "irsa_trust_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      # Limits access strictly to the 'payment-api-sa' Service Account inside the 'default' namespace
      values   = ["system:serviceaccount:default:payment-api-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["://amazonaws.com"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

# 3. Create the Dedicated IAM Role for our application pods
resource "aws_iam_role" "irsa_role" {
  name               = "${var.environment}-${var.cluster_name}-pod-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.irsa_trust_policy.json
}

# 4. Attach the data-read security policy directly to the IAM role
resource "aws_iam_role_policy_attachment" "irsa_attach" {
  role       = aws_iam_role.irsa_role.name
  policy_arn = aws_iam_policy.pod_secret_policy.arn
}

# 5. Native Kubernetes Service Account that injects the AWS Role ARN annotation
resource "kubernetes_service_account" "app_sa" {
  metadata {
    name      = "payment-api-sa"
    namespace = "default"
    annotations = {
      # This magical annotation lets AWS EKS know this pod can assume our IAM Role
      "://amazonaws.com" = aws_iam_role.irsa_role.arn
    }
  }

  # Ensure the service account isn't provisioned before the EKS Cluster API is completely online
  depends_on = [module.eks]
}
