# Kustomize Overlay Step

## 1. Objectives

- Solve a scheduling failure caused by insufficient CPU capacity in the default 
  GKE cluster configuration.
- Disable the load generator from the in-cluster deployment, as it will be run 
  externally in a later step.
- Keep the original base manifests intact to allow future upstream updates without 
  conflicts.

---

## 2. The Problem

When deploying the Online Boutique with its default configuration on a standard 
GKE cluster (2× `e2-standard-2` nodes), not all pods could be scheduled. The 
limiting factor was CPU.

The default total CPU requests across all services (including the load generator):

| Service | CPU request |
|---|---|
| adservice | 200m |
| cartservice | 200m |
| redis-cart | 70m |
| checkoutservice | 100m |
| currencyservice | 100m |
| emailservice | 100m |
| frontend | 100m |
| loadgenerator | 300m |
| paymentservice | 100m |
| productcatalogservice | 100m |
| recommendationservice | 100m |
| shippingservice | 100m |
| **Total** | **1670m** |

While this fits within the theoretical cluster capacity (3880m schedulable), GKE 
also runs system DaemonSets per node (kube-proxy, fluentd, metrics agents) that 
consume CPU beyond the base reservation. The load generator alone accounts for 
300m — the single largest consumer — and is not needed inside the cluster.

## 3. Solution

Two modifications were applied via Kustomize overlay patches:

**1. Disable the load generator** (`replicas: 0`)

The load generator is not part of the application — it exists only for testing. 
Disabling it saves 300m CPU and is the primary fix.

**2. Halve CPU requests on 2 non-critical services**

The task requires selecting 2 services whose CPU requests can be halved without 
impacting application functionality. The criterion is criticality to the 
user-facing request path.

| Service | Before | After | Justification |
|---|---|---|---|
| adservice | 200m | 100m | Serves ad recommendations asynchronously. Never in the critical path for checkout, cart, or payment. Observed idle usage: 2m. |
| cartservice | 200m | 100m | I/O-bound — primarily Redis reads/writes. Not compute-intensive. Observed idle usage: 8m. |

Observed idle CPU data from `kubectl top pods` supports these choices: both 
services have the largest gap between requested and actual usage, confirming 
they are over-provisioned relative to their computational needs.

---

## 4. Approach

1. **Do not modify the base**
   The base manifests from Online Boutique are treated as read-only. Changes go 
   in a separate overlay to avoid conflicts with future upstream updates.

2. **Kustomize overlay structure**
   A dedicated `overlays/` folder contains all modifications, referencing the 
   base and applying changes through strategic merge patches.

3. **Separation of concerns**
   - Base manifests = original upstream application, never modified
   - Overlay = all project-specific modifications, in one place

---

## 5. Observations on Memory

While reducing CPU requests, we also checked memory limits against observed 
usage from `kubectl top pods`:

- **adservice:** observed idle usage (66Mi) exceeds the base memory limit (64Mi). 
  This would cause OOMKill on startup regardless of load. Memory limit increased 
  to 128Mi.
- **cartservice:** observed idle usage (28Mi) is within the base limit (64Mi). 
  Increased to 128Mi as a conservative buffer until peak usage is measured during 
  load testing.

This is a separate concern from the scheduling fix — noted here as an observation 
from examining the configuration closely.