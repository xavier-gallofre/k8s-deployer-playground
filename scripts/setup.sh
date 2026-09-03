#!/usr/bin/env bash
# =============================================================================
# setup.sh - Instalación completa del playground
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

# Configuración por defecto (sobreescribir via .env o variables de entorno)
MINIKUBE_CPUS="${MINIKUBE_CPUS:-4}"
MINIKUBE_MEMORY="${MINIKUBE_MEMORY:-8192}"
MINIKUBE_DISK_SIZE="${MINIKUBE_DISK_SIZE:-20g}"
MINIKUBE_DRIVER="${MINIKUBE_DRIVER:-docker}"
MINIKUBE_K8S_VERSION="${MINIKUBE_K8S_VERSION:-stable}"

# Versiones de componentes (configurables via .env)
ISTIO_VERSION="${ISTIO_VERSION:-1.30.0}"
ARGO_CD_VERSION="${ARGO_CD_VERSION:-v3.5.1}"
ARGO_ROLLOUTS_VERSION="${ARGO_ROLLOUTS_VERSION:-v1.9.1}"
METALLB_VERSION="${METALLB_VERSION:-0.13.12}"

# MetalLB IP range (configurable via .env)
METALLB_IP_START="${METALLB_IP_START:-.200}"
METALLB_IP_END="${METALLB_IP_END:-.250}"

# Cargar .env si existe
if [ -f "${PROJECT_DIR}/.env" ]; then
    log_info "Cargando configuración desde .env"
    set -a
    source "${PROJECT_DIR}/.env"
    set +a
fi

main() {
    log_step "K8s Deployer Playground - Setup Completo"
    log_info "Profile: ${PLAYGROUND_PROFILE}"
    log_info "Este script instalará todas las dependencias del playground"
    echo ""

    init_logging
    check_prerequisites
    check_existing_profile
    start_minikube
    install_metallb
    install_ingress_nginx
    install_traefik
    install_istio
    install_argo
    generate_inventory
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

    install_helm

    if ! check_command "argocd" 2>/dev/null; then
        log_info "Instalando CLI de Argo CD..."
        curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        sudo install -m 555 /tmp/argocd /usr/local/bin/argocd
        rm /tmp/argocd
    fi

    if ! check_command "kubectl-argo-rollouts" 2>/dev/null; then
        log_info "Instalando plugin de Argo Rollouts..."
        curl -sSL -o /tmp/kubectl-argo-rollouts https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
        sudo install -m 555 /tmp/kubectl-argo-rollouts /usr/local/bin/kubectl-argo-rollouts
        rm /tmp/kubectl-argo-rollouts
    fi
}

check_existing_profile() {
    log_step "Verificando profile de Minikube"

    if check_profile_in_use "$PLAYGROUND_PROFILE"; then
        log_warn "El profile '${PLAYGROUND_PROFILE}' ya está ejecutándose."
        log_info "¿Quieres usar este clúster existente? Se omitirá la creación."
        read -p "Continuar con el clúster existente? (s/N): " confirm
        if [[ "$confirm" =~ ^[sS]$ ]]; then
            return
        else
            log_info "Cancelled. Usa otro PLAYGROUND_PROFILE o ejecuta teardown primero."
            exit 0
        fi
    fi
}

start_minikube() {
    log_step "Iniciando Minikube"

    if minikube status --profile="$PLAYGROUND_PROFILE" 2>/dev/null | grep -q "Running"; then
        log_warn "Minikube ya está ejecutándose"
        return
    fi

    log_info "Iniciando con driver=${MINIKUBE_DRIVER}, CPUs=${MINIKUBE_CPUS}, RAM=${MINIKUBE_MEMORY}MB"
    minikube start \
        --profile="$PLAYGROUND_PROFILE" \
        --driver="$MINIKUBE_DRIVER" \
        --cpus="$MINIKUBE_CPUS" \
        --memory="$MINIKUBE_MEMORY" \
        --disk-size="$MINIKUBE_DISK_SIZE" \
        --kubernetes-version="$MINIKUBE_K8S_VERSION"

    log_success "Minikube iniciado correctamente"
    kubectl cluster-info
}

install_metallb() {
    log_step "Instalando MetalLB (LoadBalancer para Minikube)"

    # El addon nativo de Minikube instala MetalLB v0.9.6, que NO soporta las
    # CRDs IPAddressPool/L2Advertisement (introducidas en v0.13). Además crea
    # un ConfigMap inválido. Instalamos una versión moderna via Helm en su lugar.
    if ! minikube addons list --profile="$PLAYGROUND_PROFILE" 2>/dev/null | grep metallb | grep -q enabled; then
        log_info "Deshabilitando addon metallb obsoleto de Minikube (v0.9.6)..."
        minikube addons disable metallb --profile="$PLAYGROUND_PROFILE" 2>/dev/null || true
    fi

    # Verificar si MetalLB ya está instalado
    if helm list -n metallb-system 2>/dev/null | grep -q metallb; then
        log_warn "MetalLB ya instalado via Helm"
    else
        log_info "Instalando MetalLB via Helm (v${METALLB_VERSION})..."
        helm repo add metallb https://metallb.github.io/metallb 2>/dev/null || true
        helm repo update metallb
        kubectl create namespace metallb-system --dry-run=client -o yaml | kubectl apply -f -
        helm install metallb metallb/metallb \
            --namespace metallb-system \
            --version "$METALLB_VERSION"
    fi

    # Esperar a que el controller esté realmente listo
    log_info "Esperando controller de MetalLB..."
    wait_for_pods "metallb-system" "app.kubernetes.io/component=controller" 180

    log_info "Esperando speaker de MetalLB..."
    wait_for_pods "metallb-system" "app.kubernetes.io/component=speaker" 180

    # Esperar a que las CRDs estén registradas
    log_info "Esperando CRDs de MetalLB..."
    local retries=0
    local max_retries=30
    while [ $retries -lt $max_retries ]; do
        if kubectl get crd ipaddresspools.metallb.io &>/dev/null; then
            log_success "CRDs de MetalLB listos"
            break
        fi
        retries=$((retries + 1))
        log_info "CRDs no listas, reintento ${retries}/${max_retries}..."
        sleep 3
    done

    if [ $retries -eq $max_retries ]; then
        log_error "CRDs de MetalLB no estuvieron listas tras ${max_retries} intentos"
        log_info "Puedes configurar MetalLB manualmente más adelante"
        return 0
    fi

    MINIKUBE_IP=$(minikube ip --profile="$PLAYGROUND_PROFILE")
    FIRST_IP=$(echo "$MINIKUBE_IP" | sed "s/\.[0-9]*$/${METALLB_IP_START}/")
    LAST_IP=$(echo "$MINIKUBE_IP" | sed "s/\.[0-9]*$/${METALLB_IP_END}/")

    log_info "Configurando pool de IPs: ${FIRST_IP}-${LAST_IP}"
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

    minikube addons enable ingress --profile="$PLAYGROUND_PROFILE" || true

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

    helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true
    helm repo update

    # Reintentos por errores de red transitorios (EOF/tiempos de espera)
    local attempt=0
    while [ $attempt -lt 5 ]; do
        if helm install traefik traefik/traefik \
            --namespace kube-system \
            --set service.type=LoadBalancer \
            --set resources.requests.cpu=50m \
            --set resources.requests.memory=64Mi; then
            break
        fi
        attempt=$((attempt + 1))
        log_warn "Traefik: helm install falló (intento ${attempt}/5), reintentando..."
        sleep 5
    done

    wait_for_deployment "kube-system" "traefik"

    log_success "Traefik instalado"
}

install_istio() {
    log_step "Instalando Istio (ambient mode)"

    if kubectl get ns istio-system &>/dev/null; then
        log_warn "Istio ya instalado"
        return
    fi

    if ! command -v istioctl &>/dev/null; then
        log_info "Descargando istioctl..."
        curl -L https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -
        sudo cp istio-*/bin/istioctl /usr/local/bin/
        rm -rf istio-*
    fi

    istioctl install --set profile=default --set meshConfig.enableAutoMtls=false -y

    kubectl apply -f "https://raw.githubusercontent.com/istio/istio/${ISTIO_VERSION}/manifests/charts/ztunnel/files/ztunnel.yaml" 2>/dev/null || \
        kubectl apply -f "https://github.com/istio/istio/releases/download/${ISTIO_VERSION}/ztunnel.yaml" 2>/dev/null || \
        log_warn "Ztunnel ambient mode no disponible, usando modo clásico"

    log_step "Instalando addons de Istio (Prometheus, Grafana, Kiali)"
    kubectl apply -f "https://raw.githubusercontent.com/istio/istio/${ISTIO_VERSION}/samples/addons/prometheus.yaml" 2>/dev/null || true
    kubectl apply -f "https://raw.githubusercontent.com/istio/istio/${ISTIO_VERSION}/samples/addons/grafana.yaml" 2>/dev/null || true
    kubectl apply -f "https://raw.githubusercontent.com/istio/istio/${ISTIO_VERSION}/samples/addons/kiali.yaml" 2>/dev/null || true

    log_success "Istio instalado"
}

install_argo() {
    log_step "Instalando Argo CD"

    if kubectl get ns argocd &>/dev/null; then
        log_warn "Argo CD ya instalado"
        return
    fi

    kubectl create namespace argocd

    # NOTA: la CRD `applicationsets.argoproj.io` de Argo CD supera los 256KB, lo
    # que excede el límite de la anotación `last-applied-configuration` de
    # `kubectl apply` (client-side). Se usa `--server-side` para evitar ese error.
    kubectl apply --server-side -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGO_CD_VERSION}/manifests/install.yaml"

    wait_for_pods "argocd"

    log_step "Instalando Argo Rollouts"

    if kubectl get ns argo-rollouts &>/dev/null; then
        log_warn "Argo Rollouts ya instalado"
        return
    fi

    kubectl create namespace argo-rollouts
    kubectl apply -n argo-rollouts -f "https://raw.githubusercontent.com/argoproj/argo-rollouts/${ARGO_ROLLOUTS_VERSION}/manifests/install.yaml"

    wait_for_pods "argo-rollouts"

    kubectl apply -n argo-rollouts -f "https://raw.githubusercontent.com/argoproj/argo-rollouts/${ARGO_ROLLOUTS_VERSION}/manifests/installs/kubernetes-minimal.yaml" 2>/dev/null || true

    log_success "Argo CD y Argo Rollouts instalados"
}

show_summary() {
    log_step "Instalación completada"

    echo -e "${GREEN}Resumen del entorno:${NC}"
    echo ""
    minikube status --profile="$PLAYGROUND_PROFILE"
    echo ""
    echo -e "${CYAN}URLs de acceso:${NC}"
    echo "  Argo CD UI:        $(minikube service argocd-server -n argocd --url --profile="$PLAYGROUND_PROFILE" 2>/dev/null || echo 'ejecutar: minikube service argocd-server -n argocd')"
    echo "  Traefik Dashboard: $(minikube service traefik -n kube-system --url --profile="$PLAYGROUND_PROFILE" 2>/dev/null || echo 'ejecutar: minikube service traefik -n kube-system')"
    echo "  Argo Rollouts:     kubectl argo rollouts dashboard"
    echo ""
    echo -e "${CYAN}Observabilidad:${NC}"
    echo "  Kiali:       istioctl dashboard kiali"
    echo "  Prometheus:  kubectl port-forward -n istio-system svc/prometheus 9090:9090"
    echo "  Grafana:     kubectl port-forward -n istio-system svc/grafana 3000:3000"
    echo ""
    echo -e "${CYAN}Inventario:${NC}"
    echo "  ${INVENTORY_FILE}"
    echo ""
    echo -e "${CYAN}Log completo:${NC}"
    echo "  ${LOG_FILE}"
    echo ""
    echo -e "${CYAN}Siguiente paso:${NC}"
    echo "  Desplegar aplicaciones: kubectl apply -k ${PROJECT_DIR}"
    echo ""
}

main "$@"
