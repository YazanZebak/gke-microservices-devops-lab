# Autoscaling Strategy

## 1. Context and Motivation

Performance evaluation identified a saturation point at approximately **150
concurrent users**, with `cartservice` as the primary bottleneck. At saturation:

- `cartservice` CPU utilisation reached its limit (100m)
- Response times degraded sharply across all cart-related operations
- Other services remained underutilised, with CPU well below their requests

Without autoscaling, the cluster has a hard ceiling at this load level. Adding
more users beyond ~150 causes queuing, not graceful degradation — requests pile
up inside the single `cartservice` pod waiting for Redis responses.

The goal of this autoscaling strategy is to raise that ceiling automatically,
without manual intervention, while remaining cost-efficient on the existing
2-node cluster.

---

## 2. Strategy: HPA-First with Cluster Autoscaler as Safety Net

The strategy is deliberately layered:

```
Load increases
    │
    ▼
HPA on cartservice        ← primary responder (bottleneck identified)
HPA on frontend           ← secondary responder (entry point, traffic-correlated)
    │
    ▼
Cluster Autoscaler        ← triggered only if HPA needs more nodes
    │
    ▼
New node provisioned      ← within ~2-3 min on GKE Standard
```

### Why not VPA?

VPA adjusts resource *requests* on existing pods. For `cartservice`, the problem
is not that the pod lacks resources — it is that **a single pod serialises
concurrent Redis operations**. Adding CPU to one pod does not increase Redis
concurrency. HPA (more replicas) addresses the actual bottleneck: parallelism.

VPA is appropriate for services where the workload is compute-intensive and
benefits from a larger pod (e.g. a batch job). `cartservice` is I/O-bound and
benefits from more replicas, not a larger pod.

---

## 3. HPA Configuration Decisions

### 3.1 cartservice — primary scaler

| Parameter | Value | Justification |
|---|---|---|
| Metric | CPU utilisation | Observed CPU spike at saturation; aligns with measured bottleneck |
| Target | 60% | Triggers scaling before saturation; leaves headroom per replica |
| Min replicas | 1 | Baseline — single pod is sufficient at low load |
| Max replicas | 5 | 5 × 100m = 500m CPU request; fits within cluster without Cluster Autoscaler |
| Scale-down stabilisation | 120s | Prevents flapping after brief load spikes |

**Why 60% target:** At 100m CPU limit, 60% = 60m. Observed saturation began when
CPU approached the 100m limit. Triggering at 60m (60%) gives the scheduler time
to provision a new pod and have it ready before the original pod is overloaded.
A higher target (e.g. 80%) risks triggering after degradation has already begun.

**Why max 5:** Five replicas of `cartservice` (100m each) consume 500m total CPU
request. Combined with all other services (~970m after patches), this stays well
within the cluster's ~3880m schedulable capacity without requiring new nodes.

### 3.2 frontend — secondary scaler

| Parameter | Value | Justification |
|---|---|---|
| Metric | CPU utilisation | Correlates with concurrent user sessions |
| Target | 70% | Frontend is stateless and scales linearly; higher threshold is safe |
| Min replicas | 1 | Single pod at idle |
| Max replicas | 3 | Three replicas sufficient for the load range tested |

Frontend is stateless (session state is in Redis via `cartservice`) and scales
horizontally without coordination issues. It acts as the traffic distributor —
scaling it prevents the entry point from becoming a secondary bottleneck as
`cartservice` scales up and throughput increases.

### 3.3 Services deliberately excluded from HPA

| Service | Reason |
|---|---|
| `redis-cart` | Stateful; horizontal scaling requires Redis Cluster or Sentinel, not a simple HPA |
| `adservice` | Asynchronous, not in critical path; observed CPU 2m at idle |
| `productcatalogservice` | Subject to canary deployment; HPA would interfere with replica counts managed by the canary |
| All others | CPU observed <5m at idle; not near any limit; no evidence of bottleneck |

---

## 4. Cluster Autoscaler

The Cluster Autoscaler (CA) is enabled on GKE Standard clusters with a simple
flag at cluster creation or update. It is configured with:

- **Min nodes:** 2 — preserves the baseline cluster at idle
- **Max nodes:** 4 — allows two additional nodes for burst capacity
- **Scale-down delay:** 10 minutes — prevents premature node removal after load

CA activates only when HPA has scheduled pods that cannot fit on existing nodes
(i.e. `Pending` pods due to insufficient CPU/memory). In practice, with max 5
`cartservice` replicas and max 3 `frontend` replicas, the current 2-node cluster
can absorb most scaling events without CA involvement — it acts as a safety net
for unexpected sustained overload.

**Cost implication:** Each additional node (`e2-standard-2`) costs approximately
the same as the existing nodes. CA scales down automatically when load subsides,
limiting cost exposure.

---

## 5. Expected Behaviour Under Load

| Users | Expected state |
|---|---|
| 0–80 | Single `cartservice` pod, CPU ~40-50m (below HPA threshold) |
| 80–150 | HPA triggers ~120 users; second `cartservice` pod added |
| 150–250 | Third pod added; saturation point raised to ~300+ users |
| 300+ | `frontend` HPA may trigger; CA activated if pods are `Pending` |

The previous saturation point of ~150 users with 100% CPU on a single
`cartservice` pod should shift to >300 users across 3 pods, each operating below
60% CPU utilisation.

---

## 6. Performance Evaluation Plan

To validate the strategy, run Locust in three configurations using the GCE VM
load generator:

### Baseline (no autoscaling)
```
locust_users = 200
locust_spawn_rate = 5
```
Expected: degradation above ~150 users. Captures the pre-autoscaling ceiling.

### With HPA only
```
locust_users = 300
locust_spawn_rate = 5
```
Expected: smooth scaling at ~120 users; stable throughput up to 300.

### With HPA + Cluster Autoscaler
```
locust_users = 500
locust_spawn_rate = 10
```
Expected: CA adds nodes if needed; system sustains 500 users or degrades
gracefully (not suddenly).

**Metrics to collect from Prometheus/Grafana:**
- `cartservice` CPU utilisation over time (confirm HPA trigger)
- `cartservice` replica count over time (confirm scale-out)
- p50 / p95 / p99 response latency for `/cart` and `/checkout`
- Request throughput (RPS) vs user count
- Pod scheduling events (confirm CA behaviour if triggered)

---

## 7. Kustomize Integration

HPA resources are applied alongside the overlay, not inside it. They are
standalone `HorizontalPodAutoscaler` objects that reference existing deployments
by name. They do not require changes to the base manifests or the overlay
patches.

Apply with:
```bash
kubectl apply -f overlays/hpa/
```

Or add to `kustomization.yaml` under `resources:` if you want them part of the
same `kubectl apply -k overlays` command:
```yaml
resources:
  - ../microservices-demo/kustomize/base/
  - hpa/cartservice-hpa.yaml
  - hpa/frontend-hpa.yaml
```

---

## 8. Trade-offs and Limitations

| Trade-off | Detail |
|---|---|
| CPU-based HPA for I/O-bound service | CPU is a proxy for Redis pressure, not the root cause. A custom metric (e.g. requests/s from Prometheus) would be more accurate but requires additional adapter configuration. |
| Redis is not scaled | Redis remains a single instance. Under very high load (>500 users), Redis itself could become the bottleneck regardless of `cartservice` replica count. |
| Scale-down lag | Pods take 120s to scale down after load drops. Brief over-provisioning is acceptable; it prevents repeated scale-up/down cycles under variable load. |
| Cluster Autoscaler node provision time | A new node takes ~2-3 minutes to join. HPA must buffer the load during this window using existing replicas. |
| `productcatalogservice` excluded | The ongoing canary deployment makes HPA unsafe — it would override the replica split between v1 and v2. Autoscaling should be added after the canary is promoted. |