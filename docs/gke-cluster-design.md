# GKE Cluster Design and Deployment

## 1. Cluster Design

**Overview:**

* **Cluster Type:** Standard GKE, regional multi-zone
* **Node Pool:** Single pool for main workloads

  * 2 nodes, `e2-standard-2` machines
  * 30 GB disk per node
* **Networking:** VPC-native (`--enable-ip-alias`)
* **Security:** Shielded nodes enabled
* **Purpose:** Runs Online Boutique microservices with Kustomize-managed CPU requests/limits
* **Future Additions:** Monitoring (Prometheus/Grafana), canary releases, and external load generator will be added later

---

**Architecture Diagram:**

```mermaid
graph TD
    A[GKE Cluster: online-boutique] --> B[Node Pool: 2 Nodes]
    B --> C[Pod: Email Service]
    B --> D[Pod: Cart Service]
    B --> E[Other Pods]
    A --> F[External Load Generator (planned)]
    A --> G[Monitoring (planned)]
```

**Notes:**

* All services communicate internally within the cluster.
* The external load generator and monitoring components are planned but not yet deployed.
* This design reflects the current setup that can be safely deployed within project quota limits.

## 2. Environment Configuration

All environment variables are centralized in a single configuration file for reproducibility:

```bash
./scripts/config-gke-cluster.sh
```

This file defines shared variables including project ID, region, cluster name, node settings, and feature flags. Centralization avoids duplication, reduces errors, and makes environment changes explicit and auditable.

---

## 3. Cluster Creation

Cluster creation is automated with:

```bash
./scripts/create-gke-cluster.sh
```

The script handles enabling required GCP services and creating the cluster with production-like settings suitable for experimentation. Flags include versioning, networking, security, and resource sizing.

**Execution order:** Run `config-gke-cluster.sh` first, then `create-gke-cluster.sh`.

---

## 4. Key GKE Flags Used

| Flag                              | Category   | Purpose                                           |
| --------------------------------- | ---------- | ------------------------------------------------- |
| `--release-channel`               | Cluster    | Automatic Kubernetes upgrades via release channel |
| `--node-locations`                | Cluster    | Multi-zone distribution for high availability     |
| `--enable-ip-alias`               | Networking | VPC-native pod IPs for scalability and clarity    |
| `--shielded-secure-boot`          | Security   | Ensures only signed OS components run             |
| `--shielded-integrity-monitoring` | Security   | Detects OS-level tampering                        |
| `--disk-size`                     | Resources  | Aligns node storage with workload needs           |

---

## 5. Deployment

The application is deployed using Kubernetes manifests from the official repository:

```bash
https://github.com/GoogleCloudPlatform/microservices-demo
```

Deployment script:

```bash
./scripts/deploy-k8s-app.sh
```

All services communicate internally within the cluster. No direct GCP API access is required by workloads.

---

## 6. Architecture & Design Decisions

### 6.1 Centralized Configuration

* **Decision:** Use a single config file.
* **Benefit:** Reproducible scripts, reduced duplication, auditable changes.

### 6.2 Region vs Zone Separation

* **Decision:** Explicitly configure regions and zones.
* **Benefit:** Avoids subtle errors, aligns with GKE regional cluster requirements.

### 6.3 Regional (Multi-Zone) Cluster

* **Decision:** Nodes distributed across multiple zones.
* **Benefit:** Improves fault tolerance and control plane redundancy.

### 6.4 VPC-Native Networking

* **Decision:** Enable `--enable-ip-alias`.
* **Benefit:** Pods receive VPC subnet IPs, improving scalability, routing, and compatibility with advanced GKE features.

### 6.5 Virtual Private Cloud (VPC)

* **Decision:** Use the default VPC.
* **Benefit:** Simplifies setup while retaining production-like networking primitives.

### 6.6 Shielded Nodes

* **Decision:** Enable Secure Boot and integrity monitoring.
* **Benefit:** Baseline security with minimal operational overhead.

### 6.7 Kubernetes Version Management

* **Decision:** Use release channel instead of hard pinning versions.
* **Benefit:** Controlled, automatic upgrades avoid deprecated versions and cluster creation failures.

### 6.8 Disk Size and Quota Awareness

* **Decision:** Reduce node disk size (`--disk-size`).
* **Benefit:** Avoid exceeding regional SSD quotas while aligning resources with workload needs.

### 6.9 Workload Identity

* **Decision:** Skip enabling Workload Identity.
* **Benefit:** Simplifies setup; not needed because workloads do not require GCP API access.

---

## 7. Tradeoff Summary

| Decision                   | Benefit                 | Tradeoff                       |
| -------------------------- | ----------------------- | ------------------------------ |
| Centralized config         | Reproducibility         | Initial structure overhead     |
| Regional cluster           | High availability       | Higher resource usage          |
| VPC-native networking      | Scalability and clarity | Requires networking knowledge  |
| Shielded nodes             | Improved security       | Minimal extra configuration    |
| Release channel            | Lifecycle safety        | Less strict version control    |
| Reduced disk size          | Quota compliance        | Less storage headroom per node |
| Skipping Workload Identity | Simplicity              | Reduced IAM granularity        |

---

