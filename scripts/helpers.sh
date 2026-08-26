#!/usr/bin/env bash
# =============================================================================
# helpers.sh - Funciones comunes para scripts de setup
# =============================================================================
set -euo pipefail

# Directorio base del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Profile configurable via variable de entorno
PLAYGROUND_PROFILE="${PLAYGROUND_PROFILE:-k8s-playground}"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# Logging a archivo
# =============================================================================
LOG_DIR="${PROJECT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="${LOG_DIR}/setup-${TIMESTAMP}.log"
INVENTORY_FILE="${LOG_DIR}/inventario-${TIMESTAMP}.md"

init_logging() {
    mkdir -p "$LOG_DIR"
    echo "# Log de instalación - $(date)" > "$LOG_FILE"
    echo "# Profile: ${PLAYGROUND_PROFILE}" >> "$LOG_FILE"
    echo "---" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

log_to_file() {
    local level=$1
    shift
    local message="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

# =============================================================================
# Logging a consola
# =============================================================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log_to_file "INFO" "$1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
    log_to_file "OK" "$1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    log_to_file "WARN" "$1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_to_file "ERROR" "$1"
}

log_step() {
    local step="$1"
    echo -e "\n${CYAN}━━━ ${step} ━━━${NC}\n"
    log_to_file "STEP" "━━━ ${step} ━━━"
}

# =============================================================================
# Utilidades
# =============================================================================
check_command() {
    if ! command -v "$1" &>/dev/null; then
        log_error "$1 no está instalado"
        return 1
    fi
    log_success "$1 encontrado: $(command -v "$1")"
    return 0
}

wait_for_pods() {
    local namespace=$1
    local label=${2:-""}
    local timeout=${3:-120}

    log_info "Esperando pods en namespace $namespace (timeout: ${timeout}s)..."
    if [ -n "$label" ]; then
        kubectl wait --for=condition=ready pod -l "$label" -n "$namespace" --timeout="${timeout}s" 2>/dev/null || true
    else
        kubectl wait --for=condition=ready pod --all -n "$namespace" --timeout="${timeout}s" 2>/dev/null || true
    fi
}

wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-120}

    log_info "Esperando deployment $deployment..."
    kubectl rollout status deployment/"$deployment" -n "$namespace" --timeout="${timeout}s" 2>/dev/null || true
}

wait_for_webhook() {
    local namespace=$1
    local resource=$2
    local timeout=${3:-150}
    local interval=5
    local elapsed=0

    log_info "Esperando webhook para $resource en $namespace (timeout: ${timeout}s)..."
    while [ $elapsed -lt $timeout ]; do
        if kubectl get "$resource" -n "$namespace" &>/dev/null; then
            log_success "Webhook listo para $resource"
            return 0
        fi
        elapsed=$((elapsed + interval))
        sleep $interval
    done
    log_warn "Timeout esperando webhook para $resource"
    return 1
}

# =============================================================================
# Generación de inventario
# =============================================================================
generate_inventory() {
    log_step "Generando inventario"

    cat > "$INVENTORY_FILE" <<HEADER
# Inventario del Playground

- **Fecha:** $(date '+%Y-%m-%d %H:%M:%S')
- **Profile:** ${PLAYGROUND_PROFILE}
- **Kubernetes:** $(kubectl version --short 2>/dev/null | head -1 || echo "N/A")
HEADER

    # IP del clúster
    local cluster_ip
    cluster_ip=$(minikube ip --profile="$PLAYGROUND_PROFILE" 2>/dev/null || echo "N/A")
    echo "- **IP del clúster:** ${cluster_ip}" >> "$INVENTORY_FILE"
    echo "" >> "$INVENTORY_FILE"

    # Namespaces
    echo "## Namespaces" >> "$INVENTORY_FILE"
    echo "" >> "$INVENTORY_FILE"
    echo "| Namespace | Estado |" >> "$INVENTORY_FILE"
    echo "|---|---|" >> "$INVENTORY_FILE"
    kubectl get namespaces --no-headers 2>/dev/null | while read -r ns status _; do
        echo "| ${ns} | ${status} |" >> "$INVENTORY_FILE"
    done
    echo "" >> "$INVENTORY_FILE"

    # Pods
    echo "## Pods" >> "$INVENTORY_FILE"
    echo "" >> "$INVENTORY_FILE"
    echo "| Namespace | Pod | Ready | Status |" >> "$INVENTORY_FILE"
    echo "|---|---|---|---|" >> "$INVENTORY_FILE"
    kubectl get pods --all-namespaces --no-headers 2>/dev/null | while read -r ns pod ready status _; do
        echo "| ${ns} | ${pod} | ${ready} | ${status} |" >> "$INVENTORY_FILE"
    done
    echo "" >> "$INVENTORY_FILE"

    # Servicios
    echo "## Servicios" >> "$INVENTORY_FILE"
    echo "" >> "$INVENTORY_FILE"
    echo "| Namespace | Servicio | Tipo | Puerto(s) |" >> "$INVENTORY_FILE"
    echo "|---|---|---|---|" >> "$INVENTORY_FILE"
    kubectl get services --all-namespaces --no-headers 2>/dev/null | while read -r ns svc type ports _; do
        echo "| ${ns} | ${svc} | ${type} | ${ports} |" >> "$INVENTORY_FILE"
    done
    echo "" >> "$INVENTORY_FILE"

    # Ingress
    echo "## Ingress" >> "$INVENTORY_FILE"
    echo "" >> "$INVENTORY_FILE"
    kubectl get ingress --all-namespaces 2>/dev/null | tail -n +2 >> "$INVENTORY_FILE" || echo "No hay ingress configurados" >> "$INVENTORY_FILE"
    echo "" >> "$INVENTORY_FILE"

    # Addons de Minikube
    echo "## Addons de Minikube" >> "$INVENTORY_FILE"
    echo "" >> "$INVENTORY_FILE"
    minikube addons list --profile="$PLAYGROUND_PROFILE" 2>/dev/null | tail -n +2 >> "$INVENTORY_FILE" || true
    echo "" >> "$INVENTORY_FILE"

    # Versiones de componentes clave
    echo "## Versiones" >> "$INVENTORY_FILE"
    echo "" >> "$INVENTORY_FILE"
    echo "| Componente | Versión |" >> "$INVENTORY_FILE"
    echo "|---|---|" >> "$INVENTORY_FILE"

    local istio_ver
    istio_ver=$(istioctl version --remote=false 2>/dev/null | head -1 || echo "No instalado")
    echo "| Istio | ${istio_ver} |" >> "$INVENTORY_FILE"

    local argocd_ver
    argocd_ver=$(argocd version --client --short 2>/dev/null || echo "No instalado")
    echo "| Argo CD | ${argocd_ver} |" >> "$INVENTORY_FILE"

    local rollout_ver
    rollout_ver=$(kubectl argo rollouts version 2>/dev/null | head -1 || echo "No instalado")
    echo "| Argo Rollouts | ${rollout_ver} |" >> "$INVENTORY_FILE"

    local nginx_ver
    nginx_ver=$(kubectl get deployment ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "No instalado")
    echo "| NGINX Ingress | ${nginx_ver} |" >> "$INVENTORY_FILE"

    local traefik_ver
    traefik_ver=$(kubectl get deployment traefik -n kube-system -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "No instalado")
    echo "| Traefik | ${traefik_ver} |" >> "$INVENTORY_FILE"

    echo "" >> "$INVENTORY_FILE"
    echo "---" >> "$INVENTORY_FILE"
    echo "_Generado automáticamente por k8s-deployer-playground_" >> "$INVENTORY_FILE"

    log_success "Inventario generado: ${INVENTORY_FILE}"
}

# =============================================================================
# Validación de profile
# =============================================================================
check_profile_in_use() {
    local profile=$1
    if minikube status --profile="$profile" 2>/dev/null | grep -q "Running"; then
        log_warn "El profile '${profile}' ya está en uso y ejecutándose"
        return 0
    fi
    return 1
}
