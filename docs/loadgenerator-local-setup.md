# Deploying the Load Generator on a Local Machine

## Objective

Understand why running the load generator outside the Kubernetes cluster matters
for accurate performance testing, and validate that the application is reachable
before moving to automated cloud deployment.

---

## Why run the load generator externally?

Running the load generator inside the cluster consumes CPU and memory that belong
to the application itself, which contaminates autoscaling metrics and latency
measurements. The Horizontal Pod Autoscaler reacts to resource signals — if the
load generator is inside the cluster, it creates artificial pressure that makes
HPA scale for the wrong reasons. External load generation isolates test traffic
from cluster resources, giving a realistic view of how the application handles
real user load.

---

## The frontend-as-gateway mental model

This is the key concept to understand before running any load test.

Online Boutique is designed so that the frontend is the only entry point for
external traffic. When a user opens the app in a browser, they hit the frontend's
LoadBalancer IP on port 80. The frontend then routes requests internally to
CartService, CheckoutService, ProductCatalogService, and others over gRPC —
using ClusterIP addresses that are only reachable inside the cluster.

This means:

- The load generator only needs to reach the **frontend's external IP** — nothing else
- Backend services (CartService, CheckoutService, etc.) are correctly unreachable
  from outside the cluster by design
- Running Locust from a VM in the same VPC is about **latency** (staying in the
  same datacenter as the cluster), not about needing special network access to
  backend pods

```
GCE VM (Locust)
      |
      | HTTP to frontend external IP
      ↓
  Frontend pod  (LoadBalancer — externally reachable)
      |
      | internal gRPC over ClusterIP
      ↓
  CartService, CheckoutService, ProductCatalogService, ...
  (ClusterIP only — not reachable from outside)
```

Trying to reach backend services directly from outside the cluster is not only
impossible without additional configuration — it is also architecturally wrong.
The frontend is the API gateway.

---

## Key configuration variables

| Variable | Purpose | Format |
|---|---|---|
| `FRONTEND_ADDR` | Address of the frontend | IP or hostname only — no `http://` prefix |
| `USERS` | Number of simulated concurrent users | Integer |
| `SPAWN_RATE` (or `RATE`) | How fast users are added per second | Integer |

---

## Steps

### 1. Get the frontend IP

```bash
./scripts/get-frontend-ip.sh
```

### 2. Build the load generator image

The load generator image is no longer available on GCR, so it must be built
locally from the Dockerfile in the repository:

```bash
cd microservices-demo/src/loadgenerator
docker build -t loadgenerator:local .
```

### 3. Run the load generator

```bash
docker run --rm \
  -e FRONTEND_ADDR=<frontend-ip> \
  -e USERS=10 \
  -e SPAWN_RATE=1 \
  loadgenerator:local
```

Locust runs in headless mode (no web UI) and prints a live request/failure
table to stdout.

---

## Observations from local test

### Initial failures — root cause

All requests initially failed with 100% failure rate and exactly 5000ms response
time. The 5000ms is Locust's default timeout, meaning requests were hanging until
timeout rather than being refused or returning an error.

The root cause was a **double `http://` scheme** in the host URL. The Dockerfile
entrypoint is:

```dockerfile
ENTRYPOINT locust --host="http://${FRONTEND_ADDR}" ...
```

It prepends `http://` to `FRONTEND_ADDR`. Passing `FRONTEND_ADDR=http://35.242.229.106`
results in `--host="http://http://35.242.229.106"` — an invalid URL that Locust
cannot resolve, causing every request to hang until timeout.

**Fix:** pass only the IP address without scheme:

```bash
-e FRONTEND_ADDR=35.242.229.106   # correct
-e FRONTEND_ADDR=http://35.242.229.106  # wrong — causes 5000ms timeouts
```

### After fix — successful output

Once `FRONTEND_ADDR` was corrected, requests succeeded:

```
GET  /                   10   0(0.00%) | 245  210  380  230 | 1.00  0.00
GET  /product/...         8   0(0.00%) | 312  280  450  300 | 0.80  0.00
POST /cart                2   0(0.00%) | 180  160  210  175 | 0.20  0.00
```

### Key conclusion

The load generator architecture is correct: point Locust at the frontend
external IP and let the frontend handle all internal routing. The only
configuration detail that matters is passing a bare IP/hostname to
`FRONTEND_ADDR` — not a full URL.

---

## Next steps

The local test validated connectivity and load generation mechanics. The next
step is automating the deployment of the load generator on a GCE VM inside the
same GCP region as the cluster using Terraform for VM provisioning and a startup
script or Ansible for Docker-based Locust deployment. Running inside the same
region minimises network latency between the load generator and the frontend,
giving more realistic performance measurements.