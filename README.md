# K8s Deployer Playground

Entorno local reproducible para experimentar con despliegues orquestados en Kubernetes.

## Descripción

Este proyecto proporciona un clúster Minikube preconfigurado con las herramientas necesarias para practicar estrategias de despliegue en un entorno controlado. Incluye controladores de Ingress (NGINX y Traefik), un service mesh (Istio), y herramientas de despliegue progresivo (Argo CD + Argo Rollouts).

## Componentes

| Componente | Versión | Propósito |
|---|---|---|
| Minikube | v1.35.0 | Clúster K8s local |
| Helm | v3.21.4 | Gestor de paquetes |
| NGINX Ingress | v1.11.3 | Controller de ingress clásico |
| Traefik | v3.7.11 | Controller de ingress moderno |
| Istio | v1.30.0 | Service mesh |
| Argo CD | v3.5.1 | GitOps y sincronización declarativa |
| Argo Rollouts | v1.9.1 | Despliegues progresivos |

## Requisitos previos

- Docker o Podman instalado
- `kubectl` configurado
- `curl` disponible
- Mínimo 4GB RAM libre
- ~10GB de espacio en disco

## Inicio rápido

```bash
# Instalación completa automatizada
./scripts/setup.sh

# Verificar estado
kubectl get nodes
kubectl get pods -A
```

## Guía paso a paso

Ver [docs/guia-setup.md](docs/guia-setup.md) para instalación manual detallada.

## Estrategias de despliegue

El playground incluye ejemplos de tres estrategias principales:

- **Canary** → Despliegue gradual por porcentaje de tráfico
- **Blue/Green** → Swap completo entre versiones
- **A/B Testing** → Routing basado en headers/cookies

Ver [docs/estrategias-despliegue.md](docs/estrategias-despliegue.md) para detalles.

## Estructura del proyecto

```
├── docs/                    # Documentación
├── scripts/                 # Scripts de automatización
├── apps/                    # Aplicaciones de ejemplo
│   ├── microservices-demo/  # App multi-servicio con Rollouts
│   │   ├── base/            # Deployments y Services base
│   │   ├── canary/          # Estrategia Canary
│   │   ├── bluegreen/       # Estrategia Blue/Green
│   │   └── abtesting/       # Estrategia A/B Testing
│   └── nginx-comparison/    # Comparativa NGINX vs Traefik
├── argocd/                  # Configuraciones de Argo CD
├── istio/                   # Configuraciones de Istio
├── CONTROL-PANEL.md         # URLs de acceso a todas las UIs
└── kustomization.yaml       # Kustomize root
```

## Control Panel

Ver [CONTROL-PANEL.md](CONTROL-PANEL.md) para URLs de acceso a Argo CD, Traefik Dashboard, Argo Rollouts, y otros servicios.

## User Stories

Ver [docs/user-stories.md](docs/user-stories.md) para el seguimiento de requisitos y estado de cada iteración.

## Teardown

```bash
./scripts/teardown.sh
```

Esto detiene y elimina el clúster Minikube, liberando todos los recursos.
