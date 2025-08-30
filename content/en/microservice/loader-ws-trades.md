+++
title = "Loader Ws Trades"
weight = 68
[params]
  menuPre = '<i class="fa-fw fas fa-exchange-alt"></i> '
+++

# loader-ws-trades

A microservice in the **StreamForge** ecosystem designed to load real-time trade data via WebSocket and publish it to Kafka.

## Purpose

`loader-ws-trades` performs the following tasks:

1. **Connects** to an external WebSocket API (e.g., Binance).
2. **Receives** real-time trade data for the specified trading pair.
3. **Publishes** the received data to a Kafka topic.

This service is a stateless worker intended to run as a **Kubernetes Job**. All configuration is provided through environment variables.

---

## Environment Variables

The service is fully configured via environment variables.

| Variable                    | Description                                                       | Example                             |
| --------------------------- | ----------------------------------------------------------------- | ----------------------------------- |
| **`QUEUE_ID`**              | Unique identifier for the entire workflow.                        | `wf-ws-trades-20240801-a1b2c3`      |
| **`SYMBOL`**                | Trading pair to load data for.                                    | `BTCUSDT`                           |
| **`TYPE`**                  | Type of data processed.                                           | `ws_trade`                          |
| **`KAFKA_TOPIC`**           | Name of the Kafka topic to publish data to.                       | `wf-ws-trades-20240801-a1b2c3-data` |
| **`TELEMETRY_PRODUCER_ID`** | Unique ID of this instance for telemetry.                         | `loader-ws-trades__a1b2c3`          |
| `KAFKA_BOOTSTRAP_SERVERS`   | Kafka broker addresses.                                           | `kafka-bootstrap.kafka:9093`        |
| `KAFKA_USER_PRODUCER`       | Kafka username for producer authentication.                       | `user-producer-tls`                 |
| `KAFKA_PASSWORD_PRODUCER`   | Kafka password for producer authentication (provided via Secret). | `your_kafka_password`               |
| `CA_PATH`                   | Path to the CA certificate for TLS connection to Kafka.           | `/certs/ca.crt`                     |
| `QUEUE_CONTROL_TOPIC`       | Topic for receiving control commands (e.g., `stop`).              | `queue-control`                     |
| `QUEUE_EVENTS_TOPIC`        | Topic for sending telemetry events.                               | `queue-events`                      |
| `BINANCE_WS_URL`            | Base URL for the Binance WebSocket API.                           | `wss://stream.binance.com:9443/ws`  |

---

## Input Data (WebSocket)

The service connects to an external WebSocket API (e.g., Binance) to receive real-time trade data.
The data format follows the standard WebSocket specification for trades.

---

## Output Data (Kafka)

The service publishes the received trade data to the `KAFKA_TOPIC` in JSON format.
Each message represents a single trade.

```json
{
  "trade_id": 12345,
  "price": 20000.50,
  "quantity": 0.1,
  "timestamp": 1672531200000,
  "is_buyer_maker": true,
  "symbol": "BTCUSDT"
}
```

---

## Telemetry (Topic: `queue-events`)

The service sends status events to the `queue-events` topic, enabling `queue-manager` to track task progress.

**Example `loading` event:**

```json
{
  "queue_id": "wf-ws-trades-20240801-a1b2c3",
  "symbol": "BTCUSDT",
  "type": "ws_trade",
  "status": "loading",
  "message": "Loaded and published 15000 trade records",
  "records_written": 15000,
  "finished": false,
  "producer": "loader-ws-trades__a1b2c3",
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
  "queue_id": "wf-ws-trades-20240801-a1b2c3"
}
```

Upon receiving this command, the service shuts down gracefully.
