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

**Q:** Divide the CPU requests by 2 for two non-critical services to deploy all services on the cluster. Which services do you choose and why?

**A:** Recommended services to reduce CPU requests:

### 1. **Email Service**

* **Current:** 100m → **Reduce to:** 50m
* **Justification:** Email sending is asynchronous and I/O-bound. Reducing CPU does not affect user-visible performance because the service mostly waits for network operations.

### 2. **Cart Service**

* **Current:** 200m → **Reduce to:** 100m
* **Justification:** Cart operations are I/O-bound, primarily interacting with Redis. CPU reduction does not degrade performance since the service spends most time waiting for I/O rather than computing.

**Result:** Halving CPU requests for these services reduces overall cluster resource consumption while allowing all pods to be scheduled on a standard GKE cluster without impacting core application functionality.
