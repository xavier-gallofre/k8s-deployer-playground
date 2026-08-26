# Tecnologías del Playground

## Minikube

**Versión:** v1.38.1  
**Papel:** Clúster Kubernetes local

Minikube es una herramienta oficial de Kubernetes que ejecuta un clúster de un solo nodo dentro de una máquina virtual o contenedor. Proporciona un entorno completo de Kubernetes para desarrollo y pruebas sin necesidad de infraestructura remota.

### Características principales

- Ejecución local con Docker, Podman, VirtualBox o KVM
- Soporte para addons que extienden funcionalidades
- Integración con `minikube tunnel` para acceso LoadBalancer
- Perfilado de recursos configurable (CPU, memoria, disco)

### En este playground

Minikube aloja todos los componentes. Se configura con recursos mínimos recomendados (2 CPU, 4GB RAM) y addons específicos para Ingress y metallb.

---

## NGINX Ingress Controller

**Versión:** v1.14.x  
**Papel:** Controlador de Ingress (retirado oficialmente)

NGINX Ingress Controller es el controlador de ingress más utilizado en producción. Implementa la API `Ingress` de Kubernetes usando NGINX como backend de proxy.

### Estado actual

⚠️ **Oficialmente retirado desde marzo 2026.** No recibe parches de seguridad ni correcciones de bugs. Minikube incluye un addon basado en esta versión.

### En este playground

Se utiliza para comparar su comportamiento con Traefik. El addon de minikube lo instala en el namespace `ingress-nginx`.

---

## Traefik

**Versión:** v3.x  
**Papel:** Controlador de Ingress moderno

Traefik es un reverse proxy y load balancer cloud-native diseñado para microservicios. Se integra nativamente con Kubernetes y autres orquestadores.

### Características principales

- Dashboard web integrado para visualización de rutas
- Soporte nativo para Let's Encrypt y TLS automático
- Descubrimiento automático de servicios
- Soporte para middleware (rate limiting, auth, headers)
- Compatibilidad con API Gateway de Kubernetes

### En este playground

Se instala como addon de minikube (alternativa recomendada al NGINX retirado). Registra su propio IngressClass como predeterminado.

---

## Istio

**Versión:** v1.30.x  
**Papel:** Service mesh

Istio extiende Kubernetes para establecer una red programable y consciente de la aplicación. Proporciona gestión de tráfico, telemetría y seguridad a despliegues complejos.

### Componentes principales

- **istiod**: Servidor de control que gestiona configuración, certificados y descubrimiento
- **ztunnel**: Proxy de capa 4 para el modo ambient (rendimiento y seguridad)
- **Envoy**: Proxy de servicio de capa 7 (opcional, para features avanzadas)

### Modo Ambient (GA)

Istio introduce el modo ambient que elimina la necesidad de sidecars. Utiliza un túnel zero-trust para L4 y añade Envoy solo cuando se necesita L7.

### En este playground

- Se instala en modo ambient (sin sidecar injection)
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
│  │  Ingress     │     │  (ambient mode, ztunnel)  │  │
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
