#!/usr/bin/env bash
# =============================================================================
# teardown.sh - Eliminar completamente el playground
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

# Cargar .env si existe
if [ -f "${PROJECT_DIR}/.env" ]; then
    log_info "Cargando configuración desde .env"
    set -a
    source "${PROJECT_DIR}/.env"
    set +a
fi

main() {
    log_step "K8s Deployer Playground - Teardown"
    log_info "Profile: ${PLAYGROUND_PROFILE}"
    echo ""
    log_warn "Este script eliminará completamente el clúster Minikube '${PLAYGROUND_PROFILE}' y todos sus recursos."
    echo ""

    init_logging

    read -p "¿Estás seguro? (s/N): " confirm
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        log_info "Operación cancelada"
        exit 0
    fi

    delete_applications
    delete_argo
    delete_istio
    delete_minikube
    cleanup_local_files
    show_summary
}

delete_applications() {
    log_step "Eliminando aplicaciones de ejemplo"

    kubectl delete namespace demo --ignore-not-found --wait=false 2>/dev/null || true
    log_success "Namespace demo eliminado"
}

delete_argo() {
    log_step "Eliminando Argo CD y Rollouts"

    kubectl delete namespace argocd --ignore-not-found --wait=false 2>/dev/null || true
    kubectl delete namespace argo-rollouts --ignore-not-found --wait=false 2>/dev/null || true
    log_success "Argo CD y Rollouts eliminados"
}

delete_istio() {
    log_step "Eliminando Istio"

    if command -v istioctl &>/dev/null; then
        istioctl uninstall --purge -y 2>/dev/null || true
    fi
    kubectl delete namespace istio-system --ignore-not-found --wait=false 2>/dev/null || true
    log_success "Istio eliminado"
}

delete_minikube() {
    log_step "Deteniendo y eliminando Minikube"

    minikube delete --profile="$PLAYGROUND_PROFILE" 2>/dev/null || true
    log_success "Minikube '${PLAYGROUND_PROFILE}' eliminado"
}

cleanup_local_files() {
    log_step "Limpiando archivos temporales locales"

    rm -f /tmp/argocd 2>/dev/null || true
    rm -f /tmp/kubectl-argo-rollouts* 2>/dev/null || true
    rm -rf "${HOME}/.cache/istio" 2>/dev/null || true

    log_success "Archivos temporales limpiados"
}

show_summary() {
    log_step "Teardown completado"

    echo -e "${GREEN}El playground '${PLAYGROUND_PROFILE}' ha sido eliminado completamente.${NC}"
    echo ""
    echo -e "${CYAN}Log del teardown:${NC}"
    echo "  ${LOG_FILE}"
    echo ""
    echo -e "${CYAN}Para reinstalar:${NC}"
    echo "  PLAYGROUND_PROFILE=${PLAYGROUND_PROFILE} ./scripts/setup.sh"
    echo ""
}

main "$@"
