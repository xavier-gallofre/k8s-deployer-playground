# Arquitectura del Playground

## Visión general

El playground simula un entorno de producción en miniatura con todas las capas necesarias para despliegues orquestados de microservicios.

## Diagrama de componentes

```
                        Internet / Host
                              │
                              ▼
                    ┌─────────────────┐
                    │   LoadBalancer   │
                    │   (metallb)      │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │ NGINX        │ │ Traefik      │ │ Istio        │
    │ Ingress      │ │ Ingress      │ │ Gateway      │
    │ :80/:443     │ │ :8080/:8443  │ │ :15000-15021 │
    └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
           │                │                │
           └────────────────┼────────────────┘
                            │
                            ▼
              ┌─────────────────────────┐
              │     Service Mesh        │
              │     (Istio ztunnel)     │
              │   mTLS + Traffic Mgmt   │
              └───────────┬─────────────┘
                          │
          ┌───────────────┼───────────────┐
          │               │               │
          ▼               ▼               ▼
  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
  │  frontend    │ │  api         │ │  cache       │
  │  Service     │ │  Service     │ │  Service     │
  │  :8080       │ │  :8081       │ │  :6379       │
  └──────────────┘ └──────────────┘ └──────────────┘

          ┌─────────────────────────────────┐
          │         Control Plane           │
          │                                 │
          │  ┌───────────┐  ┌───────────┐  │
          │  │ Argo CD   │  │ Argo      │  │
          │  │ :8080     │  │ Rollouts  │  │
          │  └───────────┘  └───────────┘  │
          └─────────────────────────────────┘
```

## Flujo de tráfico

### Request externo → Aplicación

1. El tráfico llega al LoadBalancer (metallb IP)
2. El Ingress Controller correspondiente (NGINX o Traefik) procesa las reglas de routing
3. Istio ztunnel gestiona mTLS y métricas en capa 4
4. El servicio destino recibe el request

### Despliegue progresivo

1. Argo CD detecta cambio en el repo Git
2. Sincroniza el manifest del Rollout
3. Argo Rollouts orquesta el despliegue gradual
4. Istio/Gateway gestiona el split de tráfico
5. Análisis de métricas determina promoción o rollback

## Namespaces

| Namespace | Propósito |
|---|---|
| `default` | Namespace por defecto |
| `ingress-nginx` | Controlador NGINX Ingress |
| `kube-system` | Traefik y addons del sistema |
| `istio-system` | Istiod y componentes Istio |
| `argocd` | Argo CD server y components |
| `argo-rollouts` | Argo Rollouts controller |
| `demo` | Aplicaciones de ejemplo |

## Recursos del clúster

```
Minikube (recomendado):
├── CPU: 4 cores
├── Memoria: 8GB
├── Disco: 20GB
└── Driver: docker (default)
```

## Puertos expuestos

| Puerto | Servicio | Acceso |
|---|---|---|
| 80 | NGINX Ingress HTTP | `minikube ip` |
| 443 | NGINX Ingress HTTPS | `minikube ip` |
| 30000-32767 | NodePort Services | `minikube ip:<port>` |
| 8080 | Argo CD UI | `minikube service argocd-server -n argocd` |
| 9000 | Traefik Dashboard | `minikube service traefik -n kube-system` |
