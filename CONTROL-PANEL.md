# Control Panel - K8s Deployer Playground

## URLs de acceso rápido

Obtener la IP de Minikube:

```bash
MINIKUBE_IP=$(minikube ip --profile=k8s-playground)
```

| UI | URL | Credenciales |
|---|---|---|
| **Argo CD** | `http://$MINIKUBE_IP:30246` | admin / [ver abajo](#argocd) |
| **Traefik Dashboard** | `http://$(minikube service traefik -n kube-system --url --profile=k8s-playground 2>/dev/null)` | — |
| **NGINX Ingress** | `http://$MINIKUBE_IP:30246` | — |
| **Argo Rollouts** | port-forward (ver abajo) | — |

---

## Argo CD

**Acceso:** `minikube service argocd-server -n argocd --url --profile=k8s-playground`

**Usuario:** `admin`

**Contraseña:**

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**UI Features:**
- Aplicaciones desplegadas
- Sync status
- Health status
- Historial de rollbacks

---

## Traefik

**Acceso directo:** Ver IP de LoadBalancer con `kubectl get svc traefik -n kube-system`

**Acceso via minikube:** `minikube service traefik -n kube-system --url --profile=k8s-playground`

**Dashboard:** Habilitado en `kube-system` via Helm chart

**IngressClass:** `traefik`

---

## NGINX Ingress

**Acceso:** `http://$(minikube ip --profile=k8s-playground):30246`

**IngressClass:** `nginx` (default)

**Ingress rules:**

| Host | Servicio |
|---|---|
| `frontend.nginx.demo.local` | frontend:8080 |
| `api.nginx.demo.local` | api:8081 |
| `nginx.demo.local` | nginx-comparison:8080 |

---

## Argo Rollouts Dashboard

**Acceso:**

```bash
kubectl argo rollouts dashboard
```

Abre http://localhost:3100 en tu navegador.

**Rollouts disponibles:**

| Rollout | Estrategia | Estado |
|---|---|---|
| `api-rollout-canary` | Canary | ✅ Healthy |
| `api-rollout-bluegreen` | Blue/Green | ✅ Healthy |
| `api-rollout-ab` | A/B Testing | ✅ Healthy |

---

## Istio

**Gateway:** `playground-gateway` en namespace `demo`

**VirtualServices:**

| VirtualService | Host | Gateway |
|---|---|---|
| `frontend-vsvc` | frontend | playground-gateway |
| `api-vsvc` | api | playground-gateway |

---

## IPs y puertos importantes

| Componente | IP | Puerto |
|---|---|---|
| Minikube | `$(minikube ip --profile=k8s-playground)` | — |
| Traefik (LB) | Ver `kubectl get svc traefik -n kube-system` | 80, 443 |
| MetalLB pool | `$(minikube ip --profile=k8s-playground)` .200-.250 | — |
| NGINX Ingress | NodePort | 30246, 31594 |

---

## Comandos útiles

```bash
# Ver todos los pods
kubectl get pods -A

# Ver pods de demo
kubectl get pods -n demo

# Ver rollouts
kubectl argo rollouts list rollouts -n demo

# Ver Ingress
kubectl get ingress -n demo

# Ver VirtualServices
kubectl get virtualservice -n demo

# Ver Argo CD apps
argocd app list

# Acceder a Argo CD UI
minikube service argocd-server -n argocd --url --profile=k8s-playground

# Acceder a Traefik Dashboard
minikube service traefik -n kube-system --url --profile=k8s-playground

# Abrir Argo Rollouts Dashboard
kubectl argo rollouts dashboard

# Obtener IP de Minikube
minikube ip --profile=k8s-playground
```
