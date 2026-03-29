# GKE Cluster Design

## Objective

This document explains the reasoning behind the GKE cluster setup, highlighting
the why, what, and trade-offs, while providing enough context to understand the
environment.

---

## Cluster Design Rationale

**Cluster Type:** Standard GKE, regional single-zone

* **Why:** We use a regional cluster for a stable control plane, but restrict
  node placement to a single zone using `--node-locations`. Without this flag,
  GKE provisions `NUM_NODES` per zone — with 3 zones and `NUM_NODES=2` that
  produces 6 nodes instead of 2, tripling cost without benefit for this lab.

**Region:** `europe-west3` (Frankfurt)

* **Why:** Originally `europe-west1` (Belgium), but a GCE stockout prevented
  node provisioning. Switched to `europe-west3` which had available capacity.
* **Trade-off:** Region selection affects latency, data residency, and pricing.
  For this lab, availability takes priority.
* **Lesson learned:** In production, the correct response to a zone stockout is
  excluding that zone with `--node-locations`, not changing regions. Changing
  regions has broader implications. For a lab, switching regions is acceptable.

**Node Pool:** Single pool of 2 `e2-standard-2` nodes in `europe-west3-a`, 30GB disk

* **Why:** Simplifies resource management and HPA observation. All microservices
  share the same pool, making scaling behavior predictable. 2 nodes provides
  enough capacity for all Online Boutique services after CPU request adjustments.

* **Machine type — `e2-standard-2` (2 vCPU, 8GB RAM):**
  Chosen as the cheapest machine type that comfortably fits this workload.
  - Smaller (`e2-medium`, 1 vCPU, 4GB): only 2 vCPU total across the cluster,
    leaving almost no headroom over the 1170m total CPU requests after patches.
    Also too memory-constrained for JVM-based services like adservice.
  - Larger (`e2-standard-4`, 4 vCPU, 16GB): sufficient capacity but ~2× the
    cost, consuming credits needed for later steps (load generator VM,
    Prometheus, canary deployments).
  - `e2-standard-2` gives 4 vCPU and 16GB total across 2 nodes — comfortable
    headroom over workload requirements at the lowest viable cost.

* **Disk size — 30GB:**
  Sufficient for container images and logs at this scale. Larger disks increase
  cost without benefit for a short-lived lab cluster.

**Node locations:** Explicitly set to `europe-west3-a` only (`--node-locations`)

* **Why:** Restricts node provisioning to a single zone, giving exactly 2 nodes
  total as intended. Learned from experience — first cluster creation without
  this flag produced 6 nodes across 3 zones.
* **Trade-off:** Single zone means no worker node zone redundancy. Acceptable
  for a lab; in production you would use at least 2 zones.

**Networking:** VPC-native (`--enable-ip-alias`)

* **Why:** Pods receive VPC IPs, improving scalability, routing, and
  compatibility with features like network policies and hybrid networking.
  Also required for the GCE VM load generator to communicate with the cluster
  over the internal VPC without special routing.

**Security:** Shielded nodes (Secure Boot + integrity monitoring)

* **Why:** Baseline production-level security without operational overhead.
  Detects OS tampering and ensures only signed components run.

**Purpose:** Host Online Boutique microservices with Kustomize-managed CPU/memory
limits.

**Future additions:** External load generator (GCE VM + Terraform),
Prometheus/Grafana monitoring, and canary deployments.

---

## Key Conceptual Questions

**Q: Why a single node pool instead of multiple pools?**

Simplifies scheduling, HPA observation, and resource allocation. Multiple pools
add complexity without immediate benefit for this workload.

**Q: Why centralize environment configuration?**

Ensures reproducibility, reduces duplication, and makes changes auditable.
Supports automation and reduces human error. Mirrors the separation between
`variables.tf` and `main.tf` in Terraform.

**Q: Why skip Workload Identity?**

The microservices don't require GCP API access. Skipping it reduces complexity
while still allowing realistic internal cluster communication.

**Q: Why use release channels instead of pinned Kubernetes versions?**

Automatic, controlled upgrades prevent failures from deprecated versions and
mirror production lifecycle management.

**Q: Why not use Autopilot mode?**

Autopilot automatically provisions nodes to satisfy pod requests, which would
hide the scheduling problem this lab asks us to solve. It also costs more and
provides less control over resource configuration. See `gke-deployment-qa.md`
for a full comparison.

**Q: Why does a regional cluster produce more nodes than expected?**

GKE regional clusters distribute `NUM_NODES` per zone, not across the region
total. With `NUM_NODES=2` and 3 zones, you get 6 nodes. To control the total
node count, use `--node-locations` to restrict which zones are used.

---

## Trade-Off Analysis

| Decision | Benefit | Trade-off |
|---|---|---|
| Centralized config | Reproducibility, reduced duplication | Initial setup overhead |
| Regional cluster, single zone | Stable control plane, controlled cost | No worker node zone redundancy |
| Explicit `--node-locations` | Predictable node count, cost control | Must be updated if zone has stockout |
| `europe-west3` region | Available capacity, avoided stockout | Slightly further from Athens than `europe-west1` |
| VPC-native networking | Scalability, routing clarity, VM-to-cluster communication | Requires networking understanding |
| Shielded nodes | Security baseline | Slightly more configuration effort |
| Release channel | Lifecycle safety, avoids deprecated versions  | Less strict version control |
| Reduced disk size | Quota compliance | Limited storage headroom per node |
| Skipping Workload Identity | Simplifies setup | Reduced IAM granularity |

---

## Operational Lessons

**GCE stockout (`europe-west1`):** Region ran out of `e2-standard-2` capacity
during cluster creation. Resolution: switched to `europe-west3`. Production
lesson: exclude the affected zone with `--node-locations` rather than changing
regions unless data residency requirements allow it.

**Regional cluster node count:** Creating a regional cluster without
`--node-locations` provisions `NUM_NODES` per zone, not total. With 3 zones and
`NUM_NODES=2`, GKE created 6 nodes instead of 2. Resolution: added
`--node-locations="${NODE_LOCATIONS}"` to the create script and
`NODE_LOCATIONS="${ZONE}"` to the config file.

---

## Conceptual Summary

This cluster is designed to be **production-like yet contained**, enabling
experimentation with microservices, autoscaling, external load testing, and
monitoring. All design choices were made to support reproducible testing,
reliable metrics, and controlled experimentation, preparing the environment for
subsequent steps such as external load generation, canary deployments, and
monitoring integration.