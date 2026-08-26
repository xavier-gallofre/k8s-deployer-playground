#!/usr/bin/env bash
# =============================================================================
# helpers.sh - Funciones comunes para scripts de setup
# =============================================================================
set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Directorio base del proyecto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"
}

check_command() {
    if ! command -v "$1" &>/dev/null; then
        log_error "$1 no está instalado"
        return 1
    fi
    log_success "$1 encontrado: $(command -v "$1")"
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
