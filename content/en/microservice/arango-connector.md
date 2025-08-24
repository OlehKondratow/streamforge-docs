+++
title = "Arango Connector"
type = "chapter"
weight = 1
+++

# Arango-connector

A consumer microservice in the **StreamForge** ecosystem, designed for universal data persistence into ArangoDB.

## Purpose

`arango-connector` performs the following tasks:

1. **Listens** to a specified Kafka topic where data is being published.
2. **Processes** these messages.
3. **Stores** them into the corresponding collection in the ArangoDB database.

This service is a stateless worker and is intended to be run as a **Kubernetes Job**.
It receives all necessary configuration via environment variables.

## \[Configuration] Environment Variables

The service is fully configurable via environment variables.

| Variable                    | Description                                                | Example                               |
| --------------------------- | ---------------------------------------------------------- | ------------------------------------- |
| **`QUEUE_ID`**              | Unique identifier of the entire workflow.                  | `wf-generic-data-20240801-a1b2c3`     |
| **`SYMBOL`**                | Data symbol or identifier.                                 | `GENERIC_DATA`                        |
| **`TYPE`**                  | Type of data being processed.                              | `raw_json`                            |
| **`KAFKA_TOPIC`**           | Name of the Kafka topic to consume from.                   | `wf-generic-data-20240801-a1b2c3-raw` |
| **`COLLECTION_NAME`**       | Name of the ArangoDB collection where data will be stored. | `generic_data_2024_08_01`             |
| **`TELEMETRY_PRODUCER_ID`** | Unique ID of this instance for telemetry purposes.         | `arango-connector__a1b2c3`            |
| `KAFKA_BOOTSTRAP_SERVERS`   | Kafka broker addresses.                                    | `kafka-bootstrap.kafka:9093`          |
| `KAFKA_USER_CONSUMER`       | Kafka username for authentication (consumer).              | `user-consumer-tls`                   |
| `KAFKA_PASSWORD_CONSUMER`   | Password for the Kafka user (passed via Secret).           | `your_kafka_password`                 |
| `CA_PATH`                   | Path to the CA certificate for Kafka TLS connection.       | `/certs/ca.crt`                       |
| `QUEUE_CONTROL_TOPIC`       | Kafka topic for receiving control commands (e.g., `stop`). | `queue-control`                       |
| `QUEUE_EVENTS_TOPIC`        | Kafka topic for sending telemetry events.                  | `queue-events`                        |
| `ARANGO_URL`                | Connection URL for ArangoDB.                               | `http://arango-cluster.db:8529`       |
| `ARANGO_DB`                 | Database name in ArangoDB.                                 | `streamforge`                         |
| `ARANGO_USER`               | ArangoDB username.                                         | `root`                                |
| `ARANGO_PASSWORD`           | ArangoDB password (passed via Secret).                     | `your_arango_password`                |

---

## Input Data (Kafka)

The service expects to receive JSON messages from the `KAFKA_TOPIC`.
Messages may contain the `_key` field for idempotent insert/update operations in ArangoDB (`UPSERT`).
If `_key` is missing, ArangoDB will generate it automatically.

Example:

```json
{
  "_key": "unique_document_id",
  "field1": "value1",
  "field2": "value2",
  "timestamp": 1722500000.123
}
```

---

## Telemetry (Topic: `queue-events`)

The service sends status events to the `queue-events` topic, allowing `queue-manager` to track the job’s progress.

**Example of a `loading` event:**

```json
{
  "queue_id": "wf-generic-data-20240801-a1b2c3",
  "symbol": "GENERIC_DATA",
  "type": "raw_json",
  "status": "loading",
  "message": "Saved 15000 records",
  "records_written": 15000,
  "finished": false,
  "producer": "arango-connector__a1b2c3",
  "timestamp": 1722445567.890
}
```

**Possible statuses:** `started`, `loading`, `interrupted`, `error`, `finished`.

---

## Control (Topic: `queue-control`)

The service listens to the `queue-control` topic and reacts to commands addressed to its `queue_id`.

**Example: `stop` command**

```json
{
  "command": "stop",
  "queue_id": "wf-generic-data-20240801-a1b2c3"
}
```

Upon receiving this command, the service gracefully shuts down:
it stops the Kafka consumer, closes the database connection, and sends a final telemetry event with the status `interrupted`.
