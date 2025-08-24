+++
title = "Dummy Service"
type = "chapter"
weight = 1
+++

# `dummy-service`: Telemetry & Command Simulation Microservice

`dummy-service` is a test microservice in the **StreamForge** ecosystem, designed for:

* Receiving commands from Kafka (`queue-control`)
* Sending events (`started`, `pong`, `interrupted`, `finished`) to Kafka (`queue-events`)
* Simulating loading and errors
* Logging in structured JSON format
* Exposing Prometheus metrics via HTTP (`/metrics`)
* Running in Kubernetes as a `Job`, `Pod`, `Deployment`, or locally

---

## 1. Main Features

| Feature            | Description                                                     |
| ------------------ | --------------------------------------------------------------- |
| `ping/pong`        | Responds to `ping` command by sending a `pong` with a timestamp |
| `stop`             | Stops on command, publishing an `interrupted` event             |
| `simulate-loading` | Periodically sends `loading` events to Kafka                    |
| `fail-after N`     | Sends `error` and terminates after `N` seconds                  |
| `/metrics`         | Exports Prometheus metrics (event counters, status)             |
| JSON logging       | Structured logs compatible with Fluent Bit / Loki               |

---

## 2. Environment Variables

| Variable                  | Description                                        |
| ------------------------- | -------------------------------------------------- |
| `QUEUE_ID`                | Unique workflow ID (e.g., `loader-...`)            |
| `SYMBOL`                  | Symbol, e.g. `BTCUSDT`                             |
| `TIME_RANGE`              | Range, e.g. `2024-01-01:2024-01-02`                |
| `TYPE`                    | Source type: `api`, `ws`, `dummy`, etc.            |
| `TELEMETRY_PRODUCER_ID`   | Service identifier in telemetry events             |
| `KAFKA_TOPIC`             | Target Kafka topic                                 |
| `QUEUE_EVENTS_TOPIC`      | Kafka topic for events (usually `queue-events`)    |
| `QUEUE_CONTROL_TOPIC`     | Kafka topic for commands (usually `queue-control`) |
| `KAFKA_BOOTSTRAP_SERVERS` | Kafka broker address                               |
| `KAFKA_USER`              | SCRAM username                                     |
| `KAFKA_PASSWORD`          | SCRAM password                                     |
| `KAFKA_CA_PATH`           | Path to CA certificate for TLS                     |
| `ARANGO_*`                | Optional ArangoDB connection details               |

---

## 3. Example Local Run

To run `dummy-service` locally (e.g., inside a devcontainer), navigate to the service directory and start it as a Python module:

```bash
cd /data/projects/stream-forge/services/dummy-service/
python3.11 -m app.main \
  --debug \
  --simulate-loading \
  --exit-after 30
```

---

## 4. Testing with `debug_producer.py`

`debug_producer.py` is a CLI tool for sending test commands to the `queue-control` Kafka topic and waiting for responses from `queue-events`.
It is used for debugging and testing microservices that communicate via Kafka.

### Examples

**4.1 Kafka Connectivity Test (ping/pong)**

```bash
python3.11 debug_producer.py \
  --queue-id <your-queue-id> \
  --command ping \
  --expect-pong
```

**4.2 Stop Command Test**

```bash
python3.11 debug_producer.py \
  --queue-id <your-queue-id> \
  --command stop
```

---

## 5. Supported `main.py` Flags

| Flag                 | Description                                                 |
| -------------------- | ----------------------------------------------------------- |
| `--debug`            | Enables DEBUG log level                                     |
| `--noop`             | Sends `started` event only, without starting Kafka consumer |
| `--exit-on-ping`     | Terminates after receiving `ping` and sending `pong`        |
| `--exit-after N`     | Terminates after `N` seconds                                |
| `--simulate-loading` | Sends `loading` event every 10 seconds                      |
| `--fail-after N`     | Sends `error` and terminates after `N` seconds              |

---

## 6. Metrics (`/metrics`)

Exposed on port `8000` and include:

* `dummy_events_total{event="started|pong|interrupted|..."}`
* `dummy_pings_total`, `dummy_pongs_total`
* `dummy_status_last{status="loading|interrupted|finished"}`

---

## 7. Example `Dockerfile` Entry Point

```dockerfile
CMD ["python3.11", "main.py", "--simulate-loading", "--exit-after", "30"]
```

---

## 8. Kubernetes Integration

Recommended to run as `Job` or `Pod` with:

* `envFrom`: ConfigMap + Secret
* Volume mount for CA (`/usr/local/share/ca-certificates/ca.crt`)
* Kafka connection via TLS + SCRAM

---

## 9. Usage in StreamForge

`dummy-service` can be used as:

* Loader emulator (`loader`)
* Kafka connectivity test (`ping/pong`)
* CI/CD command test (`stop`, `interrupted`)
* Real-time metrics and log monitoring tool
