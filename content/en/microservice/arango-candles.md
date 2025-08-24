+++
title = "Arango Candles"
weight = 1
+++

A consumer microservice in the **StreamForge** ecosystem.

## Purpose

`arango-candles` performs one primary task:

1.  **Listens** to a specific Kafka topic that receives candle data.
2.  **Processes** these messages.
3.  **Saves** them to the corresponding collection in the ArangoDB database.

This service is a stateless worker designed to run as a **Kubernetes Job**. It receives all necessary configuration through environment variables.

## ⚙️ Environment Variables

The service is fully configured through environment variables.

| Variable                  | Description                                                     | Example                                          |
| ------------------------- | --------------------------------------------------------------- | ------------------------------------------------ |
| **`QUEUE_ID`**            | A unique identifier for the entire workflow.                    | `wf-btcusdt-20240801-a1b2c3`                     |
| **`SYMBOL`**              | The trading pair.                                               | `BTCUSDT`                                        |
| **`TYPE`**                | The type of data being processed.                               | `api_candles_1m`                                 |
| **`KAFKA_TOPIC`**         | The name of the Kafka topic to read data from.                  | `wf-btcusdt-20240801-a1b2c3-api-candles-1m`      |
| **`COLLECTION_NAME`**     | The name of the collection in ArangoDB to save data to.         | `btcusdt_api_candles_1m_2024_08_01`              |
| **`TELEMETRY_PRODUCER_ID`**| A unique ID for this instance for telemetry.                   | `arango-candles__a1b2c3`                         |
| `KAFKA_BOOTSTRAP_SERVERS` | The addresses of the Kafka brokers.                             | `kafka-bootstrap.kafka:9093`                     |
| `KAFKA_USER_CONSUMER`     | The username for Kafka authentication (consumer).               | `user-consumer-tls`                              |
| `KAFKA_PASSWORD_CONSUMER` | The password for the Kafka user (passed via Secret).            | `your_kafka_password`                            |
| `CA_PATH`                 | The path to the CA certificate for the TLS connection to Kafka. | `/certs/ca.crt`                                  |
| `QUEUE_CONTROL_TOPIC`     | The topic for receiving control commands (e.g., `stop`).        | `queue-control`                                  |
| `QUEUE_EVENTS_TOPIC`      | The topic for sending telemetry events.                         | `queue-events`                                   |
| `ARANGO_URL`              | The URL for connecting to ArangoDB.                             | `http://arango-cluster.db:8529`                  |
| `ARANGO_DB`               | The name of the database in ArangoDB.                           | `streamforge`                                    |
| `ARANGO_USER`             | The user for connecting to ArangoDB.                            | `root`                                           |
| `ARANGO_PASSWORD`         | The password for ArangoDB (passed via Secret).                  | `your_arango_password`                           |

---

## Input Data (Kafka)

The service expects to receive JSON messages in the following format from the `KAFKA_TOPIC` topic:

```json
{
  "_key": "BTCUSDT_1m_1672531200000",
  "open_time": 1672531200000,
  "open": "16541.23",
  "high": "16542.88",
  "low": "16540.99",
  "close": "16541.98",
  "volume": "123.45",
  "close_time": 1672531259999,
  "quote_asset_volume": "2042134.56",
  "number_of_trades": 456,
  "taker_buy_base_asset_volume": "60.12",
  "taker_buy_quote_asset_volume": "994512.34"
}
```

The `_key` field is used for idempotent insertion/updating of data in ArangoDB (`UPSERT`).

---

## Telemetry (Topic: `queue-events`)

The service sends events about its status to the `queue-events` topic. This allows the `queue-manager` to track the progress of the task.

**Example of a `loading` event:**

```json
{
  "queue_id": "wf-btcusdt-20240801-a1b2c3",
  "symbol": "BTCUSDT",
  "type": "api_candles_1m",
  "status": "loading",
  "message": "Saved 15000 records",
  "records_written": 15000,
  "finished": false,
  "producer": "arango-candles__a1b2c3",
  "timestamp": 1722445567.890
}
```

**Possible statuses:** `started`, `loading`, `interrupted`, `error`, `finished`.

---

## Management (Topic: `queue-control`)

The service listens to the `queue-control` topic and reacts to commands addressed to its `queue_id`.

**`stop` command:**

```json
{
  "command": "stop",
  "queue_id": "wf-btcusdt-20240801-a1b2c3"
}
```

Upon receiving this command, the service gracefully terminates: it stops the consumer, closes the database connection, and sends a final telemetry event with the status `interrupted`.

---

## Unit Tests

The unit tests for this service are located in `tests/test_consumer.py`. They cover the core logic of the `calculate_and_update_indicators` function.

### 1. `test_calculate_and_update_indicators_success` (Happy Path)

This test checks the main success scenario.

-   **It simulates:** A situation where historical candle data exists in the database.
-   **It asserts that:**
    -   The function correctly queries the database for historical data.
    -   After calculating the indicators, it attempts to update the latest candle document.
    -   The data payload for the update contains the expected indicator keys (e.g., `EMA_50`, `RSI_14`).

### 2. `test_no_historical_data` (No Data Scenario)

This test checks how the function behaves when no historical data is available for a symbol.

-   **It simulates:** An empty response from the database.
-   **It asserts that:**
    -   The database `update` method is **not** called.
    -   The function handles this case gracefully without raising an error.

### 3. `test_indicator_calculation_error` (Error Scenario)

This test ensures the service is resilient to potential errors during the indicator calculation process.

-   **It simulates:** A situation where the historical data is malformed (e.g., missing required columns like `open`, `high`, `low`, `close`), which will cause an exception in the `pandas-ta` library.
-   **It asserts that:**
    -   The function catches the internal exception and does **not** crash.
    -   The database `update` method is **not** called if the calculation fails.
