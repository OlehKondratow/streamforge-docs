+++
date = '2025-08-25T10:02:00+02:00'
draft = false
icon: "article"
title = 'Part II'
weight = 2
+++

# Infrastructure Platform and Technology Stack

### **Chapter 5: Platform Fundamentals: Kubernetes and Virtualization**

The StreamForge application is deployed on a powerful and flexible infrastructure platform built on Kubernetes and modern cloud-native tools.

#### **5.1. Physical Layer: Proxmox VE Hypervisor**

`Proxmox VE` is used as the basis for virtualization. This allows for efficient management of physical resources, creation of virtual machines for Kubernetes nodes, and ensures isolation and flexibility in the distribution of computing power.

#### **5.2. Cluster Deployment: Kubespray**

The Kubernetes cluster is deployed using `Kubespray`. This tool provides automated and reproducible creation of production-ready clusters, which significantly simplifies initial setup and subsequent updates.

#### **5.3. Network Infrastructure**

*   **`kube-vip` for High Availability Control Plane:** To ensure high availability of the control plane nodes, `kube-vip` is used. It provides a virtual IP address for the Kubernetes API server, which avoids a single point of failure.
*   **`MetalLB` for Service Type `LoadBalancer`:** In a "bare-metal" environment, `MetalLB` allows the use of the standard `LoadBalancer` service type, providing external IP addresses for access to services from outside the cluster.

#### **5.4. Ingress and Gateway API**

To manage external traffic and its routing to internal services, two leading Ingress controllers are used: `Traefik` and `ingress-nginx`. `Traefik` is the preferred solution, in part due to its support for the new **Gateway API** standard, which offers a more flexible and role-based model for traffic management. `ingress-nginx` (version `4.12.1`, application `1.12.1`) is also deployed with standard settings and serves as an alternative or additional Ingress controller.

**Traefik Configuration (version `36.1.0`, application `v3.4.1`):**

*   **EntryPoints:**
    *   `web`: HTTP on port `80`, automatically redirected to `websecure` (HTTPS).
    *   `websecure`: HTTPS on port `443` with TLS enabled.
    *   `ssh`: TCP on port `2222`.
    *   `kafka`: TCP on port `9094`.
*   **Dashboard:** Enabled and accessible via Ingress at `traefik.dmz.home/dashboard`. A TLS certificate (`traefik-dashboard-tls`) is automatically issued for it using `cert-manager`.
*   **Certificate Management:** `certificatesResolvers` with a `default` ACME challenge is used for automatic retrieval of TLS certificates. The storage for ACME data (`acme.json`) is in a persistent volume.
*   **Persistence:** Persistence is enabled with a `PersistentVolumeClaim` of size `1Gi` based on `nfs-client` to store Traefik data (e.g., ACME certificates).
*   **Service Type:** `LoadBalancer` with a fixed IP address `192.168.1.153` for external access.
*   **Providers:** `kubernetesCRD` and `kubernetesIngress` are enabled to discover and route traffic to services defined via Ingress resources and Traefik custom resources.

#### **5.5. DNS and TLS Management**

*   **`Technitium DNS Server`:** Used as a local DNS server to resolve names in the `dmz.home` domain, which simplifies access to services by human-readable names.
*   **`cert-manager`:** Automates the process of managing TLS certificates. In conjunction with a local `ClusterIssuer`, it provides automatic issuance and rotation of certificates for all Ingress resources, ensuring a secure `HTTPS` connection.

### **Chapter 6: Storage System**

Reliable and high-performance storage is a critical component of the StreamForge platform. Specialized solutions are used for different data types and use cases.

#### **6.1. Storage Solutions Overview**

*   **`Linstor Piraeus` (RWO - ReadWriteOnce):** This solution is used to provide high-performance block storage. It is ideal for stateful applications that require low latency and high throughput, such as databases (`ArangoDB`, `PostgreSQL`).
*   **`GlusterFS` and `NFS Subdir External Provisioner` (RWX - ReadWriteMany):** These systems provide shared file storage. They are used for scenarios where multiple pods need to read and write data to the same volume simultaneously, for example, for storing shared configurations or log files.

    **`NFS Subdir External Provisioner` (version `4.0.18`, application `4.0.2`):**
    *   **NFS Server:** `192.168.1.6`
    *   **NFS Path:** `/data0/k2`
    *   **Purpose:** Used for dynamic provisioning of persistent volumes (PV) based on an existing NFS server, providing `ReadWriteMany` (RWX) access for multiple pods. This is critical for shared file systems such as JupyterHub home directories or shared project data.

#### **6.2. Minio Object Storage**

`Minio` provides S3-compatible object storage within the cluster. In StreamForge, it performs two key functions:
1.  **Storage of Machine Learning Artifacts:** `gnn-trainer` saves trained models, their weights, checkpoints, and training metrics in Minio. This ensures versioning and long-term storage of experiment results.
2.  **Backup Storage:** Used to store backups of databases and other critical system components.

### **Chapter 7: Data Platform**

The data platform is the core of StreamForge, providing for the collection, transmission, storage, and processing of information.

#### **7.1. `Strimzi Kafka Operator` as the Core of the Messaging System**

`Strimzi` is used for declarative management of Apache Kafka clusters in Kubernetes. It automates complex tasks such as deployment, configuration, topic and user management, and also ensures high availability and fault tolerance of the message broker.

#### **7.2. `ArangoDB` Multi-model Database**

`ArangoDB` was chosen as the primary database due to its multi-model nature. It allows you to store data both as documents (JSON) and as graphs, which is ideal for StreamForge tasks:
*   **Document Model:** Used to store "flat" data, such as historical candles, trades, and the state of `queue-manager` queues.
*   **Graph Model:** Is key to the analytical layer. `graph-builder` creates graphs of market relationships, which are then used by `gnn-trainer` to train models.

#### **7.3. `PostgreSQL` Relational Database (Zalando Operator)**

`PostgreSQL` is used to store structured service data that requires strict consistency and transactionality (e.g., user configurations, metadata). PostgreSQL cluster management is automated using the Zalando operator, which ensures high availability and ease of management.

#### **7.4. Event-Driven Autoscaling with `KEDA`**

`KEDA` (Kubernetes Event-driven Autoscaling) allows you to automatically scale the number of pods (workers) based on external events. In the context of StreamForge, KEDA will be used to monitor the queue length (lag) in Kafka topics. If the number of unprocessed messages in a topic exceeds a specified threshold, KEDA will automatically increase the number of consumer pods (e.g., `arango-connector`), and when the load decreases, it will reduce them, optimizing resource usage.

### **Chapter 8: Observability**

A full-fledged observability system is the cornerstone for the operation and debugging of a distributed system such as StreamForge.

#### **8.1. Metrics Stack: `Prometheus`, `cAdvisor`, `NodeExporter`**

`Prometheus` is used to collect and store time series (metrics). `NodeExporter` collects metrics from host machines (CPU, RAM, disk), and `cAdvisor` from containers. Each StreamForge microservice also provides its own metrics (e.g., `records_written_total`, `queue_requests_total`), which are automatically discovered and collected by Prometheus.

**Key Configuration Features:**

*   **Version:** `kube-prometheus-stack-71.1.0` (application `v0.82.0`).
*   **Prometheus:**
    *   **Storage:** Uses a `PersistentVolumeClaim` of size `20Gi` based on `nfs-client` to store time series data.
    *   **Access:** Accessible via Ingress at `prometheus.dmz.home` using the `nginx` Ingress controller and a TLS certificate (`prometheus-tls`).
*   **Alertmanager:**
    *   **Storage:** Uses a `PersistentVolumeClaim` of size `500Mi` based on `nfs-client` to store data.
*   **Grafana:**
    *   **Storage:** Persistence is enabled with a `PersistentVolumeClaim` of size `1Gi` based on `nfs-client`.
    *   **Access:** Accessible via Ingress at `grafana.dmz.home` using the `nginx` Ingress controller and a TLS certificate (`grafana-tls`).
*   **General Settings:** `cert-manager` with `homelab-ca-issuer` is used for all Ingress resources to automatically issue TLS certificates.

#### **8.2. Logging Stack: `Fluent-bit`, `Elasticsearch`, `Kibana`**

The logging system in StreamForge is a comprehensive solution that provides not only collection and storage, but also convenient debugging and analysis of logs. The platform uses a hybrid approach, collecting both structured application logs and system logs from cluster nodes.

**Key Components and Versions:**
*   **Elasticsearch:** `v8.12.0`
*   **Kibana:** `v8.12.0`
*   **Fluent-bit:** `v4.0.0-amd64`

**Log Collection Architecture:**

The platform divides log collection into two streams:

**1. Application Logs (Direct Forwarding):**

This mechanism is designed for StreamForge microservices and provides maximum flexibility and data enrichment.

*   **Method:** Applications, using standard logging libraries (e.g., `fluent-logger` for Python), send their logs over the network directly to the centralized `fluent-bit` aggregator service via the `forward` protocol on port `24224`.
*   **Dynamic Index Generation:** This is a key feature of the configuration. Using a special **Lua script**, `fluent-bit` analyzes the **tag** of each incoming log (e.g., `internal.my-app`). Based on this tag and a timestamp, it dynamically forms the index name in Elasticsearch in the format `prefix-app-YYYY.MM.DD` (e.g., `internal-my-app-2025.08.06`). This approach is critical for effective data management: it simplifies search, optimizes performance, and allows for easy configuration of retention policies.

**2. System and Infrastructure Logs (Collection from Files):**

In addition to application logs, `fluent-bit` (deployed as a `DaemonSet`) also collects standard logs from each cluster node.
*   **Sources:** The configuration includes log collection from:
    *   `/var/log/syslog` (system messages)
    *   `/var/log/nginx/access.log` (Nginx access logs)
    *   `/var/log/auth.log` (authentication logs)
*   **HTTP Input:** An HTTP input is also open on port `8888` to receive logs from external systems.

**Elasticsearch Configuration and Data Storage:**

*   **Deployment:** Elasticsearch runs as a `StatefulSet` with a single replica (`single-node`), which does not provide high availability, but is suitable for current tasks.
*   **Resources:** The pod is allocated 2-4Gi of memory and 1-2 CPU cores.
*   **Storage:** A `PersistentVolumeClaim` of size `10Gi` based on `nfs-client` is used for data.
*   **Retention Policy (ILM):** An index lifecycle policy (`ilmPolicy`) named `log-retention-30d` is configured:
    *   **Rollover:** A new index is created daily (`rolloverAfter: 1d`) or when the current size reaches `2gb`.
    *   **Deletion:** Data is automatically deleted after 30 days (`deleteAfter: 30d`).
*   **Access:** Access to Kibana for log analysis is at `kibana.dmz.home` and is protected by a TLS certificate.

**Implementation Examples (Application Logs):**

**1. Sending Logs from an Application (Python):**
The application should use `fluent-logger` to send structured logs with the correct tag.

```python
# Example from test-logger-script.yaml
from fluent import sender
import time
import random
import json

APP_NAME = "my-pod-app"

# Configure the logger to send to the fluent-bit service
logger = sender.FluentSender(
    tag='internal.' + APP_NAME, # Important: the tag determines the future index!
    host='fluent-bit-service.logging.svc.cluster.local',
    port=24224
)

# Generate and send a structured log
log_record = {
    'message': 'User logged in successfully',
    'level': 'INFO',
    'user_id': 12345
}
logger.emit('log', log_record)
```

**2. Processing and Index Creation (Lua in Fluent-bit):**
This Lua script, called for each record, extracts parts from the tag and creates a `log_index` field that Elasticsearch uses to name the index.

```lua
# Example from fluent-bit-config.yaml (set_index.lua)
function cb_set_index(tag, timestamp, record)
    local t = os.time()
    if timestamp and type(timestamp) == "table" and timestamp[1] > 0 then
        t = timestamp[1]
    end

    local prefix = "unknown"
    local app = "unknown"

    -- Parse the tag, e.g., "internal.my-pod-app"
    local parts = {}
    for part in string.gmatch(tag, "([^.]+)") do
        table.insert(parts, part)
    end
    if #parts >= 2 then
        prefix = parts[1]  -- "internal"
        app = parts[2]     -- "my-pod-app"
    end

    -- Create the index name based on the date
    local date = os.date("%Y.%m.%d", t)
    -- Add a new field to the log record
    record["log_index"] = prefix .. "-" .. app .. "-" .. date -- will be "internal-my-pod-app-2025.08.06"
    return 1, timestamp, record
end
```

**Debugging and Testing Tools:**

To ensure reliability and ease of development, special tools are built into the system:

*   **`test-logger-script`:** This is a test Python script that uses `fluent-logger` to generate and send logs with a given tag directly to `fluent-bit`. It allows developers to easily test the entire logging pipeline from sending to the appearance of the record in Kibana.
*   **`fluentbit-tailon`:** This is a special debugging `Deployment` that runs two containers in one pod: `fluent-bit` and `tailon` (a lightweight web interface for viewing logs). This `fluent-bit` receives logs over the network and simultaneously writes them to a local file, which `tailon` immediately displays. This makes it possible to see the "raw" stream of logs coming into the system in real time, which is invaluable for quick debugging without having to wait for indexing in Elasticsearch.

#### **8.3. Visualization and Alerting: `Grafana`, `Alertmanager`**

`Grafana` serves as a single point for visualizing both metrics from Prometheus and logs from Elasticsearch. It is used to create dashboards that display the state of the system in real time. `Alertmanager` is integrated with Prometheus and is responsible for deduplication, grouping, and routing of alerts, sending notifications to Telegram when critical situations arise.

### **Chapter 9: CI/CD and GitOps**

Automation of build, testing, and deployment is the basis for fast and reliable delivery of changes.

#### **9.1. `GitLab Runner` as a Pipeline Executor**

`GitLab Runner` is a key component of CI/CD, responsible for executing jobs defined in `.gitlab-ci.yml`. The project uses `gitlab-runner` version `bleeding` with a `kubernetes` executor, which provides deep integration with the cluster. `Kaniko` is used to build Docker images without using Docker-in-Docker.

##### **9.1.1. Runner Configuration and Features**

**General Runner Settings:**

*   **Executor:** `kubernetes`. For each CI/CD job, the Runner creates a separate Pod in the `gitlab` namespace, which guarantees isolation of builds and tests.
*   **Node Affinity:** The Runner is configured to run pods exclusively on the `k2w-9` node using `nodeSelector`.
*   **Permissions:** The Runner uses a pre-created `ServiceAccount` named `full-access-sa` and runs in privileged mode (`privileged = true`). This gives job pods broad permissions in the cluster, necessary for building images and deploying applications.
*   **Default Image:** The `ubuntu:22.04` image is used by default to execute jobs.
*   **Resources:** The following limits and requests are set for each job pod:
    *   **Request:** 100m CPU, 128Mi RAM.
    *   **Limit:** 500m CPU, 512Mi RAM.
*   **Caching:** S3-based distributed caching is used to speed up CI/CD pipelines.
    *   **Server:** `minio.dmz.home` (internal Minio).
    *   **Bucket:** `runner-cache`.
    *   **Security:** The connection to Minio is via HTTP (`Insecure = true`).
*   **Docker Registry Integration:** The `regcred` secret is mounted into pods as `/kaniko/.docker/config.json`, providing seamless authentication for push and pull operations with private Docker repositories.
*   **TLS:** The `home-certificates` secret is mounted into `/kaniko/ssl/certs`, which allows `kaniko` and other tools to trust internal TLS certificates.

**Specific `stf-runner` Configuration (k2m-runner):**

*   **Name:** `k2m-runner` (displayed as `stf-runner` in `helm list`).
*   **Version:** `0.79.0` (application `18.2.0`).
*   **GitLab URL:** `https://gitlab.dmz.home/`
*   **Kubernetes Namespace:** `gitlab`
*   **Poll Timeout:** 300 seconds.
*   **Volume Mounts:**
    *   `docker-config` (from the `regcred` secret) is mounted into `/kaniko/.docker` for Docker authentication.
    *   `home-certificates` (from the `home-certificates` secret) is mounted into `/kaniko/ssl/certs` to trust internal TLS certificates.
    *   `runner-home` (PVC `gitlab-runner-home`) is mounted into `/home/gitlab-runner` for persistent storage of Runner data.

##### **9.1.2. CI/CD Pipeline Structure**

The CI/CD pipeline of the StreamForge project is organized into several sequential `stages`, each of which performs a specific set of `jobs`.

**Pipeline Stages:**
*   **`setup`**: Preparatory work is performed at this stage, such as applying Kubernetes RBAC manifests (Service Accounts, Roles, RoleBindings) to provide the necessary permissions for subsequent deployment operations.
*   **`build`**: At this stage, Docker images are built for all microservices and base images. `Kaniko` is used to build images, which allows building inside a Kubernetes cluster without having to run a Docker daemon.
*   **`test`**: This stage is intended for running automated tests (unit tests, integration tests) to check the functionality and stability of the code.
*   **`deploy`**: At this stage, the built Docker images are deployed to the Kubernetes cluster. `kubectl` is used to interact with the cluster.

**How Jobs are Launched:**
Each job in the pipeline has specific `rules` that determine when it should be launched. Jobs can be launched automatically when certain files are changed (for example, when the service code or its `Dockerfile` is changed), and can also be configured for manual launch (`when: manual`) via the GitLab CI interface. This provides flexibility and control over the deployment process.

##### **9.1.3. Pipeline Configuration Details**

The CI/CD pipeline configuration in StreamForge is built on the principles of modularity and code reuse using the GitLab CI `include` and `extends` features.

**Main `.gitlab-ci.yml` File:**

This file is the entry point for the entire pipeline. It defines the general `stages` and `includes` configurations for individual services and platform components. This allows you to keep the main file clean and easy to manage.

Example `/.gitlab-ci.yml`:
```yaml
stages:
  - setup
  - build
  - test
  - deploy

include:
  - '/services/queue-manager/.gitlab-ci.yml'
  - '/services/loader-api-trades/.gitlab-ci.yml'
  - '/services/loader-api-candles/.gitlab-ci.yml'
  - '/services/arango-connector/.gitlab-ci.yml'
  - '/services/dummy-service/.gitlab-ci.yml'
  - 'platform/.gitlab-ci.yml' # Include configuration for the platform (base image, RBAC)
```

**CI/CD Templates (`.gitlab/ci-templates/`):**

To ensure uniformity and reuse of build and test logic, common templates are used. For example, `Python-Service.gitlab-ci.yml` contains a common configuration for building Docker images of Python services.

Example `/.gitlab/ci-templates/Python-Service.gitlab-ci.yml`:
```yaml
.build_python_service:
  stage: build
  image: gcr.io/kaniko-project/executor:debug
  script:
    - SERVICE_VERSION=$(cat $CI_PROJECT_DIR/$SERVICE_PATH/VERSION)
    - /kaniko/executor
      --context $CI_PROJECT_DIR/$SERVICE_PATH
      --dockerfile Dockerfile
      --destination $CI_REGISTRY_IMAGE/$SERVICE_NAME:$SERVICE_VERSION
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      changes:
        - $SERVICE_PATH/**/*
        - libs/**/*
    - if: '$CI_COMMIT_BRANCH == "main"'
      changes:
        - $SERVICE_PATH/**/*
        - libs/**/*
    - when: manual
      allow_failure: false
```

**Configuration for Individual Services (`services/<service-name>/.gitlab-ci.yml`):**

Each microservice has its own `.gitlab-ci.yml` file that includes a common template and extends it, providing service-specific variables.

Example `services/dummy-service/.gitlab-ci.yml`:
```yaml
include:
  - project: 'kinga/stream-forge'
    ref: main
    file: '/.gitlab/ci-templates/Python-Service.gitlab-ci.yml'

build-dummy-service:
  extends: .build_python_service
  variables:
    SERVICE_NAME: dummy-service
    SERVICE_PATH: services/dummy-service

deploy-dummy-service:
  stage: deploy
  image: bitnami/kubectl:latest
  script:
    - kubectl apply -f $CI_PROJECT_DIR/services/dummy-service/k8s/dummy-service-deployment.yaml
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: on_success
```

**Configuration for Platform Components (`platform/.gitlab-ci.yml`):**

Similar to services, platform components (e.g., base image build, RBAC application) have their own configuration files.

Example `platform/.gitlab-ci.yml`:
```yaml
include:
  - project: 'kinga/stream-forge'
    ref: main
    file: '/.gitlab/ci-templates/Python-Service.gitlab-ci.yml' # Use the same template to build the base image

build-base-image:
  extends: .build_python_service
  variables:
    SERVICE_NAME: base
    SERVICE_PATH: platform # Specify the path to the Dockerfile and VERSION for the base image

apply-rbac:
  stage: setup
  image: bitnami/kubectl:latest
  script:
    - kubectl apply -f $CI_PROJECT_DIR/input/cred-kafka-yaml/full-access-sa.yaml
    - kubectl apply -f $CI_PROJECT_DIR/input/cred-kafka-yaml/full-access-sa-binding.yaml
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      changes:
        - input/cred-kafka-yaml/full-access-sa.yaml
        - input/cred-kafka-yaml/full-access-sa-binding.yaml
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      changes:
        - input/cred-kafka-yaml/full-access-sa.yaml
        - input/cred-kafka-yaml/full-access-sa-binding.yaml
    - when: manual
      allow_failure: false
```

This structure provides flexibility, reusability, and easy scalability of CI/CD pipelines in the StreamForge project.


#### **9.2. `ArgoCD` for Declarative Cluster State Management**

`ArgoCD` implements the GitOps approach, continuously synchronizing the state of the cluster with a declarative description stored in a Git repository. This ensures that the cluster is always in the expected state and simplifies rollback to previous versions.

**Key Configuration Features:**

*   **GitOps Repository:** The platform is pre-configured to work with the `iac_kubeadm` Git repository (`https://gitlab.dmz.home/infra-a-cod/iac_kubeadm.git`), which serves as a single source of truth for the state of the cluster.
*   **Server Access:** In the current configuration (`server.insecure: true`), the ArgoCD API server is accessible without TLS encryption. Access to the web interface is via the `argocd.dmz.home` domain, however the Ingress resource for it is managed separately (`server.ingress.enabled: false`).
*   **Fault Tolerance:** All key ArgoCD components (`controller`, `repoServer`, `server`) run in a single instance (`replicas: 1`), which does not provide high availability.
*   **CRD Management:** Custom Resource Definitions (CRDs) installed by ArgoCD are not retained when the chart is deleted (`crds.keep: false`), which means a complete cleanup of resources upon uninstallation.
*   **GitLab Integration:** A TLS certificate for `gitlab.dmz.home` has been added to the configuration, which allows ArgoCD to securely connect to repositories hosted on the internal GitLab server.

#### **9.3. `Reloader` for Automatic Application Updates**

`Reloader` monitors changes in `ConfigMap` and `Secret`. When a configuration file or secret associated with a `Deployment` or `StatefulSet` is updated, `Reloader` automatically performs a rolling restart of the corresponding application so that it picks up the new settings.

### **Chapter 10: Security and Specialized Services**

#### **10.1. Secret Management with `HashiCorp Vault` and `Vault CSI Driver`**

`HashiCorp Vault` is used for secure storage and management of secrets (passwords, API keys, tokens). Integration with Kubernetes is via the `Vault CSI Driver`, which allows pods to receive secrets by mounting them as temporary volumes. This eliminates the need to store secrets as Kubernetes `Secret` objects and provides centralized management with rotation and auditing.

#### **10.2. Authentication and Authorization with `Keycloak`**

`Keycloak` acts as a centralized identity and access management server. It provides Single Sign-On (SSO) for all platform web interfaces, including `Grafana`, `Kibana`, `ArgoCD`, and the future UI of StreamForge itself.

#### **10.3. Acceleration of Computations with `NVIDIA GPU Operator`**

For machine learning tasks that require significant computing resources, the `NVIDIA GPU Operator` is used. It automates the lifecycle management of the software required to use NVIDIA GPUs in a Kubernetes environment. This includes installing drivers, device plugins, and other components, which is critical for efficient training of GNN models in `gnn-trainer`.

**Key Features:**

*   **Version:** `v24.9.2`
*   **Configuration:** The `gpu-operator` is deployed using the standard Helm chart settings. No custom parameters (`USER-SUPPLIED VALUES: null`) are applied, which ensures ease of updating and compliance with official NVIDIA recommendations.
*   **Functionality:** The operator automatically detects the presence of GPUs on cluster nodes and installs all necessary components, making them available to pods through standard Kubernetes resource request mechanisms (e.g., `nvidia.com/gpu: 1`).

#### **10.4. Other Utilities**

*   **`kubed`:** Used to synchronize resources such as `ConfigMap` and `Secret` between different namespaces, which simplifies the management of a common configuration.
*   **`Mailrelay`:** Acts as a centralized SMTP gateway for sending email notifications, for example, from `Alertmanager`.
