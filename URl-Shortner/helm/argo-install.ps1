helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --namespace argocd --create-namespace


helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

helm upgrade --install kube-state-metrics prometheus-community/kube-state-metrics -n monitoring --create-namespace



Argocd Installtion

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/port", "value": 8081}]'
