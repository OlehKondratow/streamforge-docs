+++
date = '2025-08-24T20:22:28+02:00'
draft = true
title = 'Architecture_and_Functioning'
weight = 2
+++
## Part II: Architecture and Functioning

### Chapter 2: High-Level Architecture

#### 2.1. Core Architectural Principles

The StreamForge architecture is engineered around several core principles to deliver a flexible, reliable, and scalable platform:

1.  **Decoupling through an Event-Driven Model:**
    At the heart of StreamForge is an event-driven model where Apache Kafka serves as the central message bus. This fundamentally decouples services from one another. `queue-manager` initiates a workflow (e.g., loading BTC data), and the corresponding microservices (like `loader-producer`) react to these events. This paradigm enables independent development, deployment, and scaling of each microservice, fostering system-wide resilience and agility.

2.  **Scalability:**
    The platform is designed for dynamic load adaptation. Stateless applications, such as `loader-*` and `arango-connector`, are deployed as ephemeral Kubernetes Jobs. This design allows for on-demand, parallel execution of tasks, providing inherent scalability. Future iterations will integrate **KEDA (Kubernetes Event-driven Autoscaling)** to enable proactive scaling of consumers based on Kafka topic backlogs, further optimizing resource utilization.

3.  **Observability:**
    A robust observability stack is integral to the architecture, providing deep insights into the distributed system:
    *   **Metrics:** Microservices export metrics to Prometheus, which are then visualized in Grafana. This includes both system-level indicators (CPU, memory) and business metrics (number of processed records, latencies).
    *   **Logging:** Centralized log collection is carried out using Fluent-bit, with subsequent analysis and visualization in Elasticsearch and Kibana.
    *   **Business-Level Telemetry:** A dedicated `queue-events` topic provides end-to-end business process tracing. It captures the complete lifecycle of every workflow, logging state transitions from initiation to completion or error, across all participating microservices.

#### 2.2. Data Flow in the System

The following diagram illustrates the data flow for a typical historical data ingestion workflow within the StreamForge ecosystem:

**Step-by-step process description:**
1.  **Workflow Initiation:** A user or automated process initiates a data processing workflow via a request to the `queue-manager` API.
2.  **State Registration:** `queue-manager` registers the new workflow in ArangoDB, assigning it a unique `queue_id` and an initial `pending` status.
3.  **Command Dispatch:** A `start` command, containing all necessary job parameters, is published by `queue-manager` to the `queue-control` topic in Apache Kafka.
4.  **Job Instantiation:** `queue-manager` generates the required Kubernetes Job manifests, which are then scheduled for execution, launching the necessary microservice pods (e.g., `loader-producer`, `arango-connector`).
5.  **Command Consumption:** The newly instantiated microservices consume the `start` command from the `queue-control` topic that corresponds to their assigned `queue_id`.
6.  **Data Ingestion:** The `loader-producer` service establishes a connection to the external data source (e.g., Binance API) and commences data retrieval.
7.  **Event Publication:** `loader-producer` serializes the ingested data into discrete messages and publishes them to a dedicated data topic within Kafka (e.g., `btc-klines-1m`).
8.  **Telemetry Reporting:** Throughout their lifecycle, all active services (`loader-producer`, `arango-connector`) publish status updates (e.g., `loading`, `completed`, `error`) to the `queue-events` topic, providing real-time progress visibility.
9.  **Data Consumption for Persistence:** The `arango-connector` service subscribes to the relevant data topic and consumes the event stream.
10. **Data Persistence:** `arango-connector` processes and persists the data into the designated collections within the ArangoDB database.
11. **Workflow Monitoring & Completion:** `queue-manager` continuously monitors the `queue-events` topic, updating the workflow's status in ArangoDB based on the received telemetry. This provides a complete, real-time audit trail of the process.

### Chapter 3: Apache Kafka as a Central Component

Apache Kafka is the central nervous system of the StreamForge architecture, delivering the key benefits of an event-driven paradigm:

*   **Decoupling and Asynchronicity:** Services operate with complete autonomy. Producers (e.g., `loader-producer`) publish events to Kafka without any awareness of or dependency on the consumers (e.g., `arango-connector`). This temporal decoupling allows components to be developed, deployed, and scaled independently, and enables the system to absorb data bursts without impacting downstream services.
*   **Resilience and Durability:** Kafka functions as a distributed, persistent log. If a consuming service experiences a failure, messages are safely retained in the topic. Upon recovery, the service can resume processing from its last known offset, guaranteeing at-least-once delivery and preventing data loss.
*   **Scalability and Extensibility:** The event-driven model allows for seamless horizontal scaling. New instances of a service can be added to a consumer group to increase processing throughput. Furthermore, the architecture is inherently extensible; new functionalities can be introduced by deploying new microservices that subscribe to existing event streams, without requiring any modification to the original data producers.

Orchestration and monitoring of StreamForge are organized around two service topics:

##### Topic `queue-control`
*   **Purpose:** The primary channel for transmitting commands from `queue-manager` to services.
*   **Initiator:** Exclusively `queue-manager`.
*   **Recipients:** All computational components (`loader-*`, `arango-connector`, and others).
*   **Example message:**
    ```json
    {
      "command": "start",
      "queue_id": "wf-btcusdt-api_candles_5m-20240801-a1b2c3",
      "target": "loader-producer",
      "symbol": "BTCUSDT",
      "type": "api_candles_5m",
      "time_range": "2024-08-01:2024-08-02",
      "kafka_topic": "wf-btcusdt-api_candles_5m-20240801-a1b2c3-data",
      "collection_name": "btcusdt_api_candles_5m_2024_08_01",
      "telemetry_id": "loader-producer__a1b2c3",
      "image": "registry.dmz.home/streamforge/loader-producer:v0.2.0",
      "timestamp": 1722500000.123
    }
    ```

##### Topic `queue-events`
*   **Purpose:** The reporting channel for task execution by all services.
*   **Initiator:** All computational components.
*   **Recipients:** `queue-manager`, which monitors the execution process to update statuses.
*   **Example message:**
    ```json
    {
      "queue_id": "wf-btcusdt-api_candles_5m-20240801-a1b2c3",
      "producer": "arango-connector__a1b2c3",
      "symbol": "BTCUSDT",
      "type": "api_candles_5m",
      "status": "loading",
      "message": "Saved 15000 records",
      "records_written": 15000,
      "finished": false,
      "timestamp": 1722500125.456
    }
    ```

### Chapter 4: Microservices

StreamForge is a complex system consisting of specialized microservices, each performing a unique and clearly defined function.

#### 4.1. `queue-manager`: The Orchestration Engine

`queue-manager` is the brain of the platform, responsible for the end-to-end orchestration of data processing workflows. Its main functions include:
*   **Workflow Management:** Manages the complete lifecycle of a workflow, from API request to final state.
*   **State Tracking:** Monitors workflow progress by consuming from the `queue-events` topic.
*   **Dynamic Job Instantiation:** Interfaces with the Kubernetes API to dynamically launch and manage the Jobs required for a given workflow.
*   **API & Reporting:** Exposes a RESTful API for initiating workflows and querying their status.

**Technologies:** Python, FastAPI (for API implementation), Pydantic, `python-kubernetes`, `aiokafka`, ArangoDB.

#### 4.2. Data Collection: `loader-*`: Data Ingestion Services

The `loader-*` family of microservices are specialized data ingestion agents. Each is responsible for connecting to an external source, fetching data, and publishing it as events to Apache Kafka:

*   **`loader-producer`:** A basic module designed for high-performance bulk data loading.
*   **`loader-api-*`:** Specialized modules for working with historical data via REST API.
*   **`loader-ws-*`:** Modules processing real-time streaming data via WebSocket connections.

Each module is configured via environment variables, interacts with the `queue-control` topic to receive commands, and sends status reports to the `queue-events` topic.

**Technologies:** Python, `aiohttp` (for REST), `websockets` (for WebSocket), `aiokafka`, `uvloop`, `orjson`.

#### 4.3. Data Storage: `arango-connector` — The Persistence Service

The `arango-connector` service functions as a highly efficient data sink, bridging the gap between the real-time event stream in Kafka and the persistent storage layer in ArangoDB:
*   **Data Extraction:** Consumption of messages from relevant Kafka topics.
*   **Storage Optimization:** Aggregation of data and its storage in ArangoDB with performance optimization in mind.
*   **Idempotent Writes:** Utilizes UPSERT operations to ensure data can be re-processed without creating duplicate records, a critical feature for fault-tolerant systems.
*   **Error Handling:** Logging of incorrect or corrupted data while maintaining service continuity.

**Technologies:** Python, `aioarango`, `aiokafka`.

#### 4.4. Analytical Layer: `graph-builder` & `gnn-trainer` — The Analytics and ML Core

This suite of services constitutes the analytical and machine learning core of the platform:

*   **`graph-builder`:** Transforms incoming data into graph structures suitable for subsequent analysis.
*   **`gnn-trainer`:** Trains Graph Neural Network (GNN) models based on the formed graphs.

**Technologies:** Python, `aioarango`, `PyTorch`, `PyTorch Geometric (PyG)`, `minio-py`.

#### 4.5. `dummy-service`: A Diagnostic and Testing Utility

`dummy-service` is developed as an auxiliary tool for testing and simulation. It is used to validate Kafka connectivity, simulate service behavior, and generate load for testing system performance and resilience.

**Technologies:** Python, FastAPI, `aiokafka`, `loguru`, `prometheus_client`.
