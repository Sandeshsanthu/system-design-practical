# filename: karpenter-helm.tf

resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = local.karpenter_namespace
  create_namespace = false

  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.0.6"

  values = [yamlencode({
    # FORCE 1 REPLICA ONLY TO FIT WITHIN BASELINE NODE RESOURCE CAPACITIES
    replicas = 1

    serviceAccount = {
      name = local.karpenter_service_account
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter_controller.arn
      }
    }

    settings = {
      clusterName       = module.eks.cluster_name
      clusterEndpoint   = module.eks.cluster_endpoint
      interruptionQueue = aws_sqs_queue.karpenter_interruption.name
    }

    controller = {
      resources = {
        requests = { cpu = "250m", memory = "512Mi" }
        limits   = { cpu = "1",    memory = "1Gi"   }
      }
    }

    affinity = {
      nodeAffinity = {
        requiredDuringSchedulingIgnoredDuringExecution = {
          nodeSelectorTerms = [{
            matchExpressions = [{
              key      = "karpenter.sh/nodepool"
              operator = "DoesNotExist"
            }]
          }]
        }
      }
    }
  })]

  depends_on = [
    aws_iam_role_policy_attachment.karpenter_controller,
    aws_eks_access_entry.karpenter_node
  ]
}

