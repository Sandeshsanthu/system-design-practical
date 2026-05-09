$CLUSTER_NAME = "eks-pdf-gen"
$REGION = "us-east-2"
$KARPENTER_VERSION = "1.0.1"
$QUEUE_NAME = "Karpenter-eks-pdf-gen"

# 1. Fetch the Controller Role ARN created by your new Terraform module
# This role allows the pod to talk to AWS (AMIs, Pricing, EC2)
$CONTROLLER_ROLE_ARN = (aws iam get-role --role-name "KarpenterController-$CLUSTER_NAME" --query "Role.Arn" --output text)

Write-Host "🚀 Installing Karpenter..." -ForegroundColor Cyan
Write-Host "Using Queue: $QUEUE_NAME" -ForegroundColor Yellow
Write-Host "Using Role: $CONTROLLER_ROLE_ARN" -ForegroundColor Magenta

# 2. Cleanup old release
helm uninstall karpenter --namespace kube-system

# 3. Re-install with IRSA (IAM Roles for Service Accounts) linked
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter `
  --namespace kube-system `
  --version $KARPENTER_VERSION `
  --set "settings.clusterName=$CLUSTER_NAME" `
  --set "settings.interruptionQueueName=$QUEUE_NAME" `
  --set "aws.defaultRegion=$REGION" `
  --set "controller.resources.requests.cpu=100m" `
  --set "controller.resources.requests.memory=512Mi" `
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=$CONTROLLER_ROLE_ARN" `
  --wait

Write-Host "--- Karpenter Installation Complete ---" -ForegroundColor Green
