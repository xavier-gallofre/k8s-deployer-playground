#!/usr/bin/env bash
# =============================================================================
# install-argo.sh - Instalación manual de Argo CD y Argo Rollouts
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

ARGO_CD_VERSION="${ARGO_CD_VERSION:-v3.5.1}"
ARGO_ROLLOUTS_VERSION="${ARGO_ROLLOUTS_VERSION:-v1.9.1}"

main() {
    install_argo_cd
    install_argo_rollouts
    configure_rollouts_for_istio
    show_access_info
}

install_argo_cd() {
    log_step "Instalando Argo CD $ARGO_CD_VERSION"

    if kubectl get ns argocd &>/dev/null; then
        log_warn "Argo CD ya instalado"
        return
    fi

    kubectl create namespace argocd

    kubectl apply -n argocd \
        -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGO_CD_VERSION}/manifests/install.yaml"

    wait_for_pods "argocd" "app.kubernetes.io/name=argocd-server"

    # Configurar password admin por defecto
    log_info "Configurando contraseña admin..."
    ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    log_success "Contraseña admin: $ARGOCD_PWD"

    # Instalar CLI si no existe
    if ! command -v argocd &>/dev/null; then
        log_info "Instalando Argo CD CLI..."
        curl -sSL -o /tmp/argocd "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
        sudo install -m 555 /tmp/argocd /usr/local/bin/argocd
        rm /tmp/argocd
    fi
}

install_argo_rollouts() {
    log_step "Instalando Argo Rollouts $ARGO_ROLLOUTS_VERSION"

    if kubectl get ns argo-rollouts &>/dev/null; then
        log_warn "Argo Rollouts ya instalado"
        return
    fi

    kubectl create namespace argo-rollouts

    kubectl apply -n argo-rollouts \
        -f "https://raw.githubusercontent.com/argoproj/argo-rollouts/${ARGO_ROLLOUTS_VERSION}/manifests/install.yaml"

    wait_for_pods "argo-rollouts"

    # Instalar plugin kubectl
    if ! command -v kubectl-argo-rollouts &>/dev/null; then
        log_info "Instalando plugin kubectl-argo-rollouts..."
        curl -sSL -o /tmp/kubectl-argo-rollouts "https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64"
        sudo install -m 555 /tmp/kubectl-argo-rollouts /usr/local/bin/kubectl-argo-rollouts
        rm /tmp/kubectl-argo-rollouts
    fi
}

configure_rollouts_for_istio() {
    log_step "Configurando Argo Rollouts para Istio"

    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argo-rollouts-config
  namespace: argo-rollouts
data:
  trafficManager: |
    istio:
      virtualServices:
      - name: \${name}-vsvc
        routes:
        - primary
EOF

    log_success "Configuración para Istio aplicada"
}

show_access_info() {
    log_step "Información de acceso"

    echo -e "${CYAN}Argo CD:${NC}"
    echo "  UI:        $(minikube service argocd-server -n argocd --url 2>/dev/null || echo 'minikube service argocd-server -n argocd')"
    echo "  Usuario:   admin"
    echo "  Password:  $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo 'ver logs anteriores')"
    echo ""
    echo -e "${CYAN}Argo Rollouts Dashboard:${NC}"
    echo "  kubectl argo rollouts dashboard"
    echo ""
}

main "$@"
