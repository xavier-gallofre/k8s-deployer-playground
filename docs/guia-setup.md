# Guía de Setup - Paso a Paso

## Prerrequisitos

### Software necesario

| Herramienta | Versión mínima | Propósito |
|---|---|---|
| Docker | 20.10+ | Runtime para Minikube |
| kubectl | 1.28+ | CLI de Kubernetes |
| curl | cualquier | Descargas |
| helm | 3.12+ | Gestor de paquetes de Kubernetes |

### Verificar prerrequisitos

```bash
docker --version
kubectl version --client
curl --version
helm version
```

## Paso 1: Instalar Minikube

### Linux (amd64)

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64
```

### macOS

```bash
brew install minikube
```

### Windows

```powershell
choco install minikube
```

## Paso 2: Instalar Helm

### Linux

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### macOS

```bash
brew install helm
```

### Windows

```powershell
choco install kubernetes-helm
```

### Verificar

```bash
helm version
```

## Paso 3: Iniciar el clúster

```bash
minikube start \
  --profile=k8s-playground \
  --driver=docker \
  --cpus=4 \
  --memory=8192 \
  --disk-size=20g \
  --kubernetes-version=stable
```

### Verificar estado

```bash
minikube status --profile=k8s-playground
kubectl get nodes
```

## Paso 4: Instalar MetalLB (LoadBalancer local)

### Habilitar addon de Minikube

```bash
minikube addons enable metallb --profile=k8s-playground
```

Esperar a que el webhook esté listo (puede tardar ~1 minuto).

### Configurar pool de IPs

```bash
MINIKUBE_IP=$(minikube ip --profile=k8s-playground)

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: playground-pool
  namespace: metallb-system
spec:
  addresses:
  - ${MINIKUBE_IP%.*}.200-${MINIKUBE_IP%.*}.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: playground-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - playground-pool
EOF
```

## Paso 5: Instalar NGINX Ingress Controller

```bash
minikube addons enable ingress --profile=k8s-playground
```

Verificar:

```bash
kubectl get pods -n ingress-nginx
```

## Paso 6: Instalar Traefik

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm install traefik traefik/traefik \
  --namespace kube-system \
  --set service.type=LoadBalancer \
  --set resources.requests.cpu=50m \
  --set resources.requests.memory=64Mi
```

Verificar:

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
```

**Nota:** NGINX y Traefik coexisten en el mismo clúster con IngressClasses diferentes (`nginx` y `traefik`). MetalLB asigna IPs externas a ambos.

## Paso 7: Instalar Istio

### Descargar istioctl

```bash
ISTIO_VERSION=1.30.0
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
cd istio-*
export PATH=$PWD/bin:$PATH
```

### Instalar Istio

```bash
istioctl install --set profile=default --set meshConfig.enableAutoMtls=false -y
```

### Verificar

```bash
kubectl get pods -n istio-system
```

## Paso 8: Instalar Argo CD

```bash
kubectl create namespace argocd

# NOTA: la CRD `applicationsets.argoproj.io` de Argo CD supera los 256KB, lo que
# excede el límite de `kubectl apply` (client-side). Usa `--server-side`.
kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.1/manifests/install.yaml
```

Esperar a que esté listo:

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=180s
```

### Obtener contraseña admin

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo
```

### Acceder a la UI

```bash
minikube service argocd-server -n argocd --url
```

Usuario: `admin`  
Password: (el obtenido arriba)

## Paso 9: Instalar Argo Rollouts

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://raw.githubusercontent.com/argoproj/argo-rollouts/v1.9.1/manifests/install.yaml
```

### Instalar plugin kubectl

```bash
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
sudo install -m 555 kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
rm kubectl-argo-rollouts-linux-amd64
```

### Verificar

```bash
kubectl argo rollouts version
```

## Paso 10: Desplegar aplicaciones

### Opción A: Usar Kustomize

```bash
kubectl apply -k .
```

### Opción B: Usar Argo CD

```bash
kubectl apply -f argocd/application.yaml
```

### Opción C: Aplicaciones individuales

```bash
# Namespace y base
kubectl apply -f apps/microservices-demo/base/

# Estrategia Canary
kubectl apply -f apps/microservices-demo/canary/

# Estrategia Blue/Green
kubectl apply -f apps/microservices-demo/bluegreen/

# Estrategia A/B Testing
kubectl apply -f apps/microservices-demo/abtesting/
```

## Paso 11: Probar el entorno

### Verificar pods

```bash
kubectl get pods -n demo
```

### Probar NGINX Ingress

```bash
# Añadir entrada DNS
echo "$(minikube ip) nginx.demo.local" | sudo tee -a /etc/hosts

# Probar
curl http://nginx.demo.local
```

### Probar Traefik

```bash
echo "$(minikube ip) traefik.demo.local" | sudo tee -a /etc/hosts
curl http://traefik.demo.local
```

### Probar despliegue Canary

```bash
kubectl argo rollouts get rollout api-rollout-canary -n demo --watch
```

En otra terminal:

```bash
kubectl argo rollouts set image api-rollout-canary api=hashicorp/http-echo:0.2.3 -n demo
```

## Troubleshooting

### Pods en CrashLoopBackOff

```bash
kubectl describe pod <pod-name> -n demo
kubectl logs <pod-name> -n demo
```

### Ingress no funciona

```bash
kubectl get ingress -n demo
kubectl describe ingress <ingress-name> -n demo
kubectl get events -n demo
```

### Istio no enruta tráfico

```bash
kubectl get virtualservices -n demo
kubectl get destinationrules -n demo
istioctl analyze -n demo
```

### Argo CD no sincroniza

```bash
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd
argocd app list
```

## Paso 12: Observabilidad (Kiali, Prometheus, Grafana)

Los addons de Istio se instalan automáticamente con `setup.sh`. Para instalación manual:

```bash
ISTIO_VERSION=1.30.0
kubectl apply -f "https://raw.githubusercontent.com/istio/istio/release-${ISTIO_VERSION}/samples/addons/prometheus.yaml"
kubectl apply -f "https://raw.githubusercontent.com/istio/istio/release-${ISTIO_VERSION}/samples/addons/grafana.yaml"
kubectl apply -f "https://raw.githubusercontent.com/istio/istio/release-${ISTIO_VERSION}/samples/addons/kiali.yaml"
```

### Acceder a los dashboards

```bash
# Kiali
istioctl dashboard kiali

# Prometheus
kubectl port-forward -n istio-system svc/prometheus 9090:9090

# Grafana
kubectl port-forward -n istio-system svc/grafana 3000:3000
```

## Limpieza manual

Si no quieres usar `scripts/teardown.sh`, puedes limpiar manualmente:

```bash
# Eliminar aplicaciones
kubectl delete namespace demo --ignore-not-found

# Eliminar Argo CD y Rollouts
kubectl delete namespace argocd --ignore-not-found
kubectl delete namespace argo-rollouts --ignore-not-found

# Eliminar Istio
istioctl uninstall --purge -y 2>/dev/null || true
kubectl delete namespace istio-system --ignore-not-found

# Eliminar Helm releases
helm uninstall traefik -n kube-system 2>/dev/null || true

# Eliminar Minikube
minikube delete --profile=k8s-playground
```
