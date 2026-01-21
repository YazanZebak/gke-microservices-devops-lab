## 1. Environment Configuration

All environment variables are centralized in a single configuration file.

```bash
./scripts/config-gke-cluster.sh
```

This file defines shared variables such as project ID, region, cluster name, and defaults used by all scripts.

---

## 2. Cluster Creation

Cluster creation, including enabling required GCP services, is handled by a dedicated script.

```bash
./scripts/create-gke-cluster.sh
```

The cluster is created using explicit flags for versioning, networking, security, and resource sizing.

---

## 3. Key GKE Flags Used

| Flag                              | Category   | Purpose                       |
| --------------------------------- | ---------- | ----------------------------- |
| `--release-channel`               | Cluster    | Controls Kubernetes upgrades  |
| `--node-locations`                | Cluster    | Multi-zone node distribution  |
| `--enable-ip-alias`               | Networking | Enables VPC-native networking |
| `--shielded-secure-boot`          | Security   | Secure node boot              |
| `--shielded-integrity-monitoring` | Security   | Node OS integrity checks      |
| `--disk-size`                     | Resources  | Controls node disk allocation |

---

## 4. Deployment

The application is deployed using Kubernetes manifests from the official repository:

```bash
https://github.com/GoogleCloudPlatform/microservices-demo
```

All services communicate internally within the cluster. No direct GCP API access is required by workloads.

```bash
./scripts/deploy-k8s-app.sh
```

Deploy the Online Boutique application on GKE.

---

## 5. Architecture & Design Decisions

This section explains the rationale behind each major decision and clarifies the underlying GKE and GCP concepts.

### 5.1 Centralized Configuration

**Decision**: All variables are defined in `config-gke-cluster.sh`.

**Explanation**:
Centralizing configuration avoids duplication, reduces errors between scripts, and mirrors real-world infrastructure practices where configuration is externalized. It also improves reproducibility and makes environment changes explicit and auditable.

---

### 5.2 Region vs Zone Separation

**Decision**: Regions and zones are explicitly separated.

**Explanation**:
A region is a geographical area (e.g. `europe-west1`), while a zone is a specific data center within that region (e.g. `europe-west1-b`). GKE regional clusters require region-level configuration; mixing the two leads to common but subtle errors. Explicit separation improves correctness and clarity.

---

### 5.3 Regional (Multi-Zone) Cluster

**Decision**: Use a regional GKE cluster.

**Explanation**:
Regional clusters distribute nodes across multiple zones and replicate the control plane. This improves fault tolerance and availability without additional application complexity. It reflects standard production GKE architecture rather than single-zone experimentation.

---

### 5.4 VPC-Native Networking

**Decision**: Enable VPC-native networking using `--enable-ip-alias`.

**Explanation**:
With VPC-native networking, pods receive IP addresses from the VPC subnet instead of an overlay network. This improves scalability, simplifies routing, and is required for many advanced GKE features. It is the recommended and default model for modern GKE clusters.

---

### 5.5 Virtual Private Cloud (VPC)

**Decision**: Use the default VPC (no custom VPC created).

**Explanation**:
A VPC is a logically isolated network that defines IP ranges, subnets, routing, and firewall rules. All GKE clusters run inside a VPC. Using the default VPC keeps the setup simple while still relying on the same networking primitives used in production.

---

### 5.6 Shielded Nodes

**Decision**: Enable Shielded GKE nodes.

**Explanation**:
Shielded nodes provide Secure Boot and integrity monitoring. Secure Boot ensures only signed components run at startup, while integrity monitoring detects OS-level tampering. These features improve baseline security with minimal operational overhead.

---

### 5.7 Kubernetes Version Management

**Decision**: Use the GKE release channel instead of hard pinning a specific patch version.

**Explanation**:
GKE supports only a limited set of Kubernetes versions that change over time. Hard pinning deprecated versions causes cluster creation failures. Using the release channel provides controlled, automatic upgrades while avoiding lifecycle-related breakage.

---

### 5.8 Disk Size and Quota Awareness

**Decision**: Explicitly reduce node disk size using `--disk-size`.

**Explanation**:
Regional clusters replicate node pools across multiple zones. By default, each node allocates 100 GB of SSD storage. This can quickly exceed regional SSD quotas. Reducing disk size aligns resource allocation with actual workload needs and avoids unnecessary quota requests.

---

### 5.9 Workload Identity (Documented but Skipped)

**Decision**: Do not enable Workload Identity.

**Explanation**:
Workload Identity maps Kubernetes Service Accounts to Google Service Accounts, enabling secure access to GCP APIs without static credentials. The microservices-demo does not require GCP API access, and enabling Workload Identity would add significant IAM configuration overhead per service. The workload pool identifier (e.g. `${PROJECT_ID}.svc.id.goog`) is safe to publish and does not grant access by itself.

---

## 6. Tradeoff Summary

| Decision                   | Benefit                 | Tradeoff                      |
| -------------------------- | ----------------------- | ----------------------------- |
| Centralized config         | Reproducibility         | Initial structure overhead    |
| Regional cluster           | High availability       | Higher resource usage         |
| VPC-native networking      | Scalability and clarity | Requires networking knowledge |
| Shielded nodes             | Improved security       | Minimal extra configuration   |
| Release channel            | Lifecycle safety        | Less strict version control   |
| Reduced disk size          | Quota compliance        | Less headroom per node        |
| Skipping Workload Identity | Simplicity              | Reduced IAM granularity       |
