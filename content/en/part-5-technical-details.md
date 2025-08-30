+++
date = '2025-08-24T20:26:06+02:00'
draft = false
title = 'Part V'
weight = 5
+++

## Part V: Technical Details and Appendices

This section provides detailed technical specifications, configuration examples, and operational guides intended for an in-depth study of the StreamForge platform's architecture and implementation.

### Appendix A: Data Schemas and API

This appendix provides the complete technical specification for the `queue-manager` API, including detailed JSON schemas for all message types exchanged via Apache Kafka. This information is essential for developers and system architects requiring a comprehensive understanding of the internal data structures and component interactions.

### Appendix B: Kubernetes Manifest Examples

This appendix contains example Kubernetes manifests that illustrate the deployment and configuration of various StreamForge components within the cluster.

#### Example: Kubernetes Job for `arango-candles`

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job-arango-candles-btcusdt-abc123
  namespace: stf
  labels:
    app: streamforge
    queue_id: "wf-btcusdt-api_candles_1m-20240801-abc123"
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: arango-candles
          image: registry.dmz.home/streamforge/arango-candles:v0.1.5
          env:
            - name: QUEUE_ID
              value: "wf-btcusdt-api_candles_1m-20240801-abc123"
            - name: SYMBOL
              value: "BTCUSDT"
            - name: TYPE
              value: "api_candles_1m"
            - name: KAFKA_TOPIC
              value: "wf-btcusdt-api_candles_1m-20240801-abc123-data"
            - name: COLLECTION_NAME
              value: "btcusdt_api_candles_1m_2024_08_01"
            # ... other variables from ConfigMap and Secret ...
      nodeSelector:
        streamforge-worker: "true" # Example selector for dedicated nodes
  backoffLimit: 2
  ttlSecondsAfterFinished: 3600
```

### Appendix C: CI/CD Pipeline Details and Best Practices

This appendix details the standardized CI/CD processes implemented within the StreamForge platform, emphasizing the best practices applied for efficient and consistent microservice development, building, and deployment.

**Key Principles and Implementations:**

*   **Unified Base Image for Services and Tests:** A single, comprehensive base Docker image (`registry.dmz.home/kinga/stream-forge/base:latest`, built from `platform/Dockerfile`) is utilized across all Python services for both application runtime and testing. This image pre-installs common Python dependencies, including all necessary test frameworks (e.g., `pytest`, `httpx`, `python-arango`), and integrates the `streamforge_utils` library via a robust wheel installation. This approach ensures environmental consistency, reduces build times, and simplifies dependency management.

*   **Optimized Kaniko Builds:** Container image builds leverage `kaniko` for secure, daemonless operations directly within the Kubernetes cluster. Build processes are optimized by:
    *   Using the project root (`$CI_PROJECT_DIR`) as the build context, allowing Dockerfiles to efficiently access shared libraries and resources across the repository.
    *   Implementing explicit image layer caching (`--cache=true --cache-repo "$CI_REGISTRY_IMAGE/cache"`) to significantly accelerate subsequent builds by reusing unchanged layers.

*   **Streamlined Testing:** Unit and integration tests are executed within the unified base image, benefiting from pre-installed test dependencies. This eliminates redundant dependency installations during pipeline execution, leading to faster and more reliable test cycles.

*   **Modular CI/CD Configuration:** The CI/CD configuration is structured with common templates (e.g., `.build_python_service` in `.gitlab/ci-templates/Python-Service.gitlab-ci.yml`) that are extended by specific pipelines for each microservice. This modularity promotes reusability, simplifies maintenance, and ensures consistent application of CI/CD best practices across the platform.


### Appendix D: Glossary of Terms

This glossary provides definitions for key terms and concepts used throughout the StreamForge documentation, including terms such as Workflow, Job, Decoupling, and Idempotence, to ensure a consistent and technically accurate understanding.

### Appendix E: Deployment and Operations Guide

This guide contains step-by-step instructions for deploying the StreamForge platform from scratch, along with best-practice recommendations for monitoring, backup procedures, and system updates, ensuring comprehensive lifecycle management.

### Appendix F: Testing Procedure

Functional and integration testing of the StreamForge system is facilitated by a suite of specialized tools, including `dummy-service` and `debug_producer.py`. These utilities are most effectively utilized within the standardized `devcontainer` development environment.

**1. `dummy-service`: Diagnostic and Simulation Microservice**

`dummy-service` is designed to simulate the behavior of various services, verify connectivity with Apache Kafka, and simulate various load scenarios.

*   **Launch:** The service can be launched in Kubernetes as a `Job` or `Pod`. For local testing in `devcontainer`, the following command is used:
    ```bash
    python3.11 -m app.main --debug --simulate-loading
    ```
*   **Further Information:** A detailed description is available in `services/dummy-service/README.md`.

**2. `debug_producer.py`: CLI for Command Injection and Response Validation**

This CLI tool is used to send test commands (`ping`, `stop`) to Apache Kafka and subsequently verify the received responses.

*   **Kafka Connectivity Testing (ping/pong):**
    ```bash
    python3.11 services/dummy-service/debug_producer.py \
      --queue-id <your-queue-id> \
      --command ping \
      --expect-pong
    ```
*   **Stop Command Testing (stop):**
    ```bash
    python3.11 services/dummy-service/debug_producer.py \
      --queue-id <your-queue-id> \
      --command stop
    ```
*   **Load Simulation and Status Tracking Testing:** Launching `dummy-service` with the `--simulate-loading` flag allows monitoring events in the `queue-events` topic.

*   **Failure Simulation Testing:** Launching `dummy-service` with the `--fail-after N` parameter allows observing the sending of `error` events.
*   **Prometheus Metrics Testing:** Metrics are checked using `curl localhost:8000/metrics`.

**3. `devcontainer`: Standardized Development Environment**

A `devcontainer` specification is used to provision a complete, self-contained development environment within a Docker container, tightly integrated with VS Code. This approach guarantees a consistent and reproducible environment for all project developers.

**Key Features:**
*   **Base Image:** Ubuntu 22.04 LTS.
*   **Tools:** Includes pre-installed tools such as `kubectl`, Helm, `gitlab-runner`, `git`, `curl`, `ssh`, and others.
*   **Kubernetes Access:** Automatic configuration of access to the Kubernetes cluster.
*   **Users and SSH:** Creation of a separate user and configuration of SSH access.
*   **Certificates:** Installation of CA certificates to ensure trust in internal services.

**Usage Instructions:**
1.  Install Docker Desktop and the "Dev Containers" extension for VS Code.
2.  Open the StreamForge project in VS Code and select "Reopen in Container."
3.  VS Code will automatically build the image and launch the container.

### Appendix G: Kafka Resource Management

The Kubernetes manifests located in the `cred-kafka-yaml/` directory are used for the declarative management of Apache Kafka resources via the Strimzi operator. This includes the creation of topics (`queue-control`, `queue-events`), the management of Kafka users (`user-streamforge`) and their access control lists (ACLs), and the secure management of credentials via Kubernetes Secrets.

### Appendix H: Kubernetes Debugging Environment

For in-cluster debugging and interactive sessions, StreamForge leverages the following tools and methodologies:

*   **JupyterHub:** Enables the on-demand provisioning of interactive Jupyter Notebook sessions directly within the Kubernetes cluster. The container images used for these sessions are pre-configured with essential command-line tools, including `kubectl` and `helm`.

    **Key Features of JupyterHub Setup:**
    *   **Idle Server Management:** Automatic termination of idle Jupyter servers to optimize resource utilization.
    *   **Authentication:** Simple "dummy" authentication is used for the test environment.
    *   **Base Database:** `sqlite-memory` is used, but data is persisted on the host.
    *   **Pod Placement:** Hub and user servers are launched on node `k2w-8`.
    *   **Access:** Via Ingress at `jupyterhub.dmz.home` with TLS.
    *   **User Server Images:** A custom image `registry.dmz.home/streamforge/core-modules/jupyter-python311:v0.0.2` with necessary tools is used.
    *   **Resources:** Guaranteed memory allocation for each server — `1G`.
    *   **Data Storage:** Persistent volumes mounted from the host are used for `/home/`, `/data/project`, `/data/venv`.
    *   **Security:** Pods are launched with `UID: 1001` and `FSGID: 100`.
    *   **Docker Registry:** The `regcred` secret is used for authentication.

*   **Dev Container (VS Code):** Described in detail in Appendix F.

*   **General-Purpose Debug Container:** A general-purpose Docker image is maintained, containing a wide range of tools (`kubectl`, `helm`, `kafkacat`, `python`). This image can be deployed as an ephemeral pod (`kubectl run -it ...`) for interactive debugging and administrative tasks directly within the cluster.

```