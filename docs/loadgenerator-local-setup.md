# Deploying the Load Generator on a Local Machine

## Objective

Understand why running the load generator outside the Kubernetes cluster is important for accurate performance testing and autoscaling evaluation.

## Why run the load generator externally?

* Running it inside the cluster consumes CPU and memory that belong to the application, polluting autoscaling metrics and latency measurements.
* External load generation isolates test traffic from cluster resources, giving a realistic view of how the application handles user load.
* This step ensures that the Horizontal Pod Autoscaler (HPA) reacts to real traffic instead of test-induced resource pressure.

## Key Questions and Reasoning

**Q: What is being tested with the load generator?**
A: The application’s ability to handle concurrent users, request rates, and scaling behavior. The load generator simulates traffic patterns that real users would produce.

**Q: Why not just keep it inside the cluster?**
A: Keeping it inside the cluster contaminates the metrics used by the HPA. CPU and memory consumed by the generator create false signals, leading to scaling decisions that do not reflect actual user load.

**Q: How do we reach the frontend from outside the cluster?**
A: The frontend must be exposed via NodePort, LoadBalancer, or Ingress so that external clients (here, the load generator) can send HTTP requests. Without this exposure, the load generator cannot generate meaningful traffic.

**Q: What are the critical variables to control?**
A: The address of the frontend (`FRONTEND_ADDR`), the number of simulated users (`USERS`), and the spawn rate (`RATE`). These define the load intensity and ensure reproducibility across different environments.

**Q: Why not edit the Dockerfile or manifests?**
A: The existing Dockerfile already packages Locust and the load behavior correctly. Changing it now could create inconsistencies with the later automated cloud deployment. The goal is to validate the current configuration externally.

## Learning Path

* Start with a local proof-of-concept to validate connectivity, load generation, and frontend metrics.
* Understand the impact of in-cluster vs. external load generation on HPA and performance signals.
* Document working parameters and behavior, which will form the template for automated deployment on Google Cloud.
* Recognize that this step is a conceptual bridge between local experimentation and cloud automation.

### Observations from Local Test

* Running the load generator outside the cluster using the frontend LoadBalancer (`frontend-external`) produced **100% failed requests** to microservices like `/cart`, `/checkout`, and `/product/...`.
* Only minimal frontend-only requests succeeded; all backend calls failed.
* Lowering users (even to 2) **did not improve success**, indicating the failures were not resource-related.
* CPU/memory usage on backend pods remained **very low**, showing that pods never actually received the requests.

### Analysis — Why the Test Failed

1. **Frontend reachable externally, but backend is not**:

   * `frontend-external` exposes the frontend UI, but backend microservices remain **ClusterIP**, only accessible internally.

2. **Frontend internally routes requests to ClusterIP addresses**:

   * From an external container, these addresses cannot be resolved or reached, causing 100% failed requests.

3. **Resource limits are not the problem**:

   * Failures occur before requests reach the backend pods; adjusting CPU/memory or HPA settings does not solve the connectivity issue.

4. **Placement of load generator is critical**:

   * Running outside the cluster simulates external traffic but **cannot succeed with the current network configuration**.

### Key Conclusions

* Local/external load generation **cannot fully test the microservices** without additional networking setup.
* Failures are due to **network accessibility limitations**, not cluster resource constraints.
* To successfully test with an external load generator, one must either:

  1. Expose backend microservices externally (not recommended), or
  2. Run the load generator inside the cluster or in a VM with **VPC access** to the cluster.

## Next Conceptual Steps

* Ensure the frontend is externally reachable. Decide the exposure method (NodePort, LoadBalancer, or Ingress) and understand its implications for testing and network access.
* Use insights from the local test to design automated provisioning of a cloud VM for the load generator, maintaining the same external load principles.
* Prepare to parameterize load settings to allow reproducible and controlled testing in the cloud environment.
* Accept that running Locust truly outside the cluster requires **network access to the VPC**, not just the frontend LoadBalancer IP, for backend requests to succeed.