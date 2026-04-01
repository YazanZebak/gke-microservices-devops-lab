# gke-microservices-devops-lab
A step-by-step DevOps project to deploy and manage a microservices application on Google Kubernetes Engine (GKE). This repository follows a practical learning approach, covering deployment, monitoring, performance evaluation, canary releases, autoscaling, cost optimization, and cluster management.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GCP](https://img.shields.io/badge/Cloud-GCP-blue)](https://cloud.google.com)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-GKE-326CE5)](https://cloud.google.com/kubernetes-engine)

## About the Demo Application

This project uses the **"Online Boutique"** demo application developed by Google. This is a mock application that simulates an online shop, comprised of 11 microservices. While the implementation of each service is simplified compared to realistic applications, it effectively illustrates the structure and operation of a reasonably complex cloud-native application.

The demo application is available from its [GitHub repository](https://github.com/GoogleCloudPlatform/microservices-demo). The main documentation can be found in the top-level README file and in the docs folder.

> **Note:** This demo application used to be named "Hipster Shop". Some documents and code/configuration files may still reference this name.

## Prerequisites
1. **Google Cloud Platform (GCP)** account with a project configured.
2. **Required Tools**:
   - `gcloud` CLI
   - `kubectl`
   - `helm`
   - `Docker`
   - `terraform`
   - `ansible`
   - `helm`

## Design Decisions and Thinking Notes

Detailed design decisions and reasoning are documented in the [docs](https://github.com/YazanZebak/gke-microservices-devops-lab/tree/main/docs) folder.

## Notes on Approach

### Cluster provisioning: scripts vs Terraform

The GKE cluster is provisioned using `gcloud` scripts (`scripts/create-gke-cluster.sh`). This was a deliberate choice to try both approaches across the project:

- **gcloud scripts** for the GKE cluster — simpler for a configuration that never changes after creation
- **Terraform** for the load generator VM — better fit since the VM is created and destroyed repeatedly across multiple test runs

In a production environment, Terraform would be the standard choice for both, as it provides state tracking, drift detection, and reviewable `terraform plan` output before any change is applied.

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/YazanZebak/gke-microservices-devops-lab.git
cd gke-microservices-devops-lab
```

### 2. Environment Configuration

Configure the following variables in `config-gke-cluster.sh`:
- `PROJECT_ID` — your GCP project ID
- `REGION` — GCP region (e.g. `europe-west3`)
- `ZONE` — single zone within the region (e.g. `europe-west3-a`)
- `CLUSTER_NAME` — name for the GKE cluster

`NODE_LOCATIONS` is automatically set to `ZONE` to ensure exactly 2 nodes are
provisioned. Without this, a regional cluster creates `NUM_NODES` per zone.

To avoid unnecessary costs, clean up and delete all resources after finishing your experiment using `delete-gke-cluster.sh`.

### 3. Deploy the Application

Run the deployment script:

`deploy-k8s-app.sh`

This script deploys the Online Boutique application on GKE.

### 4. Local Load Generator (Manual)

This [section](https://github.com/YazanZebak/gke-microservices-devops-lab/blob/main/docs/loadgenerator-local-setup.md) covers manually deploying the load generator on a local machine as
an intermediate step before automated cloud deployment.

### 5. Cloud Load Generator (Automated)

This [section](https://github.com/YazanZebak/gke-microservices-devops-lab/blob/main/docs/loadgenerator-cloud-infra-setup.md) covers automatically deploying the load generator on a GCE VM using Terraform and Ansible.

### 6. Monitoring

Prometheus and Grafana are deployed inside the cluster using the kube-prometheus-stack Helm chart. See [docs/monitoring.md](docs/monitoring.md) for design decisions and details.
