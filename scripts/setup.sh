#!/usr/bin/env bash
# =============================================================================
# setup.sh - Instalación completa del playground
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

CLUSTER_NAME="k8s-playground"
MINIKUBE_CPUS="4"
MINIKUBE_MEMORY="8192"
MINIKUBE_DISK_SIZE="20g"

main() {
    log_step "K8s Deployer Playground - Setup Completo"
    log_info "Este script instalará todas las dependencias del playground"
    echo ""

    check_prerequisites
    start_minikube
    install_metallb
    install_ingress_nginx
    install_traefik
    install_istio
    install_argo
    show_summary
}

check_prerequisites() {
    log_step "Verificando prerrequisitos"

    local missing=0
    for cmd in docker kubectl curl; do
        if ! check_command "$cmd"; then
            missing=1
        fi
    done

    if [ "$missing" -eq 1 ]; then
        log_error "Faltan dependencias. Instálalas antes de continuar."
        exit 1
    fi

    if ! check_command minikube; then
        log_info "Instalando minikube..."
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        rm minikube-linux-amd64
    fi

    if ! check_command "argocd" 2>/dev/null; then
        log_info "Instalando CLI de Argo CD..."
        curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 argocd /usr/local/bin/argocd
        rm argocd
    fi

    if ! check_command "kubectl-argo-rollouts" 2>/dev/null; then
        log_info "Instalando plugin de Argo Rollouts..."
        curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
        sudo install -m 555 kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
        rm kubectl-argo-rollouts-linux-amd64
    fi
}

start_minikube() {
    log_step "Iniciando Minikube"

    if minikube status --profile="$CLUSTER_NAME" 2>/dev/null | grep -q "Running"; then
        log_warn "Minikube ya está ejecutándose"
        return
    fi

    minikube start \
        --profile="$CLUSTER_NAME" \
        --driver=docker \
        --cpus="$MINIKUBE_CPUS" \
        --memory="$MINIKUBE_MEMORY" \
        --disk-size="$MINIKUBE_DISK_SIZE" \
        --kubernetes-version=stable

    log_success "Minikube iniciado correctamente"
    kubectl cluster-info
}

install_metallb() {
    log_step "Instalando MetalLB (LoadBalancer para Minikube)"

    if kubectl get ns metallb-system &>/dev/null; then
        log_warn "MetalLB ya instalado"
        return
    fi

    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
    wait_for_pods "metallb-system"

    # Configurar pool de IPs
    MINIKUBE_IP=$(minikube ip --profile="$CLUSTER_NAME")
    FIRST_IP=$(echo "$MINIKUBE_IP" | sed 's/\.[0-9]*$/.200/')
    LAST_IP=$(echo "$MINIKUBE_IP" | sed 's/\.[0-9]*$/.250/')

    cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: playground-pool
  namespace: metallb-system
spec:
  addresses:
  - ${FIRST_IP}-${LAST_IP}
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

    log_success "MetalLB configurado con pool ${FIRST_IP}-${LAST_IP}"
}

install_ingress_nginx() {
    log_step "Instalando NGINX Ingress Controller"

    if kubectl get ns ingress-nginx &>/dev/null; then
        log_warn "NGINX Ingress ya instalado"
        return
    fi

    minikube addons enable ingress --profile="$CLUSTER_NAME" || true

    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s 2>/dev/null || true

    log_success "NGINX Ingress instalado"
}

install_traefik() {
    log_step "Instalando Traefik"

    if kubectl get deployment traefik -n kube-system &>/dev/null; then
        log_warn "Traefik ya instalado"
        return
    fi

    minikube addons enable traefik --profile="$CLUSTER_NAME" || true

    wait_for_deployment "kube-system" "traefik"

    log_success "Traefik instalado"
}

install_istio() {
    log_step "Instalando Istio (ambient mode)"

    if kubectl get ns istio-system &>/dev/null; then
        log_warn "Istio ya instalado"
        return
    fi

    # Descargar istioctl si no existe
    if ! command -v istioctl &>/dev/null; then
        log_info "Descargando istioctl..."
        curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.30.0 sh -
        sudo cp istio-*/bin/istioctl /usr/local/bin/
        rm -rf istio-*
    fi

    istioctl install --set profile=minimal --set meshConfig.enableAutoMtls=false -y

    # Instalar ztunnel para ambient mode
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.30/manifests/charts/ztunnel/files/ztunnel.yaml 2>/dev/null || \
        kubectl apply -f https://github.com/istio/istio/releases/download/1.30.0/ztunnel.yaml 2>/dev/null || \
        log_warn "Ztunnel ambient mode no disponible, usando modo clásico"

    log_success "Istio instalado"
}

install_argo() {
    log_step "Instalando Argo CD"

    if kubectl get ns argocd &>/dev/null; then
        log_warn "Argo CD ya instalado"
        return
    fi

    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.1/manifests/install.yaml

    wait_for_pods "argocd"

    # Instalar Argo Rollouts
    log_step "Instalando Argo Rollouts"

    if kubectl get ns argo-rollouts &>/dev/null; then
        log_warn "Argo Rollouts ya instalado"
        return
    fi

    kubectl create namespace argo-rollouts
    kubectl apply -n argo-rollouts -f https://raw.githubusercontent.com/argoproj/argo-rollouts/v1.9.1/manifests/install.yaml

    wait_for_pods "argo-rollouts"

    # Configurar Rollout controller para trabajar con Istio
    kubectl apply -n argo-rollouts -f https://raw.githubusercontent.com/argoproj/argo-rollouts/v1.9.1/manifests/installs/kubernetes-minimal.yaml 2>/dev/null || true

    log_success "Argo CD y Argo Rollouts instalados"
}

show_summary() {
    log_step "Instalación completada"

    echo -e "${GREEN}Resumen del entorno:${NC}"
    echo ""
    minikube status --profile="$CLUSTER_NAME"
    echo ""
    echo -e "${CYAN}URLs de acceso:${NC}"
    echo "  Argo CD UI:      $(minikube service argocd-server -n argocd --url --profile="$CLUSTER_NAME" 2>/dev/null || echo 'ejecutar: minikube service argocd-server -n argocd')"
    echo "  Traefik Dashboard: $(minikube service traefik -n kube-system --url --profile="$CLUSTER_NAME" 2>/dev/null || echo 'ejecutar: minikube service traefik -n kube-system')"
    echo ""
    echo -e "${CYAN}Siguiente paso:${NC}"
    echo "  Desplegar aplicaciones de ejemplo: kubectl apply -f $PROJECT_DIR/apps/"
    echo ""
}

main "$@"
