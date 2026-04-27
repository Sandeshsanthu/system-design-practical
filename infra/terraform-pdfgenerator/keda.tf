# Install KEDA using Helm
resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  namespace        = "keda"
  create_namespace = true
  version          = "2.12.0"

  values = [
    yamlencode({
      resources = {
        operator = {
          limits = {
            cpu    = "1"
            memory = "1000Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "100Mi"
          }
        }
      }
    })
  ]

  depends_on = [module.eks]
}

# Install External Secrets Operator
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  version          = "0.9.9"

  values = [
    yamlencode({
      installCRDs = true
      serviceAccount = {
        name = "external-secrets-sa"
        annotations = {
          "://amazonaws.com" = aws_iam_role.external_secrets.arn
        }
      }
    })
  ]

  depends_on = [module.eks]
}

