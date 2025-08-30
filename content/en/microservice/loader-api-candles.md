+++
title = "Loader Api Candles"
weight = 63
[params]
  menuPre = '<i class="fa-fw fas fa-exchange-alt"></i> '
+++

# `loader-api-candles`

A microservice in the **StreamForge** ecosystem designed to load historical candlestick (K-line) data via REST API and publish it to Kafka.

---

## 1. Purpose

`loader-api-candles` performs the following tasks:

1. **Connects** to an external API (e.g., Binance).
2. **Retrieves** historical candlestick data for a specified trading pair and interval.
3. **Publishes** the retrieved data to a Kafka topic.

This service is a stateless worker intended to run as a **Kubernetes Job**.
All configuration is provided via environment variables.

---

## 2. Environment Variables

The service is fully configured through environment variables.

| Variable                    | Description                                                       | Example                                |
| --------------------------- | ----------------------------------------------------------------- | -------------------------------------- |
| **`QUEUE_ID`**              | Unique workflow identifier.                                       | `wf-candles-load-20240801-a1b2c3`      |
| **`SYMBOL`**                | Trading pair to load data for.                                    | `BTCUSDT`                              |
| **`TYPE`**                  | Type of data being processed.                                     | `api_candles`                          |
| **`KAFKA_TOPIC`**           | Kafka topic name to publish data to.                              | `wf-candles-load-20240801-a1b2c3-data` |
| **`TIME_RANGE`**            | Time range for data loading (`START_DATE:END_DATE`).              | `2023-01-01:2023-01-02`                |
| **`INTERVAL`**              | Candlestick interval (e.g., `1m`, `1h`, `1d`).                    | `1h`                                   |
| **`TELEMETRY_PRODUCER_ID`** | Unique ID of this instance for telemetry reporting.               | `loader-api-candles__a1b2c3`           |
| `KAFKA_BOOTSTRAP_SERVERS`   | Kafka broker addresses.                                           | `kafka-bootstrap.kafka:9093`           |
| `KAFKA_USER_PRODUCER`       | Kafka username for producer authentication.                       | `user-producer-tls`                    |
| `KAFKA_PASSWORD_PRODUCER`   | Kafka password for producer authentication (provided via Secret). | `your_kafka_password`                  |
| `CA_PATH`                   | Path to the CA certificate for Kafka TLS connection.              | `/certs/ca.crt`                        |
| `QUEUE_CONTROL_TOPIC`       | Kafka topic for receiving control commands (e.g., `stop`).        | `queue-control`                        |
| `QUEUE_EVENTS_TOPIC`        | Kafka topic for sending telemetry events.                         | `queue-events`                         |
| `BINANCE_API_KEY`           | API key for accessing Binance API.                                | `your_binance_api_key`                 |
| `BINANCE_API_SECRET`        | API secret for accessing Binance API.                             | `your_binance_api_secret`              |

---

## 3. Input Data (API)

The service connects to an external API (e.g., Binance) to fetch candlestick data.
The data format follows the standard K-lines specification.

---

## 4. Output Data (Kafka)

The service publishes the retrieved candlestick data to the `KAFKA_TOPIC` in JSON format.
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
  "interval": "1h"
}
```

---

## 5. Telemetry (Topic: `queue-events`)

The service sends status events to the `queue-events` topic.
This enables the `queue-manager` to track the progress of the job.

**Example `loading` event:**

```json
{
  "queue_id": "wf-candles-load-20240801-a1b2c3",
  "symbol": "BTCUSDT",
  "type": "api_candles",
  "status": "loading",
  "message": "Loaded and published 15000 candlestick records",
  "records_written": 15000,
  "finished": false,
  "producer": "loader-api-candles__a1b2c3",
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
  "queue_id": "wf-candles-load-20240801-a1b2c3"
}
```

Upon receiving this command, the service performs a graceful shutdown.
