# Arquitectura del Playground

## Visión general

El playground simula un entorno de producción en miniatura con todas las capas necesarias para despliegues orquestados de microservicios.

## Diagrama de componentes

```mermaid
graph TB
    subgraph "Minikube Cluster"
        subgraph "Ingress Layer"
            NGINX["NGINX Ingress<br/>:80/:443<br/>namespace: ingress-nginx"]
            TRAEFIK["Traefik Ingress<br/>NodePort 30080/30443<br/>namespace: kube-system"]
        end

        subgraph "Service Mesh - Istio"
            ISTIOD["istiod<br/>Control Plane<br/>namespace: istio-system"]
            ZTUNNEL["ztunnel<br/>L4 Proxy - mTLS<br/>ambient mode"]
        end

        subgraph "Workloads - namespace: demo"
            FE["frontend<br/>:8080"]
            API["api<br/>:8081"]
            CACHE["cache<br/>:6379"]
        end

        subgraph "GitOps & Rollouts"
            ARGOCD["Argo CD<br/>:8080<br/>namespace: argocd"]
            ROLLOUTS["Argo Rollouts<br/>Controller<br/>namespace: argo-rollouts"]
        end

        METALLB["MetalLB<br/>LoadBalancer<br/>namespace: metallb-system"]
    end

    HOST["Host Machine"] -->|"minikube ip"| METALLB
    METALLB --> NGINX
    METALLB --> TRAEFIK
    NGINX --> ZTUNNEL
    TRAEFIK --> ZTUNNEL
    ZTUNNEL --> FE
    ZTUNNEL --> API
    ZTUNNEL --> CACHE
    ISTIOD --> ZTUNNEL
    ARGOCD -->|"sync"| ROLLOUTS
    ROLLOUTS -->|"traffic split"| ISTIOD
    API -->|"reads/writes"| CACHE
    FE -->|"proxies /api"| API
```

### Flujo de tráfico

```mermaid
sequenceDiagram
    participant H as Host
    participant LB as MetalLB
    participant ING as Ingress Controller
    participant IST as Istio ztunnel
    participant Svc as Service (frontend/api/cache)

    H->>LB: Request (minikube ip:port)
    LB->>ING: Forward to IngressClass
    ING->>ING: Match Ingress rules
    ING->>IST: Route to service
    IST->>IST: mTLS + metrics
    IST->>Svc: Forward to pod
    Svc-->>IST: Response
    IST-->>ING: Response
    ING-->>LB: Response
    LB-->>H: Response
```

### Flujo de despliegue progresivo (Canary)

```mermaid
sequenceDiagram
    participant G as Git Repo
    participant ACD as Argo CD
    participant AR as Argo Rollouts
    participant IST as Istio
    participant P as Pods (v1/v2)

    G->>ACD: Push new manifest
    ACD->>AR: Sync Rollout resource
    AR->>AR: Set weight 10% canary
    AR->>IST: Update VirtualService
    IST->>P: 10% → v2, 90% → v1
    AR->>AR: Pause + check metrics
    AR->>AR: Set weight 25%
    AR->>IST: Update VirtualService
    IST->>P: 25% → v2, 75% → v1
    AR->>AR: Pause + check metrics
    AR->>AR: Set weight 100%
    AR->>IST: Update VirtualService
    IST->>P: 100% → v2
```

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
