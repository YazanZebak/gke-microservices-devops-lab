# Monitoring: Prometheus + Grafana

## Objective

Deploy a self-managed monitoring stack inside the GKE cluster to collect and
visualize metrics at the node level and pod level, independently of GCP's
built-in monitoring.

---

## Stack

| Component          | Role                                                                                |
| ------------------ | ----------------------------------------------------------------------------------- |
| Prometheus         | Scrapes and stores metrics                                                          |
| Grafana            | Dashboards and visualization                                                        |
| Node Exporter      | Per-node metrics (CPU, memory, disk, network) — runs as DaemonSet                   |
| kube-state-metrics | Per-pod/deployment/replicaset metrics                                               |
| cAdvisor           | Per-container metrics — built into the kubelet, scraped by Prometheus automatically |

Deployed via the **kube-prometheus-stack** Helm chart, which pre-wires all
components and ships with production-grade default dashboards.

---

## Design Decisions

**Why kube-prometheus-stack instead of manual manifests?**

The chart bundles Prometheus, Grafana, node-exporter, kube-state-metrics, and
alertmanager with all scrape configs and dashboards pre-configured. Writing these
manually adds significant YAML work without learning value — the interesting
decisions are what to monitor and how to interpret results, not whether a
ServiceMonitor selector is correct.

**Why a dedicated `monitoring` namespace?**

Separation of concerns. Monitoring infrastructure should not share a namespace
with the application. This also makes teardown clean — `kubectl delete namespace
monitoring` removes everything.

**Why LoadBalancer for Grafana?**

During performance evaluation, Grafana needs to be accessible while load tests
are running on the GCE VM simultaneously. A port-forward requires a dedicated
terminal and breaks if the connection drops. A LoadBalancer IP is stable and
accessible from any browser without any ongoing local process.

**Why no persistent storage for Prometheus?**

Prometheus data is only needed during active observation (live load tests). The
performance evaluation workflow is: start test → watch Grafana → stop test →
record results from Locust CSVs. Historical Prometheus data is never queried
across sessions, so persistence adds cost with no benefit for this lab.

**Why alertmanager disabled?**

Not required by any step in this lab. Enabling it adds resource consumption and
configuration complexity without payoff.

---

## Deployment

```bash
./scripts/deploy-monitoring.sh
```

This installs the Helm chart into the `monitoring` namespace and prints the
Grafana URL once the LoadBalancer IP is assigned.

Default credentials: `admin` / `admin`

---

## Key Dashboards (pre-loaded)

- **Kubernetes / Nodes** — node-level CPU, memory, disk, network per node
- **Kubernetes / Pods** — per-pod CPU and memory usage across all namespaces
- **Kubernetes / Compute Resources / Namespace (Pods)** — compare pods within
  the `default` namespace (where Online Boutique runs)

These are sufficient for the required monitoring objectives (node-level and
pod-level resource consumption).

---

## Testing

### 1. Check all pods are running

```bash
kubectl get pods -n monitoring
```

Expected: Prometheus, Grafana, kube-state-metrics, and two node-exporter pods
(one per node) all in `Running` state.

### 2. Open Grafana

Go to `http://<grafana-ip>` in your browser, login with `admin/admin`.

Left sidebar → **Dashboards → Browse** → you should see a "Kubernetes" folder
with pre-loaded dashboards.

### 3. Verify node-level metrics

Open **Kubernetes / USE Method / Node** or **Kubernetes / Nodes**. You should
see two nodes with real CPU and memory values. "No data" means node-exporter
is not being scraped — check the namespace selector in `values.yaml`.

### 4. Verify pod-level metrics

Open **Kubernetes / Compute Resources / Namespace (Pods)**, set namespace to
`default`. You should see all Online Boutique pods with their CPU and memory
consumption.

### 5. Verify end-to-end under load

Start Locust on the load generator VM:

```bash
ssh -i ~/.ssh/google_compute_engine debian@<vm-ip> \
  "sudo docker logs locust --tail 20"
```

Watch the pod metrics in Grafana move — cartservice and frontend CPU should
tick up as requests come in. This confirms the full pipeline is working.

### If something looks wrong

Check whether Prometheus is successfully scraping all targets:

```bash
kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring
```

Open `http://localhost:9090/targets` — every target should show state `UP`.

---

## Teardown

```bash
./scripts/destroy-monitoring.sh
```

Removes the Helm release and the `monitoring` namespace entirely. The GKE
cluster and Online Boutique are not affected.
