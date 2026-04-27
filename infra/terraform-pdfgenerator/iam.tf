data "aws_iam_policy_document" "worker_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_arn, "/^(.*provider/)/", "")}:sub"
      values   = ["system:serviceaccount:pdf-generator:worker-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_arn, "/^(.*provider/)/", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }


}
}

resource "aws_iam_role" "worker" {
  name               = "${var.cluster_name}-worker-role"
  assume_role_policy = data.aws_iam_policy_document.worker_assume_role.json
}
data "aws_iam_policy_document" "worker_s3" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.pdf_storage.arn,
      "${aws_s3_bucket.pdf_storage.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "worker_s3" {
  name   = "${var.cluster_name}-worker-s3-policy"
  policy = data.aws_iam_policy_document.worker_s3.json
}

resource "aws_iam_role_policy_attachment" "worker_s3" {
  role       = aws_iam_role.worker.name
  policy_arn = aws_iam_policy.worker_s3.arn
}
# IAM Role for External Secrets Operator
data "aws_iam_policy_document" "external_secrets_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_arn, "/^(.*provider/)/", "")}:sub"
      values   = ["system:serviceaccount:external-secrets:external-secrets-sa"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.cluster_name}-external-secrets-role"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume_role.json
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      aws_secretsmanager_secret.db_credentials.arn,
      "${aws_secretsmanager_secret.db_credentials.arn}*"
    ]
  }
}

resource "aws_iam_policy" "external_secrets" {
  name   = "${var.cluster_name}-external-secrets-policy"
  policy = data.aws_iam_policy_document.external_secrets.json
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}