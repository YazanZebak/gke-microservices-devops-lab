# GKE Deployment - Questions and Answers

## Question 1: Autopilot Mode in GKE

**Q:** In the README file, it is suggested to start a GKE cluster in "Autopilot" mode. Using this mode would solve the resource problem we observed. Briefly explain what Autopilot mode is and why it hides the problem.

**A:** Autopilot mode is a fully managed GKE offering where Google Cloud handles cluster infrastructure, node pools, and resource provisioning automatically. It scales nodes based on workload demands and manages node configuration without user intervention.

Autopilot hides the resource constraint problem because:

* **Automatic Scaling:** It provisions nodes as needed to satisfy pod resource requests, preventing scheduling failures.
* **Abstracted Infrastructure:** Users do not manage individual nodes or resource allocation; the platform handles it.
* **Guaranteed Requests:** Pods always get at least the CPU/memory they request, so resource limits on standard clusters don’t block scheduling.

**Trade-offs:**

* Higher cost compared to standard mode.
* Less control over cluster configuration and scheduling policies.
* Limited ability to choose node types, OS versions, or custom infrastructure settings.

For this project, we use standard mode to retain control over resources and cost optimization.

---

## Question 2: Kubernetes Resource Requests vs Limits

**Q:** Which parameter (`requests` or `limits`) actually matters when Kubernetes decides whether it can deploy a service on a worker node?

**A:** The **`requests`** parameter matters for scheduling.

Kubernetes only considers a pod’s `requests` when deciding where to place it. A pod is scheduled on a node only if the node has enough available CPU and memory to satisfy all requested resources.

* **`requests`:** Minimum guaranteed resources reserved for the pod; used by the scheduler.
* **`limits`:** Maximum resources a pod may consume; enforced at runtime but irrelevant for scheduling.

Reducing `requests` for non-critical services allows the scheduler to place more pods per node without increasing cluster capacity.

---

## Question 3: Reducing Resource Requirements

**Q:** Divide the CPU requests by 2 for two non-critical services to deploy all 
services on the cluster. Which services do you choose and why?

### Cluster capacity baseline

Our cluster has 2 nodes of type `e2-standard-2` (2 vCPU each). GKE reserves 
approximately 60m CPU per node for system components, giving schedulable capacity of:
```
2 × (2000m - 60m) = 3880m total
```

### Default CPU requests (load generator excluded)

| Service | CPU request |
|---|---|
| adservice | 200m |
| cartservice | 200m |
| redis-cart | 70m |
| checkoutservice | 100m |
| currencyservice | 100m |
| emailservice | 100m |
| frontend | 100m |
| paymentservice | 100m |
| productcatalogservice | 100m |
| recommendationservice | 100m |
| shippingservice | 100m |
| **Total** | **1370m** |

With the load generator disabled (saving 300m), the total of 1370m fits within 
the 3880m schedulable capacity on paper. However, GKE also runs system DaemonSets 
per node (kube-proxy, fluentd, metrics agents) which consume additional CPU beyond 
the 60m reservation. Reducing requests on two services provides real headroom 
against these system-level consumers.

### Observed vs requested CPU (from kubectl top pods, idle cluster)

| Service | Requested | Observed (idle) | Utilization |
|---|---|---|---|
| adservice | 200m | 2m | 1% |
| cartservice | 200m | 8m | 4% |
| checkoutservice | 100m | 1m | 1% |
| currencyservice | 100m | 3m | 3% |
| emailservice | 100m | 2m | 2% |
| frontend | 100m | 1m | 1% |
| paymentservice | 100m | 1m | 1% |
| productcatalogservice | 100m | 1m | 1% |
| recommendationservice | 100m | 3m | 3% |
| redis-cart | 70m | 3m | 4% |
| shippingservice | 100m | 1m | 1% |

Every service is heavily over-provisioned at idle. The two largest requestors 
with the lowest observed utilization are the best candidates for reduction.

### Services selected for reduction

**1. adservice** — `200m → 100m` (halved)

adservice has the largest gap between requested (200m) and observed (2m) CPU — 
only 1% utilization. It serves ad recommendations asynchronously and is never 
in the critical user-facing path (checkout, cart, payment). Reducing its request 
has no impact on application correctness or user-visible latency.

**2. cartservice** — `200m → 100m` (halved)

cartservice is the second largest requestor (200m) and the highest actual consumer 
at idle (8m). Its operations are I/O-bound — each request is primarily a single 
Redis read or write to `redis-cart`. The CPU bottleneck is never compute; it is 
always waiting for Redis. Halving the request still leaves 100m reserved, which 
is 12× its observed idle usage.

### After patches

| Service | Before | After | Saving |
|---|---|---|---|
| adservice | 200m | 100m | 100m |
| cartservice | 200m | 100m | 100m |
| load generator (disabled) | 300m | 0m | 300m |
| **Total saving** | | | **500m** |

The 500m total saving (patches + disabled load generator) provides comfortable 
headroom for system DaemonSets and leaves room for future services.

> **Memory limits:** Memory limits were increased from the base values based on 
> observed idle usage from `kubectl top pods`:
> 
> - **adservice:** idle usage (66Mi) already exceeds the base limit (64Mi), which 
>   would cause repeated OOMKill on startup. Increased to 128Mi (~2× idle), 
>   appropriate buffer for a JVM-based service that grows heap under load.
> - **cartservice:** idle usage (28Mi) is within the base limit (64Mi), but 
>   increased to 128Mi as a conservative buffer since peak usage under load is 
>   not yet measured. This will be revisited after performance evaluation.
> 
> General rule: always verify that memory limits exceed observed idle usage before 
> deploying. If observed idle > limit, OOMKill is guaranteed regardless of load.