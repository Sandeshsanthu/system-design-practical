helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --namespace argocd --create-namespace


helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm upgrade --install kube-state-metrics prometheus-community/kube-state-metrics -n monitoring --create-namespace