# this is for rds secret which is fethc in fly

resource "aws_iam_policy" "secrets_policy" {
  name        = "${var.cluster_name}-secretsmanager-read"
  description = "Allow app service accounts to read the RDS secret"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadRdsManagedSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_db_instance.postgres.master_user_secret[0].secret_arn
      }
    ]
  })
}

#this is for s3 policy where files are generated and dumpled in bucket

resource "aws_iam_policy" "s3_policy" {
  name        = "${var.cluster_name}-pdf-bucket-access"
  description = "Least-privilege S3 access for the PDF app"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::${var.pdf_bucket_name}"
      },
      {
        Sid    = "ObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${var.pdf_bucket_name}/*"
      }
    ]
  })
}

#karpanter roles

resource "aws_iam_role_policy" "karpenter_controller_extra" {
  name = "KarpenterControllerExtra"
  role = module.karpenter_irsa.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "iam:CreateInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:PassRole"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        # Permissions to allow EC2 to actually launch instances using the templates
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSpotPriceHistory",
          "ssm:GetParameter"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}


