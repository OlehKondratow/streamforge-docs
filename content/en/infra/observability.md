+++
title = "Observability"
type = "Centralized Logging Architecture in GKE Autopilot"
weight = 3
[params]
  menuPre = '<i class="fa-fw fas fa-chart-line "></i> '
+++

This repository contains a complete set of artifacts for deploying a production-ready logging system for GKE Autopilot clusters using Google Cloud Logging and Cloud Monitoring.

## 1. Architecture Overview

GKE Autopilot is automatically integrated with Cloud Logging. All standard output (`stdout`) and standard error (`stderr`) from your containers are collected and sent to Cloud Logging without the need to install agents, DaemonSets, or use `hostPath`.

Our architecture builds on top of this by configuring Cloud Logging to efficiently store, analyze, and route logs:

- **Structured Logs (JSON):** Applications write logs in JSON format to `stdout`/`stderr`. Cloud Logging automatically parses them, making fields available for filtering and analysis.
- **Log Buckets:** We create two custom buckets to separate logs by retention period: one for operational logs (30 days) and one for long-term storage (365 days).
- **Log Views:** To segregate access, we use Log Views, which provide teams with access only to the logs of their services.
- **Log Sinks:** For long-term archiving, analytics, and integrations, we configure exports (sinks) to BigQuery, Cloud Storage, and Pub/Sub.
- **Log Exclusions:** To optimize costs, we exclude "noisy" and low-priority logs (e.g., health checks) from processing.
- **Logs-based Metrics & Alerts:** We create metrics based on logs (e.g., number of 5xx errors) and configure alerts for proactive monitoring.

## 2. Components

- **Terraform (`infra/live/dev/logging/`):** Manages all GCP resources (Log Buckets, Sinks, IAM, metrics, alerts).
- **Application Samples (`samples/logging/`):** Demonstrate how to write structured logs in Python, Go, and Node.js.
- **Kubernetes Manifests (`k8s/smoke/`):** Used to deploy a test application to the cluster to verify the logging system.

## 3. Step-by-Step Launch

### Step 1: Configure Terraform

1.  Navigate to the Terraform code directory:
    ```bash
    cd infra/live/dev/logging/
    ```

2.  Create a `terraform.tfvars` file from the example:
    ```bash
    cp terraform.tfvars.example terraform.tfvars
    ```

3.  Fill in `terraform.tfvars` with your values (`project_id`, `region`, `cluster_name`, etc.).

4.  Authenticate with GCP:
    ```bash
    gcloud auth application-default login
    gcloud config set project <MY_GCP_PROJECT_ID>
    ```

5.  Initialize and apply Terraform:
    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

### Step 2: Deploy the Test Application

1.  Make sure your `kubectl` is configured to work with your GKE Autopilot cluster.
    ```bash
    gcloud container clusters get-credentials <MY_GKE_AUTOPILOT_CLUSTER> --region <MY_REGION>
    ```

2.  Deploy the test manifests:
    ```bash
    kubectl apply -f ../../../../k8s/smoke/
    ```

3.  Generate traffic to create logs. Port-forward and call the endpoints:
    ```bash
    # In one terminal
    kubectl port-forward -n logging-smoke-test svc/sample-logger-py 8080:80

    # In another terminal
    # Successful request
    curl http://localhost:8080/work
    # Request with an error
    curl http://localhost:8080/work?error=true
    # Health check (will be excluded from logs)
    curl http://localhost:8080/healthz
    ```

### Step 3: Check the Logs

Use the links and commands from the `terraform apply` output or go to the **Logs Explorer**.

**Example filters in Logs Explorer:**

-   **Show all logs for the test service:**
    ```
    resource.type="k8s_container"
    resource.labels.cluster_name="<MY_GKE_AUTOPILOT_CLUSTER>"
    resource.labels.namespace_name="logging-smoke-test"
    labels.k8s-pod/app="sample-logger-py"
    ```
-   **Show only errors (severity ERROR):**
    ```
    resource.type="k8s_container"
    resource.labels.namespace_name="logging-smoke-test"
    severity="ERROR"
    ```
-   **Find a log by trace ID:**
    ```
    resource.type="k8s_container"
    jsonPayload.trace="00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
    ```

### Step 4: Check Metrics and Alerts

1.  **Generate 5xx errors:** Run `curl http://localhost:8080/work?error=true` several times.
2.  **Check the metric:** Go to **Metrics Explorer** and find the `logging.googleapis.com/user/http_5xx_count` metric.
3.  **Check the alert:** After a few minutes (according to the settings in `monitoring_alerts.tf`), the alert should trigger and a notification should be sent to the specified channel.

## 4. Cost Optimization

-   **Exclusions:** The most effective way to reduce costs is to exclude unnecessary logs. We have already configured exclusions for health checks. Add new rules in `logging_exclusions.tf` for "chatty" services or DEBUG level logs.
-   **Retention Periods:** Use buckets with different retention periods. Keep operational logs in `default-app-logs` (30 days), and less important or archival logs in `long-app-logs` (365 days), or export them to GCS/BigQuery, which is cheaper for long-term storage.
-   **Sampling:** For DEBUG level logs in a dev environment, you can configure sampling at the application level or through more complex filters in `logging_exclusions.tf`.

## 5. Security

-   **CMEK (Customer-Managed Encryption Keys):** If you specified a `kms_key` in `terraform.tfvars`, all Log Buckets will be encrypted with your key, giving you full control over the data encryption keys.
-   **Access via Log Views:** We do not grant direct access to logs. Instead, we create `Log Views` for each team and grant the `roles/logging.viewAccessor` IAM role only to the specific View. This ensures that teams only see the logs of their applications.