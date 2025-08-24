+++
title = "Gnn Trainer"
type = "chapter"
weight = 1
+++

# `gnn-trainer`

A microservice in the **StreamForge** ecosystem designed for training **Graph Neural Network (GNN)** models based on market data.

---

## 1. Purpose

`gnn-trainer` performs the following tasks:

1. **Collects** market data (K-lines, order book, funding rates) from the Binance API.
2. **Generates** node features and edge weights to construct a dynamic market graph.
3. **Builds** a PyTorch Geometric (PyG) graph object.
4. **Trains** a GNN model to predict short-term price movements.
5. **Saves** the trained model to MinIO.

This service is a stateless worker and is intended to run as a **Kubernetes Job**.
All required configuration is provided via environment variables.

---

## 2. Environment Variables

The service is fully configured through environment variables.

| Variable                    | Description                                                   | Example                         |
| --------------------------- | ------------------------------------------------------------- | ------------------------------- |
| **`QUEUE_ID`**              | Unique identifier for the workflow.                           | `wf-gnn-train-20240801-a1b2c3`  |
| **`SYMBOL`**                | Symbol or data identifier (used in telemetry).                | `MARKET_GRAPH`                  |
| **`TYPE`**                  | Data type being processed (used in telemetry).                | `gnn_model_training`            |
| **`TELEMETRY_PRODUCER_ID`** | Unique ID of this instance for telemetry reporting.           | `gnn-trainer__a1b2c3`           |
| `BINANCE_API_KEY`           | API key for Binance API access.                               | `your_binance_api_key`          |
| `BINANCE_API_SECRET`        | API secret for Binance API access.                            | `your_binance_api_secret`       |
| `KAFKA_BOOTSTRAP_SERVERS`   | Kafka broker addresses (for telemetry and possible triggers). | `kafka-bootstrap.kafka:9093`    |
| `KAFKA_USER`                | Username for Kafka authentication.                            | `user-producer-tls`             |
| `KAFKA_PASSWORD`            | Password for Kafka authentication.                            | `your_kafka_password`           |
| `CA_PATH`                   | Path to CA certificate for Kafka TLS connection.              | `/certs/ca.crt`                 |
| `QUEUE_CONTROL_TOPIC`       | Kafka topic for receiving control commands (e.g., `stop`).    | `queue-control`                 |
| `QUEUE_EVENTS_TOPIC`        | Kafka topic for sending telemetry events.                     | `queue-events`                  |
| `ARANGO_URL`                | URL for connecting to ArangoDB (to load graph data).          | `http://arango-cluster.db:8529` |
| `ARANGO_DB`                 | ArangoDB database name.                                       | `streamforge`                   |
| `ARANGO_USER`               | ArangoDB username.                                            | `root`                          |
| `ARANGO_PASSWORD`           | ArangoDB password.                                            | `your_arango_password`          |
| `GRAPH_COLLECTION_NAME`     | ArangoDB collection name for prepared graph data.             | `prepared_graph_data`           |
| `MINIO_ENDPOINT`            | MinIO endpoint for saving models.                             | `minio.minio:9000`              |
| `MINIO_ACCESS_KEY`          | MinIO access key.                                             | `minio_access_key`              |
| `MINIO_SECRET_KEY`          | MinIO secret key.                                             | `minio_secret_key`              |
| `MINIO_BUCKET_NAME`         | MinIO bucket name for model storage.                          | `gnn-models`                    |
| `MODEL_NAME`                | Name for the saved model.                                     | `market_gnn_v1`                 |
| `EPOCHS`                    | Number of training epochs.                                    | `100`                           |
| `LEARNING_RATE`             | Learning rate.                                                | `0.001`                         |

---

## 3. Telemetry (Topic: `queue-events`)

The service sends status events to the `queue-events` topic.
This allows `queue-manager` to track the progress of the task.

**Example `loading` event:**

```json
{
  "queue_id": "wf-gnn-train-20240801-a1b2c3",
  "symbol": "MARKET_GRAPH",
  "type": "gnn_model_training",
  "status": "loading",
  "message": "Epoch 50 completed, loss: 0.0123",
  "finished": false,
  "producer": "gnn-trainer__a1b2c3",
  "timestamp": 1722445567.890,
  "extra": {"epoch": 50, "loss": 0.0123}
}
```

**Possible statuses:** `started`, `loading`, `interrupted`, `error`, `finished`.

---

## 4. Control (Topic: `queue-control`)

The service listens to the `queue-control` topic and responds to commands addressed to its `queue_id`.

**Example `stop` command:**

```json
{
  "command": "stop",
  "queue_id": "wf-gnn-train-20240801-a1b2c3"
}
```

Upon receiving this command, the service performs a graceful shutdown.
