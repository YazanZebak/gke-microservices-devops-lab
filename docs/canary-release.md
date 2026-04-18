# Canary Release with Istio

## Objective

Deploy a new version (`v2`) of a microservice alongside the stable version (`v1`),
route a controlled percentage of traffic to `v2`, and promote it to 100% without
disrupting in-flight requests.

---

## Microservice Selected: `productcatalogservice`

`productcatalogservice` was chosen for the following reasons:

- **Stateless:** reads product data from a static JSON file, no session or persistent state
- **User-visible output:** product names are rendered directly in the frontend UI, making
  version changes immediately observable without any tooling
- **Not in the critical checkout path:** a degraded response affects product listing only,
  not payments or cart operations — reducing risk during the canary window
- **Isolated:** it has no dependencies on other services that would complicate a split deployment

---

## What Changed in v2

A single product name in `products.json` was modified:

```json
"name": "Sunglasses [v2]"
```

This makes version detection trivial: browsing the product catalog reveals which version
served the request without requiring logs or metrics tooling.

---

## Architecture

```
Frontend pod
    |
    | gRPC (internal, ClusterIP)
    ↓
Istio VirtualService (75/25 split)
    |
    ├── productcatalogservice (v1) — 75% of requests
    └── productcatalogservice-v2  (v2) — 25% of requests
```

Istio intercepts all pod-to-pod traffic via sidecar proxies (Envoy). The VirtualService
defines the weighted routing rules. The DestinationRule maps `version` labels to named
subsets that the VirtualService references.

---

## Why Plain Kubernetes Isn't Enough

A Kubernetes Service routes traffic by round-robining across all pods whose labels match
its selector. Traffic split is controlled only by pod count — 25% requires exactly 1 v2
pod and 3 v1 pods. This approach:

- Cannot express exact percentages independent of replica count
- Requires over-provisioning to achieve fine-grained splits (e.g. 10% = 9 v1 + 1 v2)
- Provides no traffic observability or rollback primitives

Istio solves all three: weights are declared explicitly, replica counts are independent,
and Kiali provides real-time traffic visibility.

---

## Implementation

### Prerequisites

Istio installed with the `demo` profile and sidecar injection enabled on the `default` namespace:

```bash
istioctl install --set profile=demo -y
kubectl label namespace default istio-injection=enabled
kubectl rollout restart deployment -n default
```

After restart, all pods show `2/2` containers (app + Istio sidecar).

### Files Added

```
overlays/
  patches/
    productcatalogservice-v1-patch.yaml   # adds version: v1 label to existing deployment
  productcatalogservice-v2.yaml           # new v2 deployment
  istio/
    destinationrule.yaml                  # defines v1/v2 subsets by label
    virtualservice.yaml                   # 75/25 traffic split
```

### v1 Patch (`productcatalogservice-v1-patch.yaml`)

Adds the `version: v1` label to the existing base deployment so Istio can identify it
as a distinct subset. This is a Kustomize strategic merge patch — it modifies the existing
deployment without replacing it.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: productcatalogservice
spec:
  template:
    metadata:
      labels:
        app: productcatalogservice
        version: v1
```

### v2 Deployment (`productcatalogservice-v2.yaml`)

A new standalone deployment pointing at the Docker Hub image built from the modified source:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: productcatalogservice-v2
  labels:
    app: productcatalogservice
    version: v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: productcatalogservice
      version: v2
  template:
    metadata:
      labels:
        app: productcatalogservice
        version: v2
    spec:
      containers:
      - name: server
        image: yazanzk/productcatalogservice:v2
        ports:
        - containerPort: 3550
        env:
        - name: PORT
          value: "3550"
        - name: DISABLE_PROFILER
          value: "1"
```

Both v1 and v2 pods share the `app: productcatalogservice` label, which means they both
match the existing `productcatalogservice` Service selector. Without Istio, the Service
would round-robin across all pods. With Istio, the VirtualService overrides that behavior.

### DestinationRule (`istio/destinationrule.yaml`)

Defines named subsets by grouping pods by their `version` label:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: productcatalogservice
spec:
  host: productcatalogservice
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

### VirtualService (`istio/virtualservice.yaml`)

Applies the 75/25 traffic split at the request level:

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: productcatalogservice
spec:
  hosts:
  - productcatalogservice
  http:
  - route:
    - destination:
        host: productcatalogservice
        subset: v1
      weight: 75
    - destination:
        host: productcatalogservice
        subset: v2
      weight: 25
```

### Deployment

```bash
kubectl apply -k overlays/
```

---

## Traffic Verification

### Istio Sidecar Metrics

The Istio sidecar on the frontend pod tracks all outbound calls. Querying it directly
confirms the split without relying on Kiali or Prometheus:

```bash
kubectl exec -n default deployment/frontend -c istio-proxy \
  -- pilot-agent request GET stats | grep productcatalog
```

Observed request counts after sustained load:

| Destination | Requests | Share |
|---|---|---|
| `productcatalogservice` (v1) | 6421 | 74.5% |
| `productcatalogservice-v2` (v2) | 2196 | 25.5% |

Total: 8617 requests. The split matches the configured 75/25 weights within normal
statistical variance.

All responses returned `grpc_response_status.0` (success) with 0% error rate on both
versions, confirming v2 is functionally correct under real traffic.

### Kiali

Kiali visualizes the service graph with v1 and v2 shown as distinct nodes under the
`productcatalogservice` service, with traffic percentages displayed on the edges.

---

## Full Cutover to v2

Once v2 is validated, promotion to 100% follows a two-step sequence. Order matters:
traffic must shift before v1 is scaled down to avoid dropped requests.

**Step 1 — shift all traffic to v2:**

Update `overlays/istio/virtualservice.yaml`:

```yaml
- destination:
    host: productcatalogservice
    subset: v1
  weight: 0
- destination:
    host: productcatalogservice
    subset: v2
  weight: 100
```

Apply:

```bash
kubectl apply -f overlays/istio/virtualservice.yaml
```

**Step 2 — scale down v1:**

```bash
kubectl scale deployment productcatalogservice --replicas=0
```

In-flight requests to v1 complete naturally within the pod's `terminationGracePeriodSeconds`
before the container stops. No requests are dropped.

---

## Design Decisions

| Decision | Benefit | Trade-off |
|---|---|---|
| Istio over plain Kubernetes | Exact percentage weights, request-level control | Adds sidecar overhead to every pod |
| `productcatalogservice` as canary target | Stateless, user-visible, non-critical path | Change is cosmetic — does not test business logic differences |
| Docker Hub for v2 image | No Artifact Registry setup required | Public image; not suitable for production secrets |
| Kustomize patch for v1 label | Keeps base manifests unmodified | Extra patch file per service |
| Two-step cutover (traffic then scale) | No dropped requests during promotion | Requires manual sequencing |

---

## Operational Notes

- The `version` label on pods is purely for Istio subset matching. It has no effect on
  Kubernetes scheduling or the Service selector.
- Removing the VirtualService reverts routing to standard Kubernetes round-robin across
  all pods matching `app: productcatalogservice`.
- If v2 shows elevated error rates, rolling back is a single apply of the original
  VirtualService with `v1: 100, v2: 0`, then scaling v2 to 0.