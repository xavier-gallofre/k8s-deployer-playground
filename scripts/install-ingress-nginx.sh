#!/usr/bin/env bash
# =============================================================================
# install-ingress-nginx.sh - Instalación manual de NGINX Ingress Controller
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

main() {
    log_step "Instalando NGINX Ingress Controller (Helm)"

    install_helm

    if kubectl get ns ingress-nginx &>/dev/null; then
        log_warn "NGINX Ingress ya instalado. ¿Reinstalar? (s/N)"
        read -p "> " confirm
        if [[ ! "$confirm" =~ ^[sS]$ ]]; then
            return
        fi
        kubectl delete ns ingress-nginx
    fi

    # Añadir repo Helm
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
    helm repo update

    # Instalar
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=LoadBalancer \
        --set controller.service.externalTrafficPolicy=Local \
        --set controller.resources.requests.cpu=100m \
        --set controller.resources.requests.memory=128Mi

    wait_for_pods "ingress-nginx" "app.kubernetes.io/name=ingress-nginx"

    log_success "NGINX Ingress instalado"
    echo ""
    log_info "Para acceder al dashboard:"
    echo "  kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80"
}

main "$@"
