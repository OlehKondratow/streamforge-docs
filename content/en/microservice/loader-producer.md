+++
title = "Loader Producer"
weight = 65
[params]
  menuPre = '<i class="fa-fw fas fa-exchange-alt"></i> '
+++
# loader-producer

A microservice in the **StreamForge** ecosystem designed for high-performance bulk data loading and publishing to Kafka.

## Purpose

`loader-producer` performs the following tasks:

1. **Connects** to a data source (e.g., Binance API).
2. **Loads** data (e.g., historical candles, trades).
3. **Publishes** the retrieved data to a Kafka topic.

This service is a stateless worker intended to run as a **Kubernetes Job**. All configuration is provided through environment variables.

---

## Configuration via Environment Variables

The service is fully configurable through environment variables.

| Variable                    | Description                                                       | Example                             |
| --------------------------- | ----------------------------------------------------------------- | ----------------------------------- |
| **`QUEUE_ID`**              | Unique identifier for the entire workflow.                        | `wf-bulk-load-20240801-a1b2c3`      |
| **`SYMBOL`**                | Trading pair or data identifier.                                  | `BTCUSDT`                           |
| **`TYPE`**                  | Data type to process (e.g., `api_candles_1m`, `ws_trades`).       | `api_candles_1m`                    |
| **`TIME_RANGE`**            | Time range for data loading (START\_DATE\:END\_DATE).             | `2023-01-01:2023-01-02`             |
| **`INTERVAL`**              | Candle interval (for `api_candles`, `ws_candles`).                | `1h`                                |
| **`KAFKA_TOPIC`**           | Name of the Kafka topic to publish data to.                       | `wf-bulk-load-20240801-a1b2c3-data` |
| **`TELEMETRY_PRODUCER_ID`** | Unique ID for this instance for telemetry.                        | `loader-producer__a1b2c3`           |
| `KAFKA_BOOTSTRAP_SERVERS`   | Kafka broker addresses.                                           | `kafka-bootstrap.kafka:9093`        |
| `KAFKA_USER_PRODUCER`       | Kafka username for producer authentication.                       | `user-producer-tls`                 |
| `KAFKA_PASSWORD_PRODUCER`   | Kafka password for producer authentication (provided via Secret). | `your_kafka_password`               |
| `CA_PATH`                   | Path to CA certificate for TLS connection to Kafka.               | `/certs/ca.crt`                     |
| `QUEUE_CONTROL_TOPIC`       | Topic for receiving control commands (e.g., `stop`).              | `queue-control`                     |
| `QUEUE_EVENTS_TOPIC`        | Topic for sending telemetry events.                               | `queue-events`                      |
| `BINANCE_API_URL`           | Base URL for Binance REST API.                                    | `https://api.binance.com`           |
| `BINANCE_WS_URL`            | Base URL for Binance WebSocket API.                               | `wss://stream.binance.com:9443/ws`  |
| `BINANCE_API_KEY`           | API key for Binance API access.                                   | `your_binance_api_key`              |
| `BINANCE_API_SECRET`        | API secret for Binance API access.                                | `your_binance_api_secret`           |
| `TELEMETRY_INTERVAL`        | Telemetry sending interval in seconds.                            | `5`                                 |
| `DEBUG`                     | Enable debug mode.                                                | `true`                              |

---

## Input Data (API/WS)

The service connects to external data sources (e.g., Binance API/WS) to fetch data.
The data format depends on the `TYPE`.

---

## Output Data (Kafka)

The service publishes the retrieved data to `KAFKA_TOPIC` in JSON format.
Each message represents a single data record.

---

## Telemetry (Topic: `queue-events`)

The service sends status events to the `queue-events` topic, allowing `queue-manager` to monitor task progress.

**Example `loading` event:**

```json
{
  "queue_id": "wf-bulk-load-20240801-a1b2c3",
  "symbol": "BTCUSDT",
  "type": "api_candles_1m",
  "status": "loading",
  "message": "Loaded and published 15000 records",
  "records_written": 15000,
  "finished": false,
  "producer": "loader-producer__a1b2c3",
  "timestamp": 1722445567.890
}
```

**Possible statuses:** `started`, `loading`, `interrupted`, `error`, `finished`.

---

## Control (Topic: `queue-control`)

The service listens to the `queue-control` topic and responds to commands addressed to its `queue_id`.

**Example `stop` command:**

```json
{
  "command": "stop",
  "queue_id": "wf-bulk-load-20240801-a1b2c3"
}
```

Upon receiving this command, the service shuts down gracefully.