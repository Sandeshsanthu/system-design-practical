helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install prometheus-stack prometheus-community/kube-prometheus-stack --namespace monitoring
kubectl get pods -n monitoring

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update


helm upgrade --install loki grafana/loki-stack `
  --namespace monitoring `
  --set promtail.enabled=true `
  --set loki.persistence.enabled=false


helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm install keda kedacore/keda \
  --namespace keda \
  --create-namespace


helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts

helm repo update



helm upgrade --install loki grafana-community/loki `
  -n monitoring `
  --create-namespace `
  -f .\loki-values.yaml


  helm upgrade --install alloy grafana/alloy `
  -n monitoring `
  --create-namespace `
  -f .\alloy-values.yaml