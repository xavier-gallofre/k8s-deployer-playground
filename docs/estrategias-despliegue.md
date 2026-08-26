# Estrategias de Despliegue

## Canary

### Concepto

El despliegue Canary envía una porción del tráfico a la nueva versión mientras el resto sigue yendo a la versión actual. Si las métricas son correctas, se promociona gradualmente hasta 100%.

### Flujo

```
100% v1 ──────────────────────┐
                              │
         v1.10% ──────┐       │
         v2.90%  ─────┼───────┤  Paso 1: 10% tráfico a v2
                      │       │
         v1.5%  ─────┼───────┤  Paso 2: 25% tráfico a v2
         v2.95% ─────┘       │
                              │
         v2.100% ─────────────┘  Paso 3: Promoción completa
```

### Argo Rollouts - Canary

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: api-rollout
spec:
  replicas: 4
  strategy:
    canary:
      canaryService: api-canary
      stableService: api-stable
      trafficRouting:
        istio:
          virtualServices:
          - name: api-vsvc
            routes:
            - primary
      analysis:
        templates:
        - templateName: success-rate
        startingStep: 2
        args:
        - name: service-name
          value: api-canary.demo.svc.cluster.local
      steps:
      - setWeight: 10
      - pause: {duration: 2m}
      - setWeight: 25
      - pause: {duration: 2m}
      - setWeight: 50
      - pause: {duration: 5m}
      - setWeight: 100
```

### Cuándo usar

- Validar comportamiento en producción con riesgo mínimo
- APIs con tráfico predecible
- Cuando necesitas métricas reales antes de promocionar

---

## Blue/Green

### Concepto

Blue/Green despliega la nueva versión (green) completa junto a la actual (blue). Una vez verificada, se redirige todo el tráfico de golpe.

### Flujo

```
Estado inicial:
  blue (v1)  ──── 100% tráfico
  green (v2) ──── 0% tráfico

Despliegue:
  blue (v1)  ──── 100% tráfico
  green (v2) ──── 0% tráfico (preparando)

Switch:
  blue (v1)  ──── 0% tráfico  (standby)
  green (v2) ──── 100% tráfico
```

### Argo Rollouts - Blue/Green

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: api-rollout
spec:
  replicas: 4
  strategy:
    blueGreen:
      activeService: api-active
      previewService: api-preview
      autoPromotionEnabled: false
      prePromotionAnalysis:
        templates:
        - templateName: smoke-test
      postPromotionAnalysis:
        templates:
        - templateName: success-rate
```

### Cuándo usar

- Releases que requieren testing exhaustivo antes del tráfico real
- Rollbacks inmediatos (el blue queda activo como backup)
- Cuando el costo de mantener dos instancias es aceptable

---

## A/B Testing

### Concepto

A/B Testing enruta tráfico basado en atributos específicos (headers, cookies, user-agent). Permite validar nueva funcionalidad con un segmento específico de usuarios.

### Flujo

```
Request con header: X-User-Group: beta
  → v2 (nueva versión)

Request sin header o X-User-Group: stable
  → v1 (versión actual)
```

### Argo Rollouts - A/B Testing

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: api-rollout
spec:
  replicas: 4
  strategy:
    canary:
      canaryService: api-canary
      stableService: api-stable
      trafficRouting:
        istio:
          virtualServices:
          - name: api-vsvc
            routes:
            - primary
      analysis:
        templates:
        - templateName: success-rate
      steps:
      - setWeight: 20
      - pause: {duration: 5m}
      - setWeight: 50
      - pause: {duration: 5m}
      - setWeight: 100
```

### VirtualService para A/B

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-vsvc
spec:
  hosts:
  - api
  http:
  - match:
    - headers:
        x-user-group:
          exact: beta
    route:
    - destination:
        host: api-canary
  - route:
    - destination:
        host: api-stable
```

### Cuándo usar

- Testing de features con usuarios específicos
- Validación de UI/UX antes del release general
- Experimentos controlados con métricas de negocio

---

## Comparativa

| Característica | Canary | Blue/Green | A/B Testing |
|---|---|---|---|
| Riesgo | Bajo | Muy bajo | Bajo |
| Velocidad | Gradual | Instantáneo | Gradual |
| Costo recursos | Bajo | Alto (2x) | Bajo |
| Rollback | Rápido | Instantáneo | Rápido |
| Complejidad | Media | Baja | Alta |
| Métricas | En tiempo real | Pre/post | Por segmento |
| Uso ideal | APIs | Apps críticas | Features/UI |

## Análisis de Métricas (AnalysisTemplate)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
  - name: service-name
  metrics:
  - name: success-rate
    interval: 30s
    count: 5
    successCondition: result[0] >= 0.95
    provider:
      prometheus:
        address: http://prometheus.istio-system:9090
        query: |
          sum(rate(http_requests_total{service="{{args.service-name}}",code=~"2.*"}[1m]))
          /
          sum(rate(http_requests_total{service="{{args.service-name}}"}[1m]))
```
