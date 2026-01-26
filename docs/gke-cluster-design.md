# GKE Cluster Design

## Objective

This document explains the reasoning behind the GKE cluster setup, highlighting the why, what, and trade-offs, while providing enough context to understand the environment.

## Cluster Design Rationale

**Cluster Type:** Standard GKE, regional multi-zone

* **Why:** Multi-zone clusters provide high availability and resilience. Workloads continue running if a zone fails, allowing realistic fault tolerance testing.

**Node Pool:** Single pool of 2 `e2-standard-2` nodes with 30 GB disk

* **Why:** Simplifies resource management and HPA observation. All microservices share the same pool, making scaling behavior predictable.

**Networking:** VPC-native (`--enable-ip-alias`)

* **Why:** Pods receive VPC IPs, improving scalability, routing, and compatibility with features like network policies and hybrid networking.

**Security:** Shielded nodes (Secure Boot + integrity monitoring)

* **Why:** Baseline production-level security without operational overhead. Detects OS tampering and ensures only signed components run.

**Purpose:** Host Online Boutique microservices with Kustomize-managed CPU/memory limits.

**Future Additions:** External load generator, Prometheus/Grafana monitoring, and canary deployments.

## Key Conceptual Questions

**Q: Why a single node pool instead of multiple pools?**

* Simplifies scheduling, HPA observation, and resource allocation. Multiple pools add complexity without immediate benefit.

**Q: Why centralize environment configuration?**

* Ensures reproducibility, reduces duplication, and makes changes auditable. This supports automation and reduces human error.

**Q: Why skip Workload Identity?**

* The microservices don’t require GCP API access. Skipping it reduces complexity while still allowing realistic internal cluster communication.

**Q: Why use release channels instead of pinned Kubernetes versions?**

* Automatic, controlled upgrades prevent failures from deprecated versions and mirror production lifecycle management.

**Q: How do resource constraints influence design?**

* Node disk size and type are chosen to stay within quotas, balancing cost, capacity, and realistic workload performance.

## Trade-Off Analysis

| Decision                    | Benefit                                       | Trade-off                          |
| --------------------------- | --------------------------------------------- | ---------------------------------- |
| Centralized config          | Reproducibility, reduced duplication          | Initial setup overhead             |
| Regional multi-zone cluster | High availability, fault tolerance            | Higher resource usage              |
| VPC-native networking       | Scalability, routing clarity, feature support | Requires networking understanding  |
| Shielded nodes              | Security baseline                             | Slightly more configuration effort |
| Release channel             | Lifecycle safety, avoids deprecated versions  | Less strict version control        |
| Reduced disk size           | Quota compliance                              | Limited storage headroom per node  |
| Skipping Workload Identity  | Simplifies setup                              | Reduced IAM granularity            |

## Learning Path

* Understand how each cluster setting impacts **scalability, reliability, and testing accuracy**.
* Recognize the balance between **simplicity and realism**, e.g., skipping Workload Identity reduces setup complexity but limits fine-grained IAM.
* See how network design (VPC-native) and node distribution interact with HPA, load testing, and monitoring.
* Learn to evaluate trade-offs between resource efficiency, fault tolerance, and operational complexity.

## Conceptual Summary

This cluster is designed to be **production-like yet contained**, enabling experimentation with microservices, autoscaling, external load testing, and monitoring. All design choices were made to **support reproducible testing, reliable metrics, and controlled experimentation**, preparing the environment for subsequent steps such as external load generation, canary deployments, and monitoring integration.
