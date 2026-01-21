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
   - `Docker`

## Design Decisions and Thinking Notes

Detailed design decisions and reasoning are documented in the [docs](https://github.com/YazanZebak/gke-microservices-devops-lab/tree/main/docs) folder.

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/YazanZebak/gke-microservices-devops-lab.git
cd gke-microservices-devops-lab
```

### 2. Environment Configuration

Configure your GCP project ID, region, and cluster name in `config-gke-cluster.sh`, then execute `create-gke-cluster.sh` to create the GKE cluster.

To avoid unnecessary costs, clean up and delete all resources after finishing your experiment using `delete-gke-cluster.sh`.

### 3. Deploy the  Application

Run the deployment script:

```bash
scripts/deploy-k8s-app.sh
```
This script deploys the Online Boutique application on GKE.

