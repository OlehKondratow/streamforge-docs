+++
title = "Arango Trades"
weight = 1
+++

A consumer microservice in the **StreamForge** ecosystem, designed for persisting trade data in ArangoDB.

## Purpose

`arango-trades` performs the following tasks:

1. **Listens** to a specific Kafka topic that receives trade data.
2. **Processes** these messages.
3. **Stores** them in the corresponding collection in the ArangoDB database.

This service is a stateless worker and is intended to run as a **Kubernetes Job**.
It receives all necessary configuration through environment variables.

## Configuration — Environment Variables

The service is fully configurable via environment variables.

| Variable                    | Description                                                | Example                          |
| --------------------------- | ---------------------------------------------------------- | -------------------------------- |
| **`QUEUE_ID`**              | Unique identifier of the entire workflow.                  | `wf-trades-20240801-a1b2c3`      |
| **`SYMBOL`**                | Trading pair.                                              | `BTCUSDT`                        |
| **`TYPE`**                  | Type of data being processed.                              | `trade_data`                     |
| **`KAFKA_TOPIC`**           | Name of the Kafka topic to consume from.                   | `wf-trades-20240801-a1b2c3-data` |
| **`COLLECTION_NAME`**       | Name of the ArangoDB collection for storing data.          | `btcusdt_trades_2024_08_01`      |
| **`TELEMETRY_PRODUCER_ID`** | Unique ID of this instance for telemetry purposes.         | `arango-trades__a1b2c3`          |
| `KAFKA_BOOTSTRAP_SERVERS`   | Kafka broker addresses.                                    | `kafka-bootstrap.kafka:9093`     |
| `KAFKA_USER_CONSUMER`       | Kafka username for authentication (consumer).              | `user-consumer-tls`              |
| `KAFKA_PASSWORD_CONSUMER`   | Password for the Kafka user (passed via Secret).           | `your_kafka_password`            |
| `CA_PATH`                   | Path to the CA certificate for Kafka TLS connection.       | `/certs/ca.crt`                  |
| `QUEUE_CONTROL_TOPIC`       | Kafka topic for receiving control commands (e.g., `stop`). | `queue-control`                  |
| `QUEUE_EVENTS_TOPIC`        | Kafka topic for sending telemetry events.                  | `queue-events`                   |
| `ARANGO_URL`                | Connection URL for ArangoDB.                               | `http://arango-cluster.db:8529`  |
| `ARANGO_DB`                 | Database name in ArangoDB.                                 | `streamforge`                    |
| `ARANGO_USER`               | ArangoDB username.                                         | `root`                           |
| `ARANGO_PASSWORD`           | ArangoDB password (passed via Secret).                     | `your_arango_password`           |

---

## Input Data (Kafka)

The service expects JSON messages from the `KAFKA_TOPIC` representing trade data.
It is assumed that messages may contain a `_key` field for idempotent insert/update operations in ArangoDB (`UPSERT`).
If `_key` is missing, ArangoDB will generate it automatically.

Example:

```json
{
  "_key": "trade_id_12345",
  "trade_id": 12345,
  "symbol": "BTCUSDT",
  "price": "20000.50",
  "quantity": "0.1",
  "timestamp": 1672531200000,
  "is_buyer_maker": true
}
```

---

## Telemetry (Topic: `queue-events`)

The service sends status events to the `queue-events` topic, enabling the `queue-manager` to track job progress.

**Example of a `loading` event:**

```json
{
  "queue_id": "wf-trades-20240801-a1b2c3",
  "symbol": "BTCUSDT",
  "type": "trade_data",
  "status": "loading",
  "message": "Saved 15000 trade records",
  "records_written": 15000,
  "finished": false,
  "producer": "arango-trades__a1b2c3",
  "timestamp": 1722445567.890
}
```

**Possible statuses:** `started`, `loading`, `interrupted`, `error`, `finished`.

---

## Control (Topic: `queue-control`)

The service listens to the `queue-control` topic and responds to commands addressed to its `queue_id`.

**Example: `stop` command**

```json
{
  "command": "stop",
  "queue_id": "wf-trades-20240801-a1b2c3"
}
```

Upon receiving this command, the service gracefully shuts down:
it stops the consumer, closes the database connection, and sends a final telemetry event with the status `interrupted`.