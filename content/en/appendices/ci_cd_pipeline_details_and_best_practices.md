+++
title = "CI/CD Pipeline Details and Best Practices"
weight = 2
+++

This document provides a comprehensive overview of the CI/CD pipelines implemented in this project for both GitLab and GitHub. It details the structure, stages, and jobs, along with best practices for maintaining and extending the pipelines.

## Overview

The project utilizes a hybrid CI/CD approach, leveraging both GitLab CI/CD and GitHub Actions to automate testing, building, and deployment of services.

-   **GitLab CI/CD**: Primarily used for the main deployment pipeline, handling microservice builds, tests, and Kubernetes deployments within the project's ecosystem. It is organized with a main `.gitlab-ci.yml` that includes templates and service-specific configurations.
-   **GitHub Actions**: Used for CI checks on pushes and pull requests, running tests, building container images, and generating quality metric badges. This provides rapid feedback for developers working on GitHub.

---

## GitLab CI/CD Pipeline

The GitLab pipeline is the core of the project's integration and deployment strategy. It is defined in the root `.gitlab-ci.yml` file and is composed of several stages that orchestrate the entire workflow.

### Main Configuration (`.gitlab-ci.yml`)

The main configuration file acts as an orchestrator, defining the global stages and including CI configurations for each microservice and shared templates.

**Stages:**

1.  `setup`: Initial setup tasks.
2.  `test`: Running unit tests for services.
3.  `build`: Building container images for services.
4.  `integration-test`: Running integration tests.
5.  `deploy`: Deploying services to Kubernetes.
6.  `badges`: Updating status badges based on job outcomes.

The file uses the `include:local` keyword to pull in CI configurations from each service directory (e.g., `services/dummy-service/.gitlab-ci.yml`) and shared templates from `.gitlab/ci-templates/`.

### Shared Templates

#### 1. Python Service Template (`.gitlab/ci-templates/Python-Service.gitlab-ci.yml`)

This template provides a standardized set of CI/CD jobs for Python-based microservices. It uses hidden jobs (e.g., `.build_python_service`) that can be extended and customized by each service's specific `.gitlab-ci.yml` file.

**Key Jobs:**

-   **.test\_python\_service**:
    -   **Stage**: `test`
    -   **Description**: Installs dependencies from `requirements.txt` and runs unit tests using `pytest`. It generates a JUnit XML report for integration with GitLab's UI.
    -   **Rules**: Runs automatically on changes to a service's path on the `main` branch, or can be triggered manually.

-   **.build\_python\_service**:
    -   **Stage**: `build`
    -   **Description**: Builds a Docker image for the service using Kaniko. It reads the service version from a `VERSION` file, tags the image, and pushes it to the GitLab Container Registry.
    -   **Rules**: Runs on changes to a service's path on the `main` branch, or manually.

-   **.integration\_test\_python\_service**:
    -   **Stage**: `integration-test`
    -   **Description**: Runs integration tests against a live instance of the service started in the CI job.
    -   **Rules**: Manual or on changes to a service's path.

-   **.update\_badge\_\***:
    -   **Stage**: `badges`
    -   **Description**: A collection of jobs that generate and commit status badges (for test, build, deploy, etc.) to the repository after the corresponding job completes. They create a new branch and a merge request for the badge updates.

#### 2. Kubernetes Deployment Template (`.gitlab/ci-templates/Kubernetes-Deploy.gitlab-ci.yml`)

This template defines a standardized way to deploy services to a Kubernetes cluster.

-   **.deploy\_kubernetes\_service**:
    -   **Stage**: `deploy`
    -   **Description**: Uses `kubectl apply` to deploy a service using a specified Kubernetes manifest file.
    -   **Rules**: This is a manual job, providing control over deployments to production or staging environments.

---

## GitHub Actions Workflows

GitHub Actions are used for continuous integration to provide quick feedback on code changes pushed to the repository or in pull requests.

### 1. Build Base Image (`.github/workflows/build-base.yml`)

-   **Trigger**: Pushes to `platform/**` or manual dispatch.
-   **Description**: This workflow builds the common base Docker image used by many of the Python services. It reads the version from `platform/VERSION`, builds the image, and pushes it to the GitHub Container Registry (GHCR).

### 2. Dummy Service CI (`.github/workflows/dummy-service-ci.yml`)

This file is a comprehensive CI pipeline for the `dummy-service` and serves as a template for other services.

-   **Trigger**: Pushes or pull requests to `services/dummy-service/**` or manual dispatch.
-   **Jobs**:
    -   `tests`:
        -   Runs inside the custom base container image.
        -   Installs dependencies and runs `pytest`.
        -   Generates coverage and test reports as artifacts.
        -   Can optionally run integration tests if triggered manually with the `enable_integration` input.
    -   `build`:
        -   Builds and pushes the service's Docker image to GHCR.
        -   It cleverly tags the image with the version, branch name, and commit SHA. The `latest` tag is applied only on the `main` branch.
    -   `badges`:
        -   Runs after `tests` and `build`.
        -   Downloads the test artifacts.
        -   Generates a variety of SVG badges for test results, coverage, pass rate, and build status.
        -   Commits the generated badges directly to the `badges/github` directory on the `main` branch.

---

## Best Practices

### Adding a New Python Service

To integrate a new Python service into the CI/CD system:

1.  **Create Service Directory**: Add a new directory under `services/`.
2.  **Add Standard Files**: Your service should include:
    -   `app/main.py`: Your application entry point.
    -   `Dockerfile`: To containerize your service.
    -   `requirements.txt`: Python dependencies.
    -   `VERSION`: A file containing the semantic version of the service (e.g., `0.1.0`).
    -   `tests/`: A directory for unit and integration tests.
3.  **Create GitLab CI file**: Add a `.gitlab-ci.yml` file in your service directory. This file should `extend` the jobs defined in the `Python-Service.gitlab-ci.yml` template. Example for a service named `my-new-service`:

    ```yaml
    variables:
      SERVICE_NAME: "my-new-service"
      SERVICE_PATH: "services/my-new-service"

    test-my-new-service:
      extends: .test_python_service

    build-my-new-service:
      extends: .build_python_service

    deploy-my-new-service:
      extends: .deploy_kubernetes_service
      # Add environment specific variables if needed
    ```
4.  **Update Root `.gitlab-ci.yml`**: Include your new service's CI file in the root `.gitlab-ci.yml`.

    ```yaml
    include:
      # ... other services
      - local: 'services/my-new-service/.gitlab-ci.yml'
    ```
5.  **(Optional) Add GitHub Actions**: For GitHub-based CI, you can copy and adapt the `dummy-service-ci.yml` workflow for your new service.

### Managing Secrets and Variables

-   **GitLab**: CI/CD variables should be stored in the project's **Settings > CI/CD > Variables**. This includes tokens like `GIT_PUSH_TOKEN` and credentials for services like Kafka or ArangoDB.
-   **GitHub**: Secrets should be stored in the repository's **Settings > Secrets and variables > Actions**. This includes `GHCR_TOKEN` for pushing images to the registry.

By following this structure, the project maintains a scalable and consistent CI/CD process across all its microservices.
