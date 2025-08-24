+++
title = "Loader Ws Orderbook"
type = "chapter"
weight = 1
+++

# loader-ws-orderbook

A microservice in the **StreamForge** ecosystem designed to load real-time order book data via WebSocket and publish it to Kafka.

## Purpose

`loader-ws-orderbook` performs the following tasks:

1. **Connects** to an external WebSocket API (e.g., Binance).
2. **Receives** real-time order book data for the specified trading pair.
3. **Publishes** the received data to a Kafka topic.

This service is a stateless worker intended to run as a **Kubernetes Job**. All configuration is provided through environment variables.

---

## Environment Variables

The service is fully configured via environment variables.

| Variable                    | Description                                                       | Example                                |
| --------------------------- | ----------------------------------------------------------------- | -------------------------------------- |
| **`QUEUE_ID`**              | Unique identifier for the entire workflow.                        | `wf-ws-orderbook-20240801-a1b2c3`      |
| **`SYMBOL`**                | Trading pair to load data for.                                    | `BTCUSDT`                              |
| **`TYPE`**                  | Type of data processed (e.g., `ws_depth`, `ws_diff_depth`).       | `ws_depth`                             |
| **`KAFKA_TOPIC`**           | Name of the Kafka topic to publish data to.                       | `wf-ws-orderbook-20240801-a1b2c3-data` |
| **`TELEMETRY_PRODUCER_ID`** | Unique ID of this instance for telemetry.                         | `loader-ws-orderbook__a1b2c3`          |
| `KAFKA_BOOTSTRAP_SERVERS`   | Kafka broker addresses.                                           | `kafka-bootstrap.kafka:9093`           |
| `KAFKA_USER_PRODUCER`       | Kafka username for producer authentication.                       | `user-producer-tls`                    |
| `KAFKA_PASSWORD_PRODUCER`   | Kafka password for producer authentication (provided via Secret). | `your_kafka_password`                  |
| `CA_PATH`                   | Path to the CA certificate for TLS connection to Kafka.           | `/certs/ca.crt`                        |
| `QUEUE_CONTROL_TOPIC`       | Topic for receiving control commands (e.g., `stop`).              | `queue-control`                        |
| `QUEUE_EVENTS_TOPIC`        | Topic for sending telemetry events.                               | `queue-events`                         |
| `BINANCE_WS_URL`            | Base URL for the Binance WebSocket API.                           | `wss://stream.binance.com:9443/ws`     |

---

## Input Data (WebSocket)

The service connects to an external WebSocket API (e.g., Binance) to receive real-time order book data.
The data format follows the standard WebSocket specification for order book updates.

---

## Output Data (Kafka)

The service publishes the received order book data to the `KAFKA_TOPIC` in JSON format.
Each message represents either a snapshot or a delta of the order book.

```json
{
  "e": "depthUpdate",
  "E": 1678886400000,
  "s": "BTCUSDT",
  "U": 12345,
  "u": 12350,
  "b": [
    ["20000.00", "1.0"],
    ["19999.50", "2.0"]
  ],
  "a": [
    ["20000.50", "1.0"],
    ["20001.00", "0.5"]
  ]
}
```

---

## Telemetry (Topic: `queue-events`)

The service sends status events to the `queue-events` topic, enabling `queue-manager` to track task progress.

**Example `loading` event:**

```json
{
  "queue_id": "wf-ws-orderbook-20240801-a1b2c3",
  "symbol": "BTCUSDT",
  "type": "ws_depth",
  "status": "loading",
  "message": "Loaded and published 15000 order book records",
  "records_written": 15000,
  "finished": false,
  "producer": "loader-ws-orderbook__a1b2c3",
  "timestamp": 1722445567.890
}
```

**Possible statuses:** `started`, `loading`, `interrupted`, `error`, `finished`.

---

## Control (Topic: `queue-control`)

The service listens to the `queue-control` topic and reacts to commands addressed to its `queue_id`.

**Example `stop` command:**

```json
{
  "command": "stop",
  "queue_id": "wf-ws-orderbook-20240801-a1b2c3"
}
```

Upon receiving this command, the service shuts down gracefully.
