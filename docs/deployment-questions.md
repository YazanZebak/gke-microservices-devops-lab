# GKE Deployment - Questions and Answers

## Question 1: Autopilot Mode in GKE

**Q: In the README file, it is suggested to start a GKE cluster configured in "Autopilot" mode (as opposed to "standard" mode). Using this mode would solve the problem we just observed. Briefly explain what is this Autopilot mode and why it hides the problem.**

**A:** Autopilot mode is a managed GKE offering where Google Cloud automatically manages cluster infrastructure, node pools, and resource provisioning. It automatically scales the cluster based on workload demands and handles node management without user intervention.

It "hides" the resource constraint problem because:
- **Automatic Scaling**: Autopilot automatically provisions additional nodes when workloads request more resources, eliminating manual capacity planning
- **Abstracted Infrastructure**: Users don't need to worry about individual node capacity or resource allocation - the platform handles it transparently
- **Optimized Resource Allocation**: Autopilot intelligently bins workloads and manages resources to maximize utilization

**Trade-offs of Autopilot mode:**
- More expensive billing compared to standard mode
- Less flexible control over cluster configuration and resource parameters
- Limited customization options for infrastructure management

For this project, we are using standard mode to have more control over resource management and cost optimization.

---

## Question 2: Kubernetes Resource Requests vs Limits

**Q: Which of the two parameters (requests and limits) actually matters when Kubernetes decides that it can deploy a service on a worker node?**

**A:** The **`requests`** parameter is the one that matters for scheduling decisions.

When Kubernetes decides whether to deploy a service on a worker node, it checks if the node has enough available resources to satisfy the pod's `requests`. The scheduler will only place a pod on a node if that node has sufficient resources for all requested amounts across CPU and memory.

**Parameter differences:**
- **`requests`**: Guaranteed minimum resources reserved for the pod. Used by the scheduler to make placement decisions
- **`limits`**: Maximum resources a pod is allowed to consume. Used to prevent resource overuse but doesn't affect initial scheduling

By reducing the `requests` parameter for non-critical services, we can fit more pods on the available worker nodes without changing the actual cluster capacity.

---

## Question 3: Reducing Resource Requirements

**Q: We know that dividing by 2 the CPU resources requested by 2 of the services is enough to be able to deploy all services on the GKE cluster. Select 2 services among those that seem less critical in the application to reduce their resource requirement and justify your choices.**

**A:** Based on the Online Boutique microservices architecture, the recommended services to reduce CPU requests are:

### 1. **Email Service**
- **Current**: 100m → **Reduce to**: 50m
- **Justification**: Email sending is inherently asynchronous and non-blocking, making it a background task that doesn't impact user experience directly. The service has low CPU intensity since it's mostly I/O-bound, waiting for SMTP operations to complete rather than performing CPU-intensive calculations.

### 2. **Cart Service**
- **Current**: 200m → **Reduce to**: 100m
- **Justification**: Redis operations are fundamentally **I/O-bound, not CPU-bound**. The bottleneck in cart service performance is network/storage access to Redis, not CPU computation. Cart operations consist of simple read/write operations to the cache, so CPU reduction won't degrade performance since the service is waiting on I/O operations, not computing.

By halving the CPU requests for these two I/O-bound services, we can reduce overall cluster resource consumption while maintaining performance, which should be sufficient to allow all services to be deployed on the default GKE cluster configuration.
