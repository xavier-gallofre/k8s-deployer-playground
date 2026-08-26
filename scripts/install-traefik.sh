#!/usr/bin/env bash
# =============================================================================
# install-traefik.sh - Instalación manual de Traefik
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

main() {
    log_step "Instalando Traefik (Helm)"

    if kubectl get deployment traefik -n kube-system &>/dev/null; then
        log_warn "Traefik ya instalado. ¿Reinstalar? (s/N)"
        read -p "> " confirm
        if [[ ! "$confirm" =~ ^[sS]$ ]]; then
            return
        fi
        helm uninstall traefik -n kube-system 2>/dev/null || true
    fi

    # Añadir repo Helm
    helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true
    helm repo update

    # Instalar
    helm install traefik traefik/traefik \
        --namespace kube-system \
        --set ports.web.nodePort=30080 \
        --set ports.websecure.nodePort=30443 \
        --set service.type=LoadBalancer \
        --set resources.requests.cpu=100m \
        --set resources.requests.memory=128Mi

    wait_for_deployment "kube-system" "traefik"

    log_success "Traefik instalado"
    echo ""
    log_info "Dashboard disponible en:"
    echo "  kubectl port-forward -n kube-system svc/traefik 9000:9000"
    echo ""
    log_info "O acceder directamente:"
    echo "  minikube service traefik -n kube-system --url"
}

main "$@"
