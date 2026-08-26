#!/usr/bin/env bash
# =============================================================================
# install-istio.sh - Instalación manual de Istio
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

ISTIO_VERSION="${ISTIO_VERSION:-1.30.0}"

main() {
    log_step "Instalando Istio $ISTIO_VERSION"

    if kubectl get ns istio-system &>/dev/null; then
        log_warn "Istio ya instalado. ¿Reinstalar? (s/N)"
        read -p "> " confirm
        if [[ ! "$confirm" =~ ^[sS]$ ]]; then
            return
        fi
        istioctl uninstall --purge -y
        kubectl delete ns istio-system
    fi

    # Instalar istioctl
    install_istioctl

    # Instalar Istio con perfil minimal
    log_info "Instalando Istio con perfil minimal..."
    istioctl install --set profile=minimal -y

    # Instalar sample de addons (Kiali, Prometheus, etc.)
    log_info "Instalando addons de Istio..."
    kubectl apply -f "https://raw.githubusercontent.com/istio/istio/release-1.30/samples/addons/prometheus.yaml" 2>/dev/null || true
    kubectl apply -f "https://raw.githubusercontent.com/istio/istio/release-1.30/samples/addons/grafana.yaml" 2>/dev/null || true
    kubectl apply -f "https://raw.githubusercontent.com/istio/istio/release-1.30/samples/addons/kiali.yaml" 2>/dev/null || true

    log_success "Istio instalado"
    echo ""
    log_info "Habilitar namespace para Istio:"
    echo "  kubectl label namespace demo istio-injection=enabled"
    echo ""
    log_info "Acceder a Kiali:"
    echo "  istioctl dashboard kiali"
}

install_istioctl() {
    if command -v istioctl &>/dev/null; then
        log_info "istioctl ya instalado"
        return
    fi

    log_info "Descargando istioctl..."
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION="$ISTIO_VERSION" sh -
    sudo cp "istio-${ISTIO_VERSION}/bin/istioctl" /usr/local/bin/
    rm -rf "istio-${ISTIO_VERSION}"
}

main "$@"
