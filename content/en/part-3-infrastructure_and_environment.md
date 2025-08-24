+++
date = '2025-08-24T20:23:59+02:00'
draft = true
title = 'Infrastructure and env'
weight = 3
+++

## Part III: Infrastructure and Environment

The **StreamForge** platform is deployed within a high-performance, on-premises environment engineered for maximum reliability, scalability, and operational efficiency. The infrastructure is built upon a curated stack of enterprise-grade open-source technologies. At its core is a **Kubernetes** cluster, operating within a virtualized environment and managed through modern GitOps methodologies and cloud-native architectural patterns.

### Chapter 5: Platform Fundamentals: Kubernetes and Virtualization

#### 5.1. Foundation: Proxmox VE

**Proxmox VE** serves as the foundational virtualization layer—a mature, enterprise-grade platform that provides robust isolation of computing environments, high availability, and centralized resource management. Virtual machines deployed on Proxmox VE serve as the hosts for the Kubernetes cluster nodes.

#### 5.2. Cluster Deployment: Kubespray

The Kubernetes cluster is deployed using **Kubespray**—a CNCF-conformant, automated tool for production-ready environments. Kubespray delivers an idempotent and repeatable deployment process, encompassing control-plane installation, network topology configuration, and TLS integration, thereby guaranteeing cluster consistency and reproducibility.

#### 5.3. Network Infrastructure

StreamForge's network infrastructure is engineered for high reliability and adaptability, with a focus on fault tolerance and transparent external access:

- **kube-vip** provides a virtual IP address for High Availability (HA) access to the Kubernetes API, allowing automatic traffic redirection in case of a control plane node failure.
- **MetalLB** version `0.14.9` is used in Layer2 mode to support `LoadBalancer` type services in a bare-metal environment, eliminating the need for a hardware load balancer.

#### 5.4. Ingress and Gateway API: Traffic Management

A dual Ingress controller strategy is employed in StreamForge to manage incoming traffic, ensuring flexible routing and high availability:

- **Traefik** (v36.1.0) — the primary Ingress controller, utilizing the new **Gateway API** for declarative routing and traffic management at L7 (HTTP/HTTPS) and L4 (TCP/UDP) layers.
- **ingress-nginx** (v4.12.1) — a backup Ingress controller, providing compatibility and additional fault tolerance.

Settings include:
- TLS via `cert-manager` and internal CA `homelab-ca-issuer`
- External IP: `192.168.1.153`
- ACME storage: 1Gi NFS
- Monitoring via `/dashboard`
- Support for TCP services (`ssh`, `kafka`)

#### 5.5. DNS and TLS

- **Technitium DNS Server** provides a local resolver with support for arbitrary DNS zones, including `*.dmz.home`, ensuring access to services by human-readable names.
- **cert-manager** automates TLS certificate management, reducing the risk of errors and enhancing the security of communications between components.

##### `script.sh` for TLS Certificate Generation

The `/platform/base/cert/script.sh` script automates the full lifecycle of TLS certificate generation, including:
1. Configuration of generation and storage parameters;
2. Creation of CSR with SAN fields (FQDN + IP);
3. Formation of a `CertificateRequest` resource and submission to `cert-manager`;
4. Waiting for execution and saving PEM files;
5. Certificate validation via `openssl`.

---

### Chapter 6: Data Management: Storage and Access Strategies

Persistent data storage is a critically important aspect for ensuring long-term analytics and effective model training. In StreamForge, data storage is segmented by functional zones to optimize performance and availability.

#### 6.1. Overview of Storage Solutions

- **Linstor Piraeus** — a fault-tolerant block storage (RWO) for critical services such as PostgreSQL and ArangoDB, ensuring high availability and data integrity.
- **GlusterFS** and **NFS Subdir External Provisioner** (v4.0.18) — provide shared volumes with RWX (ReadWriteMany) access mode, which is ideal for collaborative environments like JupyterHub and for shared datasets. The primary access path is `192.168.1.6:/data0/k2`.

#### 6.2. Object Storage Minio

- **Minio** — an S3-compatible object storage, serves as the primary repository for:
- storing model artifacts (e.g., GNN, PPO),
- backing up services and metadata.

Ensures high availability and integration with Kubernetes via StatefulSet.

---

### Chapter 7: Data Platform: Information Management

#### 7.1. Strimzi Kafka Operator

**Strimzi** automates the full lifecycle management of Apache Kafka within a Kubernetes environment, including deployment, updates, topic configuration, encryption, and monitoring. Integration is achieved declaratively through Custom Resources such as `KafkaUser`, `KafkaTopic`, and `KafkaConnect`.

#### 7.2. ArangoDB: Multi-Model Database

ArangoDB is a multi-model database that natively integrates document and graph data models within a single engine:
- **Documents**: used for storing historical candles and events, providing flexibility and scalability.
- **Graphs**: applied to describe complex relationships between assets and trading operations, which is critically important for the functioning of Graph Neural Networks (GNN).

#### 7.3. PostgreSQL (Zalando Operator)

The **Zalando Operator** manages the deployment and operation of PostgreSQL clusters with high availability, automated backups, and failover mechanisms. This solution is used for storing structured relational data, including Return on Investment (ROI) tables, agent action logs, and experiment metadata.

#### 7.4. Autoscaling with KEDA

**KEDA** (Kubernetes Event-driven Autoscaling) enables dynamic, event-driven scaling of consumer pods based on the message backlog in Apache Kafka. This ensures optimal adaptation to fluctuating workloads without manual intervention, which optimizes resource utilization, reduces operational costs, and minimizes processing latency.

#### 7.5. Kafka UI

**Kafka UI**, a web interface from `provectuslabs`, offers an intuitive visual control plane for managing topics, consumer groups, users, and messages in Apache Kafka.

Parameters:
- Access at `https://kafka-ui.dmz.home`
- Integration via SASL_SSL (SCRAM-SHA-512)
- Connection to cluster `k3`
- Running on `k2w-7`, 1 replica

---

### Chapter 8: Monitoring and Observability: Comprehensive System Control

To ensure stable operation and enable rapid incident response, StreamForge leverages a comprehensive observability stack.

#### 8.1. Metrics: Prometheus, NodeExporter, cAdvisor

- **Prometheus** — the core time-series database for collecting and storing system and application metrics.
- **cAdvisor** — a tool for monitoring container resources and performance.
- **NodeExporter** — an exporter for operating system and host metrics.

Components:
- kube-prometheus-stack `v71.1.0`
- TLS + Ingress for Prometheus (`prometheus.dmz.home`) and Grafana (`grafana.dmz.home`)
- Persistent volumes: Prometheus — 20Gi, Grafana — 1Gi

#### 8.2. Logs: Fluent-bit, Elasticsearch, Kibana

A centralized logging pipeline based on the **EFK stack** (Elasticsearch, Fluent-bit, Kibana) is implemented for system-wide log aggregation, routing, and analysis:

- **Fluent-bit** applies a Lua filter for dynamic index creation based on tags (e.g., `internal-myapp-2025.08.07`), providing flexibility in log indexing.
- **Elasticsearch** provides full-text search, aggregations, and log storage.
- **Kibana** visualizes logs, offering a convenient interface for analysis by tags, indices, and time ranges.

#### 8.3. Grafana and Alertmanager

- **Grafana** — the primary platform for data visualization, integrated with Prometheus, Elasticsearch, and PostgreSQL to provide a unified view of system metrics and logs.
- **Alertmanager** — manages the routing, grouping, and dispatching of alerts via email and Telegram based on predefined rules.

---

### Chapter 9: Automation and GitOps: Optimizing Deployment Processes

StreamForge is managed through a strict GitOps methodology, which automates and streamlines deployment and infrastructure management, thereby minimizing manual intervention and enhancing system reliability.

#### 9.1. GitLab Runner

CI/CD pipelines are powered by GitLab CI, utilizing `kaniko` for secure, daemonless container image builds directly within the Kubernetes cluster. To optimize build times and ensure consistency across development, testing, and production environments, a **unified base image** is employed. This image, built from `platform/Dockerfile`, pre-installs common Python dependencies, including all necessary test frameworks and libraries, and integrates the `streamforge_utils` library via a robust wheel installation.

- The Runner operates in a `kubernetes` executor with a `nodeSelector` on node `k2w-9` for optimal resource distribution.
- **Kaniko build processes are optimized** by using the project root as the build context and leveraging explicit image layer caching (`--cache=true`) to significantly speed up subsequent builds.
- CI/CD configuration is divided into common templates (`.build_python_service`) and specific pipelines for each service, ensuring modularity and reusability.

##### 9.1.1. Runner: Configuration Features

- Privileged rights
- ServiceAccount: `full-access-sa`
- Pools: `runner-home`, `docker-config`, `home-certificates`
- Repository: `https://gitlab.dmz.home/`

##### 9.1.2. Pipeline Structure

- `setup` → `build` → `test` → `deploy`
- Include files with paths to services are used
- Reusable templates `.gitlab/ci-templates/`

##### 9.1.3. Integration and Modularity

Each service (e.g., `dummy-service`) uses `SERVICE_NAME`, `SERVICE_PATH` variables and extends a common template.

#### 9.2. ArgoCD

**ArgoCD** is the declarative GitOps engine responsible for the automated management of the Kubernetes cluster state based on a Git repository. It provides:

- **Single Source of Truth:** The `iac_kubeadm` repository (`gitlab.dmz.home`) serves as the single source of truth for cluster configuration.
- **TLS Support:** Secure communication with GitLab is ensured via TLS.
- **Web Access:** Access to the ArgoCD user interface is available at `argocd.dmz.home`.

- **Version Control:** All infrastructure components are under version control, simplifying change tracking and rollback to previous states.

#### 9.3. Reloader

**Reloader** is a lightweight controller that automates the rolling update of pods when their associated `Secret` or `ConfigMap` objects are modified. This guarantees that applications always use the latest configuration without manual intervention.

---

### Chapter 10: Security and Additional Capabilities

#### 10.1. HashiCorp Vault

**HashiCorp Vault** is integrated with the `Vault CSI Driver` to facilitate the secure and dynamic injection of temporary secrets into Kubernetes pods, preventing their persistent storage within the cluster.

#### 10.2. Keycloak

**Keycloak** serves as the central Identity and Access Management (IAM) solution for all platform services. It supports SSO (Single Sign-On) and OpenID Connect standards, integrating with Grafana, Kibana, and ArgoCD for centralized user and permission management.

#### 10.3. NVIDIA GPU Operator

The **NVIDIA GPU Operator** automates the management of NVIDIA GPU resources within the Kubernetes cluster, including driver installation and configuration, thereby abstracting hardware complexities.

- Version: `v24.9.2`
- GNN Training Support: Provides the necessary infrastructure for efficient Graph Neural Network training.
- Easy Updates via Helm: Simplifies the process of updating and managing the operator.

#### 10.4. Other Utilities

- `kubed` — a controller for synchronizing Kubernetes resources (e.g., Secrets, ConfigMaps) between namespaces, ensuring configuration consistency.
- `Mailrelay` — a centralized SMTP relay for dispatching notifications from various system components, including Alertmanager, CronJobs, and CI/CD pipelines.


##### 9.1.2. Pipeline Structure

- `setup` → `build` → `test` → `deploy`
- Include files with paths to services are used
- Reusable templates `.gitlab/ci-templates/`

##### 9.1.3. Integration and Modularity

Each service (e.g., `dummy-service`) uses `SERVICE_NAME`, `SERVICE_PATH` variables and extends a common template.

#### 9.2. ArgoCD

**ArgoCD** is the declarative GitOps engine responsible for the automated management of the Kubernetes cluster state based on a Git repository. It provides:

- **Single Source of Truth:** The `iac_kubeadm` repository (`gitlab.dmz.home`) serves as the single source of truth for cluster configuration.
- **TLS Support:** Secure communication with GitLab is ensured via TLS.
- **Web Access:** Access to the ArgoCD user interface is available at `argocd.dmz.home`.

- **Version Control:** All infrastructure components are under version control, simplifying change tracking and rollback to previous states.

#### 9.3. Reloader

**Reloader** is a lightweight controller that automates the rolling update of pods when their associated `Secret` or `ConfigMap` objects are modified. This guarantees that applications always use the latest configuration without manual intervention.

---

### Chapter 10: Security and Additional Capabilities

#### 10.1. HashiCorp Vault

**HashiCorp Vault** is integrated with the `Vault CSI Driver` to facilitate the secure and dynamic injection of temporary secrets into Kubernetes pods, preventing their persistent storage within the cluster.

#### 10.2. Keycloak

**Keycloak** serves as the central Identity and Access Management (IAM) solution for all platform services. It supports SSO (Single Sign-On) and OpenID Connect standards, integrating with Grafana, Kibana, and ArgoCD for centralized user and permission management.

#### 10.3. NVIDIA GPU Operator

The **NVIDIA GPU Operator** automates the management of NVIDIA GPU resources within the Kubernetes cluster, including driver installation and configuration, thereby abstracting hardware complexities.

- Version: `v24.9.2`
- GNN Training Support: Provides the necessary infrastructure for efficient Graph Neural Network training.
- Easy Updates via Helm: Simplifies the process of updating and managing the operator.

#### 10.4. Other Utilities

- `kubed` — a controller for synchronizing Kubernetes resources (e.g., Secrets, ConfigMaps) between namespaces, ensuring configuration consistency.
- `Mailrelay` — a centralized SMTP relay for dispatching notifications from various system components, including Alertmanager, CronJobs, and CI/CD pipelines.
