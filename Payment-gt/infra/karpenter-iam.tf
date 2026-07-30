# filename: karpenter-iam.tf

locals {
  karpenter_namespace       = "kube-system"
  karpenter_service_account = "karpenter"
}

# ──────────────────────────────────────────────
# 1. IAM Role for Karpenter Controller (IRSA)
# ──────────────────────────────────────────────
data "aws_iam_policy_document" "karpenter_controller_trust" {
  statement {
    sid     = "KarpenterControllerTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:sub"
      values   = ["system:serviceaccount:${local.karpenter_namespace}:${local.karpenter_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "karpenter_controller" {
  name               = "${var.environment}-${var.cluster_name}-karpenter-controller"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_trust.json

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

# Karpenter controller needs these permissions to launch/terminate nodes
resource "aws_iam_policy" "karpenter_controller" {
  name        = "${var.environment}-${var.cluster_name}-karpenter-controller-policy"
  description = "Karpenter controller policy for node provisioning"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowScopedEC2InstanceActions"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate"
        ]
        Resource = [
          "arn:aws:ec2:${var.aws_region}::image/*",
          "arn:aws:ec2:${var.aws_region}::snapshot/*",
          "arn:aws:ec2:${var.aws_region}:*:security-group/*",
          "arn:aws:ec2:${var.aws_region}:*:subnet/*",
          "arn:aws:ec2:${var.aws_region}:*:launch-template/*",
          "arn:aws:ec2:${var.aws_region}:*:capacity-reservation/*",
          "arn:aws:ec2:${var.aws_region}:*:instance/*",
          "arn:aws:ec2:${var.aws_region}:*:volume/*",
          "arn:aws:ec2:${var.aws_region}:*:network-interface/*",
          "arn:aws:ec2:${var.aws_region}:*:spot-instances-request/*"
        ]
      },
      {
        Sid    = "AllowScopedEC2InstanceActionsWithTags"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate"
        ]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:*:fleet/*",
          "arn:aws:ec2:${var.aws_region}:*:instance/*",
          "arn:aws:ec2:${var.aws_region}:*:volume/*",
          "arn:aws:ec2:${var.aws_region}:*:network-interface/*",
          "arn:aws:ec2:${var.aws_region}:*:launch-template/*",
          "arn:aws:ec2:${var.aws_region}:*:spot-instances-request/*"
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
          StringLike = {
            "aws:RequestTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid    = "AllowScopedDeletion"
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate"
        ]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:*:instance/*",
          "arn:aws:ec2:${var.aws_region}:*:launch-template/*"
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
          StringLike = {
            "aws:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Sid    = "AllowReadActions"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "pricing:GetProducts",
          "ssm:GetParameter"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "AllowInterruptionQueueActions"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage"
        ]
        Resource = [aws_sqs_queue.karpenter_interruption.arn]
      },
      {
        Sid    = "AllowPassingInstanceRole"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [aws_iam_role.karpenter_node.arn]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ec2.amazonaws.com"
          }
        }
      },
      {
        Sid    = "AllowScopedInstanceProfileMutations"
        Effect = "Allow"
        Action = [
          "iam:AddRoleToInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile"
        ]
        Resource = ["*"]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
          }
          StringLike = {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
          }
        }
      },
      {
        Sid    = "AllowUnconditionedDiscoveryAndProfileRead"
        Effect = "Allow"
        Action = [
          "iam:GetInstanceProfile",
          "eks:DescribeCluster",
          "ec2:CreateTags"
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# ──────────────────────────────────────────────
# 2. IAM Role for Nodes Karpenter Launches
# ──────────────────────────────────────────────

# FIXED SECTION: Uses safe raw jsonencode wrapper entirely, avoiding data source interpolation corruption
resource "aws_iam_role" "karpenter_node" {
  name = "${var.environment}-${var.cluster_name}-karpenter-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AllowEC2ToWithstandNodeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy_attachment" "karpenter_node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])

  role       = aws_iam_role.karpenter_node.name
  policy_arn = each.value
}

resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.karpenter_node.arn
  type          = "EC2_LINUX"

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

