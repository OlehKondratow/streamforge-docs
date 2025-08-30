+++
title = "Graph Builder"
weight = 62
[params]
  menuPre = '<i class="fa-fw fas fa-share-alt"></i> '
+++

# `graph-build`

A microservice in the **StreamForge** ecosystem designed for building graph structures from prepared data and storing them in ArangoDB.

---

## 1. Purpose

`graph-build` performs the following tasks:

1. **Consumes** a designated Kafka topic containing prepared graph data.
2. **Processes** incoming messages to extract nodes and edges.
3. **Builds** graph structures and **stores** them in the corresponding ArangoDB collections.

This service is a stateless worker intended to run as a **Kubernetes Job**.
All configuration is provided via environment variables.

---

## 2. Environment Variables

The service is fully configured through environment variables.

| Variable                    | Description                                                       | Example                                   |
| --------------------------- | ----------------------------------------------------------------- | ----------------------------------------- |
| **`QUEUE_ID`**              | Unique workflow identifier.                                       | `wf-graph-build-20240801-a1b2c3`          |
| **`SYMBOL`**                | Symbol or data identifier.                                        | `GRAPH_STRUCTURE`                         |
| **`TYPE`**                  | Type of data being processed.                                     | `graph_data`                              |
| **`KAFKA_TOPIC`**           | Kafka topic name to consume prepared data from.                   | `wf-graph-build-20240801-a1b2c3-prepared` |
| **`GRAPH_COLLECTION_NAME`** | ArangoDB collection name where graph data is stored.              | `market_graph_2024_08_01`                 |
| **`TELEMETRY_PRODUCER_ID`** | Unique ID of this instance for telemetry reporting.               | `graph-build__a1b2c3`                     |
| `KAFKA_BOOTSTRAP_SERVERS`   | Kafka broker addresses.                                           | `kafka-bootstrap.kafka:9093`              |
| `KAFKA_USER_CONSUMER`       | Kafka username for consumer authentication.                       | `user-consumer-tls`                       |
| `KAFKA_PASSWORD_CONSUMER`   | Kafka password for consumer authentication (provided via Secret). | `your_kafka_password`                     |
| `CA_PATH`                   | Path to the CA certificate for Kafka TLS connection.              | `/certs/ca.crt`                           |
| `QUEUE_CONTROL_TOPIC`       | Kafka topic for receiving control commands (e.g., `stop`).        | `queue-control`                           |
| `QUEUE_EVENTS_TOPIC`        | Kafka topic for sending telemetry events.                         | `queue-events`                            |
| `ARANGO_URL`                | ArangoDB connection URL.                                          | `http://arango-cluster.db:8529`           |
| `ARANGO_DB`                 | ArangoDB database name.                                           | `streamforge`                             |
| `ARANGO_USER`               | ArangoDB username.                                                | `root`                                    |
| `ARANGO_PASSWORD`           | ArangoDB password (provided via Secret).                          | `your_arango_password`                    |

---

## 3. Input Data (Kafka)

The service consumes JSON messages from the `KAFKA_TOPIC` containing prepared data for graph construction.
Messages may contain the `_key` field for **idempotent UPSERT** operations in ArangoDB.
If `_key` is not provided, ArangoDB will auto-generate it.

**Example message:**

```json
{
  "_key": "node_id_1",
  "type": "node",
  "attributes": {"feature1": 1.0, "feature2": "value"}
}
```

---

## 4. Telemetry (Topic: `queue-events`)

The service sends status events to the `queue-events` topic.
This allows the `queue-manager` to track the progress of the task.

**Example `loading` event:**

```json
{
  "queue_id": "wf-graph-build-20240801-a1b2c3",
  "symbol": "GRAPH_STRUCTURE",
  "type": "graph_data",
  "status": "loading",
  "message": "Constructed 15000 nodes and edges",
  "records_written": 15000,
  "finished": false,
  "producer": "graph-build__a1b2c3",
  "timestamp": 1722445567.890
}
```

**Possible statuses:** `started`, `loading`, `interrupted`, `error`, `finished`.

---

## 5. Control (Topic: `queue-control`)

The service listens to the `queue-control` topic and responds to commands addressed to its `queue_id`.

**Example `stop` command:**

```json
{
  "command": "stop",
  "queue_id": "wf-graph-build-20240801-a1b2c3"
}
```

Upon receiving this command, the service performs a graceful shutdown.
