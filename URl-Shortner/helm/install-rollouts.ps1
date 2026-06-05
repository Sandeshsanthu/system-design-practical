# Add the official Argo Helm repository
helm repo add argo https://argoproj.github.io/argo-helm

# Update your local chart cache
helm repo update

# Install the controller into its own namespace
helm install argo-rollouts argo/argo-rollouts `
  --create-namespace `
  --namespace argo-rollouts
