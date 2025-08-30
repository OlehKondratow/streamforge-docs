+++
title = "Kafka"
weight = 12
[params]
  menuPre = '<i class="fa-fw fas fa-list-ol"></i> '
+++
# Terraform Code for Automated Deployment and Management of an Apache Kafka Cluster in Kubernetes using [Strimzi Kafka Operator](https://strimzi.io/).

## Overview

This solution allows for declarative management of all aspects of a Kafka cluster: from its deployment to the creation of topics and users. The Strimzi Operator significantly simplifies the operation of Kafka in a Kubernetes environment by automating complex tasks.

### Key Features

*   **Infrastructure as Code (IaC)**: Complete lifecycle management of Kafka through Terraform.
*   **Deployment via Strimzi**: Use of Strimzi's CRDs (Custom Resource Definitions) for reliable cluster creation and management.
*   **Automation**: Automatic creation of a namespace, Kafka cluster, topics, and users.
*   **Flexible Configuration**: Cluster parameters, such as the number of replicas, storage configuration, and topics, are easily configured through Terraform variables.
*   **Security**: Built-in support for creating users with SCRAM-SHA-512 authentication and TLS encryption.
*   **External Access**: Configuration of external access to brokers via Ingress.

## Prerequisites

1.  **Kubernetes Cluster**: Access to a running Kubernetes cluster.
2.  **kubectl**: Installed and configured `kubectl` for access to your cluster.
3.  **Terraform**: Installed Terraform (version 1.x or higher).
4.  **Ingress Controller**: An Ingress Controller (e.g., Traefik, NGINX) must be installed in the cluster. `traefik` is used by default.
5.  **StorageClass**: A `StorageClass` must be available for dynamic provisioning of persistent volumes (PVCs). `linstor-storage` is used by default.
6.  **DNS**: Pre-configured DNS records pointing to your Ingress Controller for the hosts specified in the `bootstrap_host` and `broker_hosts` variables.

## 3-Stage Installation Model

Although the entire configuration is applied with a single `terraform apply` command, the deployment process can be internally divided into three logical stages that Terraform executes in the correct order thanks to dependencies (`depends_on`).

### Stage 1: Installing the Strimzi Operator

**What happens?**
At this stage, the foundation for our Kafka cluster is created.
1.  **Namespace**: Terraform creates a dedicated Kubernetes namespace (default `kafka`) to isolate all Kafka-related resources.
2.  **Strimzi Operator**: The Strimzi Kafka Operator is installed into this namespace using a Helm chart.

**Analysis and Features:**
*   **Operator-Oriented Approach**: Instead of managing Kafka pods directly, we delegate this task to the operator. The operator monitors the state of custom resources (such as `Kafka`, `KafkaTopic`) and brings the cluster into compliance with their specifications. This significantly increases reliability and simplifies updates.
*   **Idempotency**: All resources are created idempotently. Re-applying the configuration will not cause errors but will only bring the system to the desired state.

### Stage 2: Deploying the Kafka Cluster

**What happens?**
Once the operator is running and ready, Terraform creates the `Kafka` custom resource.
1.  **Kafka CRD**: Terraform sends a `Kafka` manifest to Kubernetes, describing the desired cluster configuration:
    *   Number of brokers (`kafka_replicas`).
    *   Number of Zookeeper nodes (`zk_replicas`).
    *   Storage configuration (`storage_class`).
    *   Listener settings for internal and external access.

**Analysis and Features:**
*   **Declarativeness**: We do not describe *how* to create the cluster, but only *what* it should be. The Strimzi Operator handles all the complex logic: creating `StatefulSet` for brokers and Zookeeper, managing PVCs, and configuring `Service` and `Ingress`.
*   **Scalability**: To scale the cluster, you only need to change the `kafka_replicas` variable and apply the configuration. Strimzi will safely add new brokers to the cluster.

### Stage 3: Creating Resources (Topics and Users)

**What happens?**
When the Kafka cluster is fully ready, Terraform creates the remaining resources.
1.  **KafkaTopic CRD**: For each element in the `topics` variable, a `KafkaTopic` resource is created. The Strimzi operator automatically creates these topics in Kafka with the specified parameters (number of partitions, replication, retention policy).
2.  **KafkaUser CRD**: If `create_user_streamforge` is set to `true`, a `KafkaUser` resource is created. The operator creates the user and generates a Kubernetes secret for them with credentials for SCRAM-SHA-512 authentication.

**Analysis and Features:**
*   **Management via GitOps**: The configuration of topics and users is stored in code (`variables.tf`), which is ideal for a GitOps approach. All changes are versioned and applied through a standard CI/CD pipeline.
*   **Security by Default**: Users are created with a strong authentication method. Secrets are generated automatically and stored in Kubernetes, which is more secure than storing them in plain text.

## Installation and Usage

### 1. Initialize Terraform
Execute this command in the `/infra/kafka` directory:
```bash
terraform init
```

### 2. Configure Variables
Create a `terraform.tfvars` file or modify the variables in `variables.tf` to match your environment.

**Example `terraform.tfvars`:**
```hcl
# Domain name for external access
domain = "my-cluster.com"

# Hostnames must be resolved by your DNS
bootstrap_host = "kafka-bootstrap.my-cluster.com"
broker_hosts = [
  "kafka-0.my-cluster.com",
  "kafka-1.my-cluster.com",
  "kafka-2.my-cluster.com",
]

# StorageClass available in your cluster
storage_class = "standard-rwo"

# List of topics to create
topics = [
  { name = "prod-events", partitions = 10, replicas = 3, retention_ms = 604800000, cleanup_policy = "delete" },
  { name = "prod-metrics", partitions = 5, replicas = 3, retention_ms = 86400000,  cleanup_policy = "delete" },
]
```

### 3. Deployment
Apply the configuration:
```bash
terraform apply
```
Terraform will show the plan and ask for confirmation. After entering `yes`, the deployment process will begin.

## Obtaining Credentials

After a successful deployment, Terraform will output the names of the secrets containing the cluster's CA certificate and the user's password.

*   `cluster_ca_secret_name`: The name of the secret with the CA certificate (`k3-cluster-ca-cert`).
*   `user_streamforge_secret_name`: The name of the secret with the user's password (`user-streamforge`).

**To get the user's password:**
```bash
kubectl get secret user-streamforge -n kafka -o jsonpath='{.data.password}' | base64 -d
```

**To get the CA certificate:**
```bash
kubectl get secret k3-cluster-ca-cert -n kafka -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
```

This information is required by your clients to connect to Kafka.

---

## Deployment in GKE Autopilot

Deploying in a GKE Autopilot environment requires several specific configuration changes due to the peculiarities of this platform. Autopilot manages nodes and resources automatically, which imposes certain limitations.

### Key Changes for Autopilot

1.  **StorageClass**: GKE Autopilot does not support custom `StorageClass` like `linstor-storage`. You must use the standard storage classes provided by Google Cloud.
    *   **Solution**: Change the `storage_class` variable to `standard-rwo` (for standard persistent disks) or `premium-rwo` (for SSDs).

2.  **Ingress Controller**: Instead of `traefik`, it is recommended to use the native GKE Ingress.
    *   **Solution**: Set the `ingress_class` variable to `"gce"`. However, note that the `k3-kafka.yaml.tmpl` template may need to be modified to add GKE Ingress-specific annotations if they are not created automatically.

3.  **Resource Requests**: GKE Autopilot has strict rules for managing CPU and Memory resources. Strimzi allows you to set these parameters in its CRDs.
    *   **Recommendation**: Check the `templates/k3-kafka.yaml.tmpl` template file. If it has hard-coded resource requests (`requests` and `limits`) for Kafka or Zookeeper, make sure they correspond to the ranges allowed in Autopilot. Otherwise, Autopilot may reject the creation of pods. It is often better to let Autopilot manage resources by removing these fields from the template.

### Example Configuration for GKE Autopilot

Create a `terraform.tfvars` file with the following changes:

```hcl
# Use the standard StorageClass for GKE
storage_class = "standard-rwo"

# Specify the Ingress class for GKE.
# You may need to configure annotations in the k3-kafka.yaml.tmpl template
ingress_class = "gce"

# Make sure your domain and DNS records are configured
# to work with the external IP address that will be created by GKE Ingress
domain = "gke.my-company.com"
bootstrap_host = "kafka-bootstrap.gke.my-company.com"
broker_hosts = [
  "kafka-0.gke.my-company.com",
  "kafka-1.gke.my-company.com",
  "kafka-2.gke.my-company.com",
]
```

### Deployment Process

The deployment process remains the same: `terraform init`, `terraform plan`, `terraform apply`. However, before applying the configuration, make sure that all the above changes have been made to avoid errors specific to the Autopilot environment.