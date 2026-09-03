# Guia de Prueba Paso a Paso

Guia completa para probar el entorno k8s-deployer-playground desde cero.

## Prerequisitos

| Herramienta | Versión mínima | Verificar |
|---|---|---|
| Docker | 20.10+ | `docker ps` |
| kubectl | 1.25+ | `kubectl version --client` |
| curl | cualquier | `curl --version` |
| Conexión a internet | -- | `curl -s https://google.com` |

Minikube, Helm, Argo CD CLI y kubectl-argo-rollouts se instalan automáticamente.

---

## Fase 1: Setup Completo

### Paso 1.1 — Verificar que no hay un cluster viejo

```bash
minikube status --profile=k8s-playground
```

Si muestra "Running" o "Stopped", eliminarlo:

```bash
minikube delete --profile=k8s-playground
```

### Paso 1.2 — Ejecutar el setup

```bash
./scripts/setup.sh
```

El setup toma ~5-10 minutos e instala en orden:

1. Minikube cluster (4 CPU, 8GB RAM)
2. MetalLB (LoadBalancer local)
3. NGINX Ingress Controller
4. Traefik (via Helm)
5. Istio (perfil minimal + addons)
6. Argo CD + Argo Rollouts
7. Kiali, Prometheus, Grafana

### Paso 1.3 — Verificar el resumen final

El script imprime algo como:

```
Resumen del entorno:
  Argo CD UI:        http://192.168.58.2:30246
  Traefik Dashboard: http://192.168.58.200
  Kiali:             istioctl dashboard kiali
  Prometheus:        kubectl port-forward -n istio-system svc/prometheus 9090:9090
  Grafana:           kubectl port-forward -n istio-system svc/grafana 3000:3000
```

### Paso 1.4 — Verificar namespaces

```bash
kubectl get ns
```

Deben existir estos namespaces:

| Namespace | Creado por |
|---|---|
| `metallb-system` | Helm (v0.13.12) |
| `ingress-nginx` | Minikube addon |
| `istio-system` | Istio |
| `argocd` | Setup |
| `argo-rollouts` | Setup |

### Paso 1.5 — Verificar pods de infraestructura

```bash
# MetalLB
kubectl get pods -n metallb-system

# NGINX Ingress
kubectl get pods -n ingress-nginx

# Traefik
kubectl get pods -n kube-system | grep traefik

# Istio
kubectl get pods -n istio-system

# Argo CD
kubectl get pods -n argocd

# Argo Rollouts
kubectl get pods -n argo-rollouts
```

Todos deben estar en estado `Running` o `Completed`.

### Paso 1.6 — Verificar MetalLB

```bash
# Verificar IP pool
kubectl get ipaddresspool -n metallb-system

# Verificar que Traefik tiene External-IP
kubectl get svc traefik -n kube-system

# Verificar que Istio Ingress Gateway tiene External-IP
kubectl get svc istio-ingressgateway -n istio-system
```

El `EXTERNAL-IP` de Traefik e Istio Gateway debe estar en el rango `192.168.58.200-250`.

---

## Fase 2: Desplegar Aplicaciones

### Paso 2.1 — Desplegar todo con Kustomize

```bash
kubectl apply -k .
```

### Paso 2.2 — Verificar pods en namespace demo

```bash
kubectl get pods -n demo
```

Debes ver ~18 pods:

| Pod | Réplicas | Descripción |
|---|---|---|
| `frontend-*` | 2 | Frontend NGINX |
| `api-*` | 2 | API base |
| `cache-*` | 1 | Redis |
| `api-rollout-canary-*` | 4 | Canary rollout |
| `api-rollout-bluegreen-*` | 4 | Blue/Green rollout |
| `api-rollout-ab-*` | 4 | A/B Testing rollout |
| `nginx-comparison-v1-*` | 2 | Comparison app v1 |
| `nginx-comparison-v2-*` | 2 | Comparison app v2 |

### Paso 2.3 — Verificar servicios

```bash
kubectl get svc -n demo
```

Servivos esperados:

| Servicio | Puerto | Tipo |
|---|---|---|
| `frontend` | 8080 | ClusterIP |
| `api` | 8081 | ClusterIP |
| `cache` | 6379 | ClusterIP |
| `api-stable` | 8081 | ClusterIP |
| `api-canary` | 8081 | ClusterIP |
| `api-active` | 8081 | ClusterIP |
| `api-preview` | 8081 | ClusterIP |
| `api-ab-stable` | 8081 | ClusterIP |
| `api-ab-canary` | 8081 | ClusterIP |
| `nginx-comparison` | 8080 | ClusterIP |

### Paso 2.4 — Verificar Ingresses

```bash
kubectl get ingress -n demo
```

Deben aparecer 6 Ingress resources (3 NGINX + 3 Traefik).

### Paso 2.5 — Verificar Istio resources

```bash
kubectl get gateway,virtualservice,destinationrule -n demo
```

Deben aparecer: 1 Gateway, 5 VirtualServices, 5 DestinationRules.

---

## Fase 3: Probar NGINX Ingress

### Paso 3.1 — Configurar DNS local

```bash
MINIKUBE_IP=$(minikube ip --profile=k8s-playground)

echo "$MINIKUBE_IP frontend.nginx.demo.local" | sudo tee -a /etc/hosts
echo "$MINIKUBE_IP api.nginx.demo.local" | sudo tee -a /etc/hosts
echo "$MINIKUBE_IP nginx.demo.local" | sudo tee -a /etc/hosts
```

### Paso 3.2 — Probar Frontend

```bash
curl http://frontend.nginx.demo.local
```

**Resultado esperado:** HTML del frontend o respuesta del servidor NGINX.

### Paso 3.3 — Probar API

```bash
curl http://api.nginx.demo.local
```

**Resultado esperado:** `API v1 - Hello from microservices demo`

### Paso 3.4 — Probar Comparison App

```bash
curl http://nginx.demo.local
```

**Resultado esperado:** `App v1 - NGINX vs Traefik comparison`

---

## Fase 4: Probar Traefik

### Paso 4.1 — Configurar DNS local

```bash
MINIKUBE_IP=$(minikube ip --profile=k8s-playground)

echo "$MINIKUBE_IP frontend.traefik.demo.local" | sudo tee -a /etc/hosts
echo "$MINIKUBE_IP api.traefik.demo.local" | sudo tee -a /etc/hosts
echo "$MINIKUBE_IP traefik.demo.local" | sudo tee -a /etc/hosts
```

### Paso 4.2 — Probar Frontend

```bash
curl http://frontend.traefik.demo.local
```

**Resultado esperado:** Igual que NGINX Ingress.

### Paso 4.3 — Probar API

```bash
curl http://api.traefik.demo.local
```

**Resultado esperado:** `API v1 - Hello from microservices demo`

### Paso 4.4 — Probar Comparison App

```bash
curl http://traefik.demo.local
```

**Resultado esperado:** `App v1 - NGINX vs Traefik comparison`

---

## Fase 5: Probar Istio Gateway

### Paso 5.1 — Verificar Istio Ingress Gateway

```bash
kubectl get svc istio-ingressgateway -n istio-system
```

Debe mostrar un `EXTERNAL-IP` en el rango `192.168.58.200-250` (MetalLB).

### Paso 5.2 — Port-forward al Istio Ingress Gateway

```bash
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80 &
```

### Paso 5.3 — Probar Frontend

```bash
curl -H "Host: frontend.demo.local" http://localhost:8080
```

**Resultado esperado:** Respuesta del frontend.

### Paso 5.4 — Probar API

```bash
curl -H "Host: api.demo.local" http://localhost:8080
```

**Resultado esperado:** `API v1 - Hello from microservices demo`

### Paso 5.5 — Detener port-forward

```bash
kill %1
```

---

## Fase 6: Probar Canary Rollout

### Paso 6.1 — Ver estado actual

```bash
kubectl argo rollouts get rollout api-rollout-canary -n demo
```

Debes ver 4 pods healthy con la versión actual.

### Paso 6.2 — Iniciar actualización

```bash
kubectl argo rollouts set image api-rollout-canary api=hashicorp/http-echo:0.2.3 -n demo
```

### Paso 6.3 — Observar el progreso

```bash
kubectl argo rollouts get rollout api-rollout-canary -n demo --watch
```

**Qué observar:**

1. Nuevos pods canary aparecen
2. Traffic weight sube gradualmente:
   - 10% → pausa 2 min (analysis ejecuta checks)
   - 25% → pausa 2 min
   - 50% → pausa 5 min
   - 100% → rollout completado
3. AnalysisTemplate consulta Prometheus para verificar success-rate >= 95%

### Paso 6.4 — Detener watch

```bash
# Presiona Ctrl+C en la terminal del watch
```

---

## Fase 7: Probar Blue/Green Rollout

### Paso 7.1 — Ver estado actual

```bash
kubectl argo rollouts get rollout api-rollout-bluegreen -n demo
```

### Paso 7.2 — Iniciar actualización

```bash
kubectl argo rollouts set image api-rollout-bluegreen api=hashicorp/http-echo:0.2.3 -n demo
```

### Paso 7.3 — Observar el progreso

```bash
kubectl argo rollouts get rollout api-rollout-bluegreen -n demo --watch
```

**Qué observar:**

1. Nuevos pods (green) aparecen junto a los viejos (blue)
2. `api-preview` apunta a los nuevos pods
3. `api-active` sigue apuntando a los viejos
4. **El rollout se PAUSA** esperando promoción manual
5. Smoke test (curl Job) verifica que el preview responde HTTP 200

### Paso 7.4 — Promover manualmente

```bash
kubectl argo rollouts promote api-rollout-bluegreen -n demo
```

**Qué observar después:**

1. `api-active` cambia a los nuevos pods
2. Los pods viejos se eliminan
3. Post-promotion analysis ejecuta success-rate check

---

## Fase 8: Probar A/B Testing Rollout

### Paso 8.1 — Ver estado actual

```bash
kubectl argo rollouts get rollout api-rollout-ab -n demo
```

### Paso 8.2 — Iniciar actualización

```bash
kubectl argo rollouts set image api-rollout-ab api=hashicorp/http-echo:0.2.3 -n demo
```

### Paso 8.3 — Probar routing por header

Necesitas acceso al Istio Gateway:

```bash
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80 &
```

Probar sin header (va a stable/v1):

```bash
curl -H "Host: api.demo.local" http://localhost:8080
```

**Resultado:** `API A/B testing` (versión stable)

Probar con header beta (va a canary/v2):

```bash
curl -H "Host: api.demo.local" -H "x-user-group: beta" http://localhost:8080
```

**Resultado:** `API A/B testing` (versión canary, con imagen actualizada)

### Paso 8.4 — Observar el progreso

```bash
kubectl argo rollouts get rollout api-rollout-ab -n demo --watch
```

**Qué observar:**

1. Traffic weight sube gradualmente:
   - 20% → pausa 5 min
   - 50% → pausa 5 min
   - 100% → rollout completado
2. Los headers `x-user-group: beta` siempre van a canary independientemente del weight

---

## Fase 9: Probar Observabilidad

### Paso 9.1 — Kiali (Service Mesh Dashboard)

```bash
istioctl dashboard kiali
```

**Qué verificar:**
- Topología del grafo muestra todos los servicios
- Traffic flow entre frontend → api → cache
- No hay errores en las conexiones

### Paso 9.2 — Prometheus

```bash
kubectl port-forward -n istio-system svc/prometheus 9090:9090
```

Abrir `http://localhost:9090` en el navegador.

**Query de prueba:**

```
sum(rate(http_requests_total{namespace="demo"}[1m])) by (pod)
```

### Paso 9.3 — Grafana

```bash
kubectl port-forward -n istio-system svc/grafana 3000:3000
```

Abrir `http://localhost:3000` en el navegador.

**Qué verificar:**
- Dashboards de Istio pre-configurados
- Métricas de tráfico en tiempo real

### Paso 9.4 — Argo CD UI

```bash
minikube service argocd-server -n argocd --url --profile=k8s-playground
```

**Credenciales:**

```bash
# Usuario
echo "admin"

# Password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

**Qué verificar:**
- Las 5 aplicaciones aparecen en la UI
- Status: "Synced" o "OutOfSync" (si no configuraste Argo CD con tu repo)

### Paso 9.5 — Argo Rollouts Dashboard

```bash
kubectl argo rollouts dashboard
```

Abrir `http://localhost:3100` en el navegador.

**Qué verificar:**
- Los 3 rollouts aparecen (canary, bluegreen, ab)
- Puedes ver el estado de cada uno
- Puedes promover/bluegreen desde la UI

---

## Fase 10: Limpieza

### Opción A — Script automatizado

```bash
./scripts/teardown.sh
```

### Opción B — Manual

```bash
# Eliminar aplicaciones
kubectl delete namespace demo --ignore-not-found

# Eliminar Argo CD y Rollouts
kubectl delete namespace argocd --ignore-not-found
kubectl delete namespace argo-rollouts --ignore-not-found

# Eliminar Istio
istioctl uninstall --purge -y 2>/dev/null || true
kubectl delete namespace istio-system --ignore-not-found

# Eliminar Helm releases
helm uninstall traefik -n kube-system 2>/dev/null || true

# Eliminar Minikube
minikube delete --profile=k8s-playground
```

### Opción C — Solo eliminar apps (mantener infraestructura)

```bash
kubectl delete namespace demo --ignore-not-found
kubectl delete -f argocd/application.yaml 2>/dev/null || true
kubectl delete -f argocd/rollouts-app.yaml 2>/dev/null || true
```

---

## Troubleshooting

### Pods en Pending

```bash
kubectl describe pod <pod-name> -n demo
# Buscar "Events" al final del output
```

Causa común: recursos insuficientes. Verificar:

```bash
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### Pods en CrashLoopBackOff

```bash
kubectl logs <pod-name> -n demo --tail=50
```

### Ingress no funciona

```bash
# Verificar Ingress
kubectl get ingress -n demo
kubectl describe ingress <ingress-name> -n demo

# Verificar que el controller está corriendo
kubectl get pods -n ingress-nginx
kubectl get pods -n kube-system | grep traefik
```

### Istio no enruta tráfico

```bash
# Verificar VirtualServices
kubectl get virtualservices -n demo

# Analizar problemas
istioctl analyze -n demo

# Verificar proxy config
istioctl proxy-config routes <pod-name> -n demo
```

### MetalLB no asigna External-IP

> **Nota:** MetalLB se instala **via Helm v0.13.12** (no con el addon obsoleto de Minikube, que era v0.9.6 y no soporta las CRDs `IPAddressPool`/`L2Advertisement`).

```bash
# Verificar IP pool
kubectl get ipaddresspool -n metallb-system

# Verificar L2Advertisement
kubectl get l2advertisements -n metallb-system

# Verificar logs del controller
kubectl logs -n metallb-system -l app=metallb,component=controller
```

Si recibes `connection refused` al aplicar el pool, el webhook del controller (puerto 9443) aún no está escuchando aunque el pod reporte `Ready`; espera unos segundos y reintenta, o aplica un pool temporal de prueba hasta que el webhook responda.

### Argo CD no sincroniza

```bash
# Verificar aplicaciones
argocd app list
argocd app get microservices-demo

# Verificar logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

---

## Referencia Rápida

| Acción | Comando |
|---|---|
| Ver pods | `kubectl get pods -n demo` |
| Ver servicios | `kubectl get svc -n demo` |
| Ver Ingresses | `kubectl get ingress -n demo` |
| Ver Istio | `kubectl get gateway,virtualservice,destinationrule -n demo` |
| Ver rollouts | `kubectl argo rollouts get rollout -n demo` |
| Ver logs | `kubectl logs -f <pod> -n demo` |
| Port-forward | `kubectl port-forward svc/<service> <port>:<port> -n demo` |
| Istio dashboard | `istioctl dashboard kiali` |
| Rollouts dashboard | `kubectl argo rollouts dashboard` |
| Argo CD dashboard | `minikube service argocd-server -n argocd --url` |
