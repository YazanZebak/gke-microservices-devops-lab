# Deploying the Load Generator on a Local Machine

## Objective

Understand why running the load generator outside the Kubernetes cluster matters for accurate performance testing, and validate that the application is reachable before moving to automated cloud deployment.

## Why run the load generator externally?

Running the load generator inside the cluster consumes CPU and memory that belong to the application itself, which contaminates autoscaling metrics and latency measurements. The Horizontal Pod Autoscaler reacts to resource signals — if the load generator is inside the cluster, it creates artificial pressure that makes HPA scale for the wrong reasons. External load generation isolates test traffic from cluster resources, giving a realistic view of how the application handles real user load.

## The frontend-as-gateway mental model

This is the key concept to understand before running any load test.

Online Boutique is designed so that **the frontend is the only entry point for external traffic**. When a user opens the app in a browser, they hit the frontend's LoadBalancer IP on port 80. The frontend then routes requests internally to CartService, CheckoutService, ProductCatalogService, and others over gRPC — using ClusterIP addresses that are only reachable inside the cluster.

This means:

- The load generator only needs to reach the **frontend's external IP** — nothing else
- The backend services (CartService, CheckoutService, etc.) are correctly unreachable from outside the cluster by design
- Running Locust from a VM in the same VPC is about **latency** (staying in the same datacenter as the cluster), not about needing special network access to backend pods

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

Trying to reach backend services directly from outside the cluster is not only impossible without additional configuration — it is also architecturally wrong. The frontend is the API gateway.

## Key configuration variables

| Variable | Purpose |
|---|---|
| `FRONTEND_ADDR` | Must be `http://<external-ip>` — no trailing slash, correct scheme |
| `USERS` | Number of simulated concurrent users |
| `SPAWN_RATE` | How fast users are added per second |

## Observations from local test

Running Locust pointed at the `frontend-external` LoadBalancer IP produced failures on cart, checkout, and product routes. Frontend-only pages (home, category listing) succeeded.

### Root cause analysis

The failures were **not** caused by:
- Network inaccessibility — the frontend was reachable
- Resource limits — backend pod CPU/memory remained near zero, meaning requests never arrived at the pods

The failures were caused by **backend pods that had not fully started**, likely due to the resource constraint issue addressed in the Kustomize overlay step. Services like CartService depend on Redis (`redis-cart:6379`); if Redis or CartService itself was in a pending or crash-loop state, any frontend request that touched the cart would fail at the application level — not the network level.

### Key conclusion

The load generator architecture is correct: point Locust at the frontend external IP, and let the frontend handle all internal routing. Failures during local testing reflected the cluster's partial deployment state, not a fundamental networking problem with external load generation.

## Next steps

The local test validated connectivity and load generation mechanics. The next step is automating the deployment of the load generator on a GCE VM inside the same GCP region as the cluster, so that network latency between the load generator and the frontend is minimised. This is done using Terraform for VM provisioning and a startup script or Ansible for Docker-based Locust deployment.