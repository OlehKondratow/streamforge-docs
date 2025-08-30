+++
title = "Loader Api Trades"
weight = 64
[params]
  menuPre = '<i class="fa-fw fas fa-exchange-alt"></i> '
+++

# `loader-api-trades`

A microservice in the **StreamForge** ecosystem designed to load historical trade data via REST API and publish it to Kafka.

---

## 1. Purpose

`loader-api-trades` performs the following tasks:

1. **Connects** to an external API (e.g., Binance).
2. **Retrieves** historical trade data for the specified trading pair.
3. **Publishes** the retrieved data to a Kafka topic.

This service is a stateless worker intended to run as a **Kubernetes Job**.
All configuration is provided via environment variables.

---

## 2. Environment Variables

The service is fully configured through environment variables.

| Variable                    | Description                                                       | Example                               |
| --------------------------- | ----------------------------------------------------------------- | ------------------------------------- |
| **`QUEUE_ID`**              | Unique workflow identifier.                                       | `wf-trades-load-20240801-a1b2c3`      |
| **`SYMBOL`**                | Trading pair to load data for.                                    | `BTCUSDT`                             |
| **`TYPE`**                  | Type of data being processed.                                     | `api_trades`                          |
| **`KAFKA_TOPIC`**           | Kafka topic name to publish data to.                              | `wf-trades-load-20240801-a1b2c3-data` |
| **`TIME_RANGE`**            | Time range for data loading (`START_DATE:END_DATE`).              | `2023-01-01:2023-01-02`               |
| **`LIMIT`**                 | Maximum number of trades per request.                             | `1000`                                |
| **`TELEMETRY_PRODUCER_ID`** | Unique ID of this instance for telemetry reporting.               | `loader-api-trades__a1b2c3`           |
| `KAFKA_BOOTSTRAP_SERVERS`   | Kafka broker addresses.                                           | `kafka-bootstrap.kafka:9093`          |
| `KAFKA_USER_PRODUCER`       | Kafka username for producer authentication.                       | `user-producer-tls`                   |
| `KAFKA_PASSWORD_PRODUCER`   | Kafka password for producer authentication (provided via Secret). | `your_kafka_password`                 |
| `CA_PATH`                   | Path to the CA certificate for Kafka TLS connection.              | `/certs/ca.crt`                       |
| `QUEUE_CONTROL_TOPIC`       | Kafka topic for receiving control commands (e.g., `stop`).        | `queue-control`                       |
| `QUEUE_EVENTS_TOPIC`        | Kafka topic for sending telemetry events.                         | `queue-events`                        |
| `BINANCE_API_KEY`           | API key for accessing Binance API.                                | `your_binance_api_key`                |
| `BINANCE_API_SECRET`        | API secret for accessing Binance API.                             | `your_binance_api_secret`             |

---

## 3. Input Data (API)

The service connects to an external API (e.g., Binance) to fetch trade data.
The data format follows Binance aggregated trade data (`aggTrades`).

---

## 4. Output Data (Kafka)

The service publishes the retrieved trade data to the `KAFKA_TOPIC` in JSON format.
Each message represents a single trade.

**Example message:**

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

## 5. Telemetry (Topic: `queue-events`)

The service sends status events to the `queue-events` topic.
This enables the `queue-manager` to track the progress of the job.

**Example `loading` event:**

```json
{
  "queue_id": "wf-trades-load-20240801-a1b2c3",
  "symbol": "BTCUSDT",
  "type": "api_trades",
  "status": "loading",
  "message": "Loaded and published 15000 trade records",
  "records_written": 15000,
  "finished": false,
  "producer": "loader-api-trades__a1b2c3",
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
  "queue_id": "wf-trades-load-20240801-a1b2c3"
}
```

Upon receiving this command, the service performs a graceful shutdown.
