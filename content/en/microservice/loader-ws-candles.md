+++
title = "Loader Ws Candles"
type = "chapter"
weight = 1
+++

# `loader-ws-candles`

A microservice in the **StreamForge** ecosystem designed to load real-time candlestick (K-line) data via WebSocket and publish it to Kafka.

---

## 1. Purpose

`loader-ws-candles` performs the following tasks:

1. **Connects** to an external WebSocket API (e.g., Binance).
2. **Receives** real-time candlestick data for the specified trading pair and interval.
3. **Publishes** the received data to a Kafka topic.

This service is a stateless worker intended to run as a **Kubernetes Job**.
All configuration is provided via environment variables.

---

## 2. Environment Variables

The service is fully configured through environment variables.

| Variable                    | Description                                                       | Example                              |
| --------------------------- | ----------------------------------------------------------------- | ------------------------------------ |
| **`QUEUE_ID`**              | Unique workflow identifier.                                       | `wf-ws-candles-20240801-a1b2c3`      |
| **`SYMBOL`**                | Trading pair to load data for.                                    | `BTCUSDT`                            |
| **`TYPE`**                  | Type of data being processed.                                     | `ws_candles`                         |
| **`INTERVAL`**              | Candlestick interval (e.g., `1m`, `5m`, `1h`).                    | `1m`                                 |
| **`KAFKA_TOPIC`**           | Kafka topic name to publish data to.                              | `wf-ws-candles-20240801-a1b2c3-data` |
| **`TELEMETRY_PRODUCER_ID`** | Unique ID of this instance for telemetry reporting.               | `loader-ws-candles__a1b2c3`          |
| `KAFKA_BOOTSTRAP_SERVERS`   | Kafka broker addresses.                                           | `kafka-bootstrap.kafka:9093`         |
| `KAFKA_USER_PRODUCER`       | Kafka username for producer authentication.                       | `user-producer-tls`                  |
| `KAFKA_PASSWORD_PRODUCER`   | Kafka password for producer authentication (provided via Secret). | `your_kafka_password`                |
| `CA_PATH`                   | Path to the CA certificate for Kafka TLS connection.              | `/certs/ca.crt`                      |
| `QUEUE_CONTROL_TOPIC`       | Kafka topic for receiving control commands (e.g., `stop`).        | `queue-control`                      |
| `QUEUE_EVENTS_TOPIC`        | Kafka topic for sending telemetry events.                         | `queue-events`                       |
| `BINANCE_WS_URL`            | Base URL for Binance WebSocket API.                               | `wss://stream.binance.com:9443/ws`   |

---

## 3. Input Data (WebSocket)

The service connects to an external WebSocket API (e.g., Binance) to receive real-time candlestick data.
The data format follows the standard Binance K-line WebSocket specification.

---

## 4. Output Data (Kafka)

The service publishes the candlestick data to the `KAFKA_TOPIC` in JSON format.
Each message represents a single candlestick.

**Example message:**

```json
{
  "open_time": 1672531200000,
  "open": 16541.23,
  "high": 16542.88,
  "low": 16540.99,
  "close": 16541.98,
  "volume": 123.45,
  "close_time": 1672531259999,
  "quote_asset_volume": 2042134.56,
  "number_of_trades": 456,
  "taker_buy_base_asset_volume": 60.12,
  "taker_buy_quote_asset_volume": 994512.34,
  "symbol": "BTCUSDT",
  "interval": "1m"
}
```

---

## 5. Telemetry (Topic: `queue-events`)

The service sends status events to the `queue-events` topic.
This allows the `queue-manager` to monitor the job’s progress.

**Example `loading` event:**

```json
{
  "queue_id": "wf-ws-candles-20240801-a1b2c3",
  "symbol": "BTCUSDT",
  "type": "ws_candles",
  "status": "loading",
  "message": "Loaded and published 15000 candlestick records",
  "records_written": 15000,
  "finished": false,
  "producer": "loader-ws-candles__a1b2c3",
  "timestamp": 1722445567.890
}
```

**Possible statuses:** `started`, `loading`, `interrupted`, `error`, `finished`.

---

## 6. Control (Topic: `queue-control`)

The service listens to the `queue-control` topic and reacts to commands addressed to its `queue_id`.

**Example `stop` command:**

```json
{
  "command": "stop",
  "queue_id": "wf-ws-candles-20240801-a1b2c3"
}
```

Upon receiving this command, the service performs a graceful shutdown.
