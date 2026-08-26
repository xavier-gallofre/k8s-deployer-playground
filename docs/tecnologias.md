# Tecnologías del Playground

## Minikube

**Versión:** v1.35.0  
**Papel:** Clúster Kubernetes local

Minikube es una herramienta oficial de Kubernetes que ejecuta un clúster de un solo nodo dentro de una máquina virtual o contenedor. Proporciona un entorno completo de Kubernetes para desarrollo y pruebas sin necesidad de infraestructura remota.

### Características principales

- Ejecución local con Docker, Podman, VirtualBox o KVM
- Soporte para addons que extienden funcionalidades
- Integración con `minikube tunnel` para acceso LoadBalancer
- Perfilado de recursos configurable (CPU, memoria, disco)

### En este playground

Minikube aloja todos los componentes. Se configura con 4 CPU, 8GB RAM, 20GB disco y driver Docker.

---

## Helm

**Versión:** v3.21.4  
**Papel:** Gestor de paquetes de Kubernetes

Helm es el gestor de paquetes estándar para Kubernetes. Simplifica la instalación y gestión de aplicaciones complejas mediante charts predefinidos.

### En este playground

Se utiliza para instalar Traefik y NGINX Ingress Controller. Es un prerequisito requerido por los scripts de setup.

---

## NGINX Ingress Controller

**Versión:** v1.11.3  
**Papel:** Controlador de Ingress

NGINX Ingress Controller es el controlador de ingress más utilizado en producción. Implementa la API `Ingress` de Kubernetes usando NGINX como backend de proxy.

### En este playground

Se instala via `minikube addon enable ingress`. Se ejecuta en el namespace `ingress-nginx` con IngressClass `nginx` (predeterminado).

---

## Traefik

**Versión:** v3.7.11  
**Papel:** Controlador de Ingress moderno

Traefik es un reverse proxy y load balancer cloud-native diseñado para microservicios. Se integra nativamente con Kubernetes y otros orquestadores.

### Características principales

- Dashboard web integrado para visualización de rutas
- Soporte nativo para Let's Encrypt y TLS automático
- Descubrimiento automático de servicios
- Soporte para middleware (rate limiting, auth, headers)
- Compatibilidad con API Gateway de Kubernetes

### En este playground

Se instala via Helm en el namespace `kube-system`. MetalLB le asigna una IP LoadBalancer. IngressClass `traefik`.

---

## Istio

**Versión:** v1.30.0  
**Papel:** Service mesh

Istio extiende Kubernetes para establecer una red programable y consciente de la aplicación. Proporciona gestión de tráfico, telemetría y seguridad a despliegues complejos.

### Componentes principales

- **istiod**: Servidor de control que gestiona configuración, certificados y descubrimiento
- **ztunnel**: Proxy de capa 4 para el modo ambient (rendimiento y seguridad)
- **Envoy**: Proxy de servicio de capa 7 (opcional, para features avanzadas)

### En este playground

- Se instala en modo minimal con istiod
- Proporciona traffic splitting para Argo Rollouts
- Ofrece observabilidad de tráfico entre microservicios
- Gestiona mTLS transparente

---

## Argo CD

**Versión:** v3.5.1  
**Papel:** GitOps y sincronización declarativa

Argo CD es un controlador de entrega de aplicaciones declarativo para Kubernetes. Observa repositorios Git y sincroniza el estado deseado con el estado actual del clúster.

### Características principales

- Sincronización automática o manual desde Git
- UI web para visualizar estado y diferencias
- Soporte para Kustomize, Helm, y manifests planos
- RBAC y multi-tenancy
- Webhooks para sincronización reactiva

### En este playground

- Se instala en modo no-HA (suficiente para desarrollo)
- Conecta con repositorios Git que contienen los manifests
- Gestiona el ciclo de vida de las aplicaciones de ejemplo

---

## Argo Rollouts

**Versión:** v1.9.1  
**Papel:** Despliegues progresivos

Argo Rollouts es un controlador Kubernetes que gestiona despliegues progresivos con soporte para múltiples estrategias de release.

### Estrategias soportadas

| Estrategia | Descripción |
|---|---|
| **Canary** | Despliegue gradual por porcentaje de tráfico |
| **Blue/Green** | Swap completo entre versiones con switch de tráfico |
| **A/B Testing** | Routing basado en experimentos con métricas |

### Integración

- **Istio**: Traffic splitting nativo para control fino de tráfico
- **NGINX/Traefik**: Soporte via Ingress annotations
- **Prometheus**: Análisis de métricas para promoción automática

### En este playground

Se configura para trabajar con Istio como proveedor de traffic splitting. Cada estrategia tiene sus propios manifests y templates de análisis.

---

## Interacción entre componentes

```
┌─────────────────────────────────────────────────────┐
│                    Minikube                          │
│                                                      │
│  ┌──────────────┐     ┌──────────────────────────┐  │
│  │ NGINX/Traefik│◄────│       Istio               │  │
│  │  Ingress     │     │  (istiod)                 │  │
│  └──────┬───────┘     └────────────┬─────────────┘  │
│         │                          │                  │
│         ▼                          ▼                  │
│  ┌─────────────────────────────────────────────┐    │
│  │           Microservicios (Pods)              │    │
│  │  frontend ←──► api ←──► cache                │    │
│  └─────────────────────────────────────────────┘    │
│                                                      │
│  ┌──────────────┐     ┌──────────────────────────┐  │
│  │   Argo CD    │────►│   Argo Rollouts           │  │
│  │  (GitOps)    │     │  (Canary/BG/AB)           │  │
│  └──────────────┘     └──────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```
