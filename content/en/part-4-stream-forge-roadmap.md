+++
date = '2025-08-25T10:04:00+02:00'
draft = false
title = 'Part IV'
weight = 4
+++

## **Appendix A: Data Schemas and API**

*(This section will contain the full OpenAPI specification for `queue-manager`, as well as detailed JSON schemas for all messages transmitted via Kafka.)*

## **Appendix B: Kubernetes Manifest Examples**

### **Example: Kubernetes Job for `arango-candles`**

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

## **Appendix C: CI/CD Pipeline Examples**

*(This section will contain the full `.gitlab-ci.yml` files for each microservice, demonstrating the testing, build, and deployment stages.)*

## **Appendix D: Glossary of Terms**

*(This section will contain definitions of key terms used in the project: Workflow, Job, Decoupling, Idempotency, etc.)*

## **Appendix E: Deployment and Operations Guide**

*(This section will contain step-by-step instructions for deploying the entire platform from scratch, as well as a guide to basic operational procedures: monitoring, backups, component updates.)*

## **Appendix F: Module Descriptions**

*   **core-modules/argocd/**: Manages the deployment of ArgoCD, a GitOps tool that provides declarative and continuous deployment of applications in Kubernetes.
*   **core-modules/cert-manager/**: Responsible for automating the management of TLS certificates in Kubernetes, including their issuance and rotation.
*   **core-modules/gitlab-runner/**: Contains the configuration for registering and running GitLab Runner in Kubernetes, which allows for the execution of CI/CD pipelines.
*   **core-modules/postgres-operator/**: Manages the deployment and lifecycle of PostgreSQL clusters using the Zalando operator.
*   **core-modules/elk3/**: Contains configuration files for deploying the ELK stack (Elasticsearch, Logstash, Kibana) for collecting, storing, and analyzing logs.
*   **core-modules/GlusterFS/**: Provides the setup of the GlusterFS distributed file system to provide persistent volumes with ReadWriteMany (RWX) access.
*   **core-modules/gpu/**: Manages support for GPU accelerators in Kubernetes, including the installation of NVIDIA device plugins.
*   **core-modules/jupyter/**: Contains the configuration for deploying JupyterHub, a multi-user platform for running interactive notebooks.
*   **core-modules/kafka/**: Responsible for deploying an Apache Kafka cluster using the Strimzi operator.
*   **core-modules/kafka-ui/**: Manages the deployment of Kafka UI, a web interface for managing and monitoring Kafka clusters.
    *   **Version:** `v0.7.2` (image `provectuslabs/kafka-ui:v0.7.2`)
    *   **Access:** Accessible via Ingress at `kafka-ui.dmz.home` using the `nginx` Ingress controller and a TLS certificate (`kafka-ui-tls`).
    *   **Pod Placement:** Configured to run on the `k2w-7` node using `nodeSelector`.
    *   **Replicas:** Deployed in a single instance (`replicaCount: 1`).
    *   **Kafka Connection:** Connects to the `k3` Kafka cluster at `k3-kafka-bootstrap.kafka:9093` using `SASL_SSL` and the `SCRAM-SHA-512` authentication mechanism with the user `user-streamforge`.
*   **core-modules/keycloak/**: Contains the configuration for deploying Keycloak, an identity and access management server.
*   **core-modules/kubernetes/**: Contains basic configuration files for setting up a Kubernetes cluster.
*   **core-modules/metallb/**: Provides a LoadBalancer implementation for bare-metal Kubernetes clusters.

## **Appendix G: Testing Procedure**

`dummy-service` and `debug_producer.py` are used to test the system's functionality and the end-to-end flow of commands and events through Kafka. These tools are particularly effective in a standardized `devcontainer` development environment.

**1. `dummy-service`: Test Microservice for Simulation**

`dummy-service` is a StreamForge test microservice designed to simulate the behavior of other services, test Kafka connectivity, and debug. It can receive commands from `queue-control`, send events to `queue-events`, simulate loading and errors, and publish Prometheus metrics.

*   **Launch:** Run `dummy-service` in Kubernetes as a `Job` or `Pod`, passing it the necessary environment variables. For local testing in a `devcontainer`, use:
    ```bash
    python3.11 -m app.main --debug --simulate-loading
    ```
    (without `--exit-after` so that the service runs continuously for interactive testing).
*   **More details:** See `services/dummy-service/README.md`.

**2. `debug_producer.py`: Tool for Sending Commands and Checking Responses**

`debug_producer.py` is a CLI tool for sending test commands (`ping`, `stop`) to the `queue-control` Kafka topic and waiting for responses (`pong`) from `queue-events`. It is used for debugging and testing microservices that interact via Kafka.

*   **Kafka Connectivity Testing (ping/pong):**
    Send a `ping` command and wait for a `pong` to check the basic connectivity and health of the target microservice.
    ```bash
    python3.11 services/dummy-service/debug_producer.py \
      --queue-id <your-queue-id> \
      --command ping \
      --expect-pong
    ```
    `debug_producer.py` will wait for a `pong` response from `dummy-service` (or another service that handles `ping`) and will output the round-trip time (RTT). This confirms that `dummy-service` received the command, processed it, and sent a response event to Kafka.

*   **Testing the Stop Command (stop):**
    Send a `stop` signal to the target service, which should terminate gracefully.
    ```bash
    python3.11 services/dummy-service/debug_producer.py \
      --queue-id <your-queue-id> \
      --command stop
    ```

*   **Testing Load Simulation and Status Tracking:**
    Run `dummy-service` with the `--simulate-loading` flag. Use `debug_producer.py` (or another consumer) to track the `loading` events that `dummy-service` sends to `queue-events`.

*   **Testing Failure Simulation:**
    Run `dummy-service` with the `--fail-after N` flag. Observe the `dummy-service` logs and events in `queue-events` to ensure that the service correctly sends an `error` event before terminating.

*   **Testing Prometheus Metrics:**
    Run `dummy-service` and use `curl localhost:8000/metrics` to check the exported metrics. Send commands with `debug_producer.py` and observe the metrics update.

*   **More details:** See `services/dummy-service/debug_producer.md`.

**3. Using `devcontainer` for Testing:**

The `devcontainer` environment provides a standardized and isolated environment that mimics a production environment (with access to Kubernetes, Kafka, etc.). This makes the tests performed in the `devcontainer` particularly valuable, as they are as close as possible to real deployment conditions. It is recommended to perform all the tests described above in this environment.

## **Appendix H: Kafka Resource Management**

The `cred-kafka-yaml/` directory contains Kubernetes manifests for declarative management of Kafka resources using the Strimzi operator. These manifests include:

*   **Topic Definitions:** Creation of control topics such as `queue-control` and `queue-events`.
*   **Users and Permissions:** Creation of Kafka users (e.g., `user-streamforge`) and configuration of their access rights (ACLs).
*   **Secrets:** Storage of credentials for accessing Kafka.

### **Appendix I: Debugging Environment in Kubernetes**

The following environments are provided in the project for debugging and interacting with the Kubernetes cluster:

*   **JupyterHub:** Allows you to run interactive Jupyter Notebook sessions directly in the cluster, providing analysts and developers with a ready-made environment for interacting with the Kubernetes API and data.

    **Key Configuration Features:**
    *   **Culling Inactive Servers:** Automatic termination of inactive Jupyter servers is enabled. Administrator servers are terminated after 7200 seconds (2 hours) of inactivity, with a check every 600 seconds (10 minutes). User servers are not terminated automatically.
    *   **Authentication:** Simple "dummy" authentication is used, which simplifies access in a test environment.
    *   **Hub Database:** `sqlite-memory` is used for the JupyterHub database, but it is persistently mounted from the host (`/data/home/jovyan/hub-db`) to preserve state.
    *   **Pod Placement:** Both the Hub and user servers (`singleuser` pods) are configured to run on a specific node (`k2w-8`) using `nodeSelector`.
    *   **Access:** Access to JupyterHub is via Ingress at `jupyterhub.dmz.home` using the `Traefik` Ingress controller and a TLS certificate (`jupyterhub-tls`).
    *   **User Server Images:** A custom image `registry.dmz.home/streamforge/core-modules/jupyter-python311:v0.0.2` is used, which includes `kubectl`, `helm`, and other necessary tools.
    *   **User Server Resources:** The guaranteed amount of memory for each user server is `1G`.
    *   **User Data Storage:** Persistent volumes mounted from the host are used for user data and projects:
        *   `/home/` (GlusterFS `gf-home`)
        *   `/data/project` (GlusterFS `gf-projects`)
        *   `/data/venv` (GlusterFS `gf-venv`)
    *   **User Pod Security:** User pods are run with `UID: 1001` and `FSGID: 100`.
    *   **Docker Registry Integration:** The `regcred` secret is used for authentication when downloading images.

*   **Dev Container (VS Code):**
    Is a Docker container that serves as a full-fledged development environment integrated with VS Code. It provides a standardized and isolated environment for all developers, eliminating "it works on my machine" problems.

    **Key Features:**
    *   **Base Image:** Ubuntu 22.04 LTS.
    *   **Pre-installed Tools:** `kubectl`, Helm, `gitlab-runner`, `git`, `curl`, `ssh`, and other standard utilities.
    *   **Kubernetes Access Configuration:** Automatically configures environment variables for `kubectl`, allowing interaction with the Kubernetes cluster.
    *   **User and SSH Management:** Creates a separate user and configures SSH access.
    *   **Certificate Management:** Installs CA certificates to trust internal services with TLS.

    **How to Use:**
    1.  Install Docker Desktop (or Docker Engine) and the "Dev Containers" extension for VS Code.
    2.  Open the StreamForge project in VS Code and select "Reopen in Container" (or "Open Folder in Container").
    3.  VS Code will build a Docker image based on `platform/devcontainer/Dockerfile` and launch the container, providing a ready-made development environment.

*   **Dev Container (General):** Is a Docker image with a wide range of development and debugging tools, including `kubectl`, `helm`, `kafkacat`, and `python`. This image can be used to launch temporary pods in Kubernetes that serve as a full-fledged interactive environment for debugging microservices.
