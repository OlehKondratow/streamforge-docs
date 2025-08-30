+++
title = "Google Kubernetes Engine (GKE)"
weight = 53
[params]
  menuPre = '<i class="fa-fw fas fa-cloud"></i> '
+++

## Introduction

This Terraform configuration deploys a Google Kubernetes Engine (GKE) Autopilot cluster in Google Cloud Platform (GCP). It creates a custom VPC, subnet with secondary ranges for pods and services, enables required APIs, and sets up a regional Autopilot cluster. The setup is minimalistic and cost-effective by default, suitable for development environments.

**Note:** GKE Autopilot manages node pools automatically; do not manually create resources in the `kube-system` namespace, as it is managed by GKE.

## Prerequisites

- A Google Cloud Platform (GCP) account with a billing account enabled (even for free tier usage; check GCP Free Tier limits).
- Terraform installed (version >= 1.6).
- Google Cloud SDK (`gcloud`) installed and authenticated with `gcloud auth login`.
- kubectl installed for Kubernetes interactions.
- A GCP project ID (set in `terraform.tfvars`).
- A GitLab Personal Access Token with `api`, `read_repository`, and `write_repository` scopes for managing Terraform state.

## Directory Structure

The configuration files are located in `infra/live/dev/gke/`:

- `versions.tf`: Specifies Terraform and provider versions.
- `variables.tf`: Defines input variables with defaults.
- `providers.tf`: Configures the Google provider.
- `apis.tf`: Enables required GCP APIs.
- `network.tf`: Creates VPC and subnet.
- `cluster.tf`: Deploys the GKE Autopilot cluster.
- `outputs.tf`: Defines outputs like cluster name and connection hints.
- `terraform.tfvars`: Example variable values (customize with your project ID and GitLab access token).
- `backend.tf`: Configures the GitLab HTTP backend for Terraform state management.

## Installation and Deployment

This configuration uses GitLab's HTTP backend for storing Terraform state.

1.  **Configure GitLab HTTP Backend (`backend.tf`):**
    Ensure your `backend.tf` file in `infra/live/dev/gke/` contains the following:

    ```terraform
    terraform {
      backend "http" {
      }
    }
    ```

2.  **Initialize Terraform:**
    When initializing Terraform, you need to provide the GitLab backend details, including authentication. Replace `glpat-YOUR_ACCESS_TOKEN` with your actual GitLab Personal Access Token.

    ```bash
    terraform -chdir=infra/live/dev/gke init \
      -reconfigure \
      -force-copy \
      -backend-config="address=https://gitlab.dmz.home/api/v4/projects/136/terraform/state/gke-dev" \
      -backend-config="lock_address=https://gitlab.dmz.home/api/v4/projects/136/terraform/state/gke-dev/lock" \
      -backend-config="unlock_address=https://gitlab.dmz.home/api/v4/projects/136/terraform/state/gke-dev/lock" \
      -backend-config="lock_method=POST" \
      -backend-config="unlock_method=DELETE" \
      -backend-config="username=kinga" \
      -backend-config="password=glpat-YOUR_ACCESS_TOKEN"
    ```
    *   `-reconfigure`: Re-initializes the backend configuration.
    *   `-force-copy`: Automatically answers "yes" to prompts about copying existing state to the new backend. This is useful for initial setup or migrating local state.
    *   `username` and `password`: Used for authenticating with the GitLab HTTP backend. The password should be your GitLab Personal Access Token.

3.  **Review the Plan:**
    ```bash
    terraform -chdir=infra/live/dev/gke plan
    ```

4.  **Apply the Configuration:**
    ```bash
    terraform -chdir=infra/live/dev/gke apply -auto-approve
    ```
    This will create the VPC, enable APIs, and deploy the GKE cluster. Monitor the output for any errors.

## Usage

After deployment, Terraform will output:
- `cluster_name`: The name of the GKE cluster.
- `cluster_region`: The region of the cluster.
- `get_credentials_hint`: A ready-to-use `gcloud` command to configure kubectl.

Example outputs:
```
cluster_name = "gke-free-autopilot"
cluster_region = "us-central1"
get_credentials_hint = "gcloud container clusters get-credentials gke-free-autopilot --region us-central1 --project stream-forge-4"
```

## Accessing the Cluster

1.  **Configure kubectl:**
    Run the command from the `get_credentials_hint` output to update your local kubeconfig:
    ```bash
    gcloud container clusters get-credentials ${cluster_name} --region ${cluster_region} --project ${project_id}
    ```
    Replace placeholders with actual values.

2.  **Verify Access:**
    ```bash
    kubectl get nodes
    ```
    This should list the Autopilot-managed nodes.

3.  **Interact with the Cluster:**
    Use `kubectl` commands to deploy applications, manage resources, etc.

## Smoke Test

To verify the cluster is working:

1.  Save the following YAML as `smoke-test.yaml`:
    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: smoke-test-nginx
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: nginx
      template:
        metadata:
          labels:
            app: nginx
        spec:
          containers:
          - name: nginx
            image: nginx:alpine
            resources:
              requests:
                cpu: "100m"
                memory: "128Mi"
              limits:
                cpu: "100m"
                memory: "128Mi"
            ports:
            - containerPort: 80
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: smoke-test-nginx
    spec:
      type: ClusterIP
      selector:
        app: nginx
      ports:
      - port: 80
        targetPort: 80
    ```

2.  Apply the manifest:
    ```bash
    kubectl apply -f smoke-test.yaml
    ```

3.  Port-forward to access locally:
    ```bash
    kubectl port-forward svc/smoke-test-nginx 8080:80
    ```
    Open http://localhost:8080 in a browser to see the nginx welcome page. Press Ctrl+C to stop.

4.  Clean up:
    ```bash
    kubectl delete -f smoke-test.yaml
    ```

## Cleanup

To destroy the resources:
```bash
terraform -chdir=infra/live/dev/gke destroy -auto-approve
```

## GitLab Terraform State Management Notes

This section provides additional details and troubleshooting tips for managing Terraform state with GitLab.

### `terraform.tfvars` and `gitlab_access_token`

You might have a `gitlab_access_token` variable defined in your `terraform.tfvars` file (e.g., `infra/live/dev/gke/terraform.tfvars`). If there is no corresponding `variable "gitlab_access_token"` block in your Terraform configuration, you might see a warning like:

```
Warning: Value for undeclared variable

The root module does not declare a variable named "gitlab_access_token" but
a value was found in file "terraform.tfvars". If you meant to use this
value, add a "variable" block to the configuration.
```
This is a warning and does not prevent Terraform from functioning, especially if the token is primarily used for backend authentication via command-line flags.

### Handling State Locks

Terraform acquires a state lock to prevent concurrent modifications. If a `terraform init` or `terraform apply` command fails or is interrupted, the state might remain locked.

If you encounter an "Error acquiring the state lock", you will need to clear the lock manually in the GitLab UI:

1.  Navigate to your GitLab project.
2.  Go to **Operate** -> **Terraform states**.
3.  Find the relevant state (e.g., `gke-dev`).
4.  If an active lock is present, use the "Unlock" or "Clear lock" option to release it.

After clearing the lock, re-run your `terraform init` command.

## Outputs:

```
cluster_name = "gke-free-autopilot"
cluster_region = "us-central1"
get_credentials_hint = "gcloud container clusters get-credentials gke-free-autopilot --region us-central1 --project stream-forge-4"

```

# GKE Module

This directory contains a Terraform module for provisioning a Google Kubernetes Engine (GKE) cluster.

## Features

- Deploys a GKE cluster with configurable settings.
- Manages node pools, networking, and other cluster-related resources.

## Usage

To use this module, include it in your Terraform configuration:

```terraform
module "gke_cluster" {
  source = "./modules/gke"

  project_id   = var.project_id
  region       = var.region
  cluster_name = "my-gke-cluster"
  # ... other variables
}
```

## Inputs

| Name         | Description                               | Type     | Default |
|--------------|-------------------------------------------|----------|---------|
| `project_id` | The GCP project ID.                       | `string` | n/a     |
| `region`     | The GCP region for the GKE cluster.       | `string` | n/a     |
| `cluster_name` | The name of the GKE cluster.              | `string` | n/a     |
| `node_locations` | List of zones in which the cluster's nodes are located. | `list(string)` | `[]` |
| `initial_node_count` | The number of nodes in the cluster.       | `number` | `1`     |

## Outputs

| Name             | Description                               |
|------------------|-------------------------------------------|
| `cluster_name`   | The name of the created GKE cluster.      |
| `cluster_endpoint` | The endpoint of the GKE cluster.          |
| `kubeconfig`     | Kubeconfig for connecting to the cluster. |
