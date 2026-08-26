# Control Panel - K8s Deployer Playground

## URLs de acceso rápido

| UI | URL | Credenciales |
|---|---|---|
| **Argo CD** | http://192.168.58.2:30246 | admin / [ver abajo](#argocd) |
| **Traefik Dashboard** | http://192.168.58.200 | — |
| **Argo Rollouts** | port-forward (ver abajo) | — |

---

## Argo CD

**Acceso:** `minikube service argocd-server -n argocd --url`

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

**Acceso directo:** http://192.168.58.200

**Acceso via minikube:** `minikube service traefik -n kube-system --url`

**Dashboard:** Habilitado en `kube-system` via Helm chart

**IngressClass:** `traefik`

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

## NGINX Ingress

**Acceso:** http://192.168.58.2:30246

**IngressClass:** `nginx` (default)

**Ingress rules:**

| Host | Servicio |
|---|---|
| `frontend.nginx.demo.local` | frontend:8080 |
| `api.nginx.demo.local` | api:8081 |
| `nginx.demo.local` | nginx-comparison:8080 |

---

## Traefik Ingress

**Ingress rules:**

| Host | Servicio |
|---|---|
| `frontend.traefik.demo.local` | frontend:8080 |
| `api.traefik.demo.local` | api:8081 |
| `traefik.demo.local` | nginx-comparison:8080 |

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
| Minikube | 192.168.58.2 | — |
| Traefik (LB) | 192.168.58.200 | 80, 443 |
| MetalLB pool | 192.168.58.200-250 | — |
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
minikube service argocd-server -n argocd --url

# Acceder a Traefik Dashboard
minikube service traefik -n kube-system --url

# Abrir Argo Rollouts Dashboard
kubectl argo rollouts dashboard
```
