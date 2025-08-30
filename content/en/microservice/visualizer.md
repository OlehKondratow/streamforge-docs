+++
title = "Visualizer"
weight = 70
[params]
  menuPre = '<i class="fa-fw fas fa-chart-pie"></i> '
+++

## Documentation: `visualizer` (StreamForge)

### Purpose

The `visualizer` microservice is responsible for displaying market data, technical indicators, and graph structures in a **web interface** (UI).
It is used to retrieve and display both real-time data and historical collections.

---

### Supported UI Tabs

* `Webhooks` — events from microservices
* `Kafka Topic` — WebSocket message stream
* `Candlestick Chart` — OHLCV visualization
* `Heatmap Levels` — market level visualization
* `Indicators` — RSI, VWAP, MA, etc.
* `GNN Output` — probabilities, classifications
* `Graph View` — token/relationship graph visualization

---

### Example Start Command from `queue-manager`

```json
{
  "command": "start",
  "queue_id": "visual-btcusdt-candles_indicators-2024_06_01-abc123",
  "target": "visualizer",
  "symbol": "BTCUSDT",
  "type": "candles_indicators",
  "telemetry_id": "visualizer__abc123",
  "image": "registry.dmz.home/streamforge/visualizer:v0.1.0",
  "timestamp": 1722347501.100
}
```

---

### Example Telemetry (`queue-events`)

```json
{
  "queue_id": "visual-btcusdt-candles_indicators-2024_06_01-abc123",
  "telemetry_id": "visualizer__abc123",
  "status": "started",
  "message": "Visualizer started",
  "timestamp": 1722347510.123,
  "producer": "visualizer__abc123",
  "finished": false
}
```

```json
{
  "queue_id": "visual-btcusdt-candles_indicators-2024_06_01-abc123",
  "telemetry_id": "visualizer__abc123",
  "status": "finished",
  "message": "Visualizer shutdown (no more data)",
  "timestamp": 1722348999.456,
  "producer": "visualizer__abc123",
  "finished": true
}
```

---

### WebSocket Support

```http
GET /ws/topic/{kafka_topic}
```

Retrieves messages from the specified Kafka topic and streams them to the client in real time.

---

### Environment Variables (.env or ConfigMap)

```dotenv
ARANGO_URL=http://abase-3.dmz.home:8529
ARANGO_DB=streamforge
ARANGO_USER=root
ARANGO_PASSWORD=...

KAFKA_BOOTSTRAP_SERVERS=k3-kafka-bootstrap.kafka:9093
KAFKA_USER=user-consumer-tls
KAFKA_PASSWORD=...
CA_PATH=/usr/local/share/ca-certificates/ca.crt

QUEUE_CONTROL_TOPIC=queue-control
QUEUE_EVENTS_TOPIC=queue-events
KAFKA_TOPIC=visualizer-topic
QUEUE_ID=visual-btcusdt-candles_indicators-2024_06_01-abc123

TELEMETRY_PRODUCER_ID=visualizer__abc123

# UI
FRONTEND_PATH=/app/frontend
HOST=0.0.0.0
PORT=8000
```
---

### Data Sources

| Source         | Purpose                     |
| -------------- | --------------------------- |
| Kafka (topic)  | Receive data via WebSocket  |
| ArangoDB       | Historical candle data, RSI |
| MinIO (future) | GNN model outputs           |

---

### Technical Components

* FastAPI backend
* Jinja2 templates
* WebSocket endpoint
* Kafka consumer
* Prometheus metrics
* Filtering by `queue_id` and `symbol`

---

### Unit Tests

* Verify WebSocket connection and routes
* Check data retrieval and handling from Kafka
* Validate filtering by symbol / type
* Test UI templates (HTML response)

---

### Behavior

1. Receives start command from `queue-control`
2. Launches UI and WebSocket listener
3. Updates tabs as new data arrives
4. Stops on `stop` command or when no new data is available

---

## `visualizer`: API Command / Swagger Template

**Purpose:** Render charts from ArangoDB or MinIO data: candles, indicators, graphs, model predictions.

### Example `/queues/start` Command

```json
{
  "command": "start",
  "queue_id": "visualize-btcusdt-2024_06_01-abc123",
  "target": "visualizer",
  "symbol": "BTCUSDT",
  "type": "plot_graph",
  "collection_name": "btc_graph_5m_2024_06_01",
  "graph_name": "btc_graph_5m_2024_06_01",
  "output_type": "html",
  "output_path": "s3://visuals/btcusdt/2024_06_01/index.html",
  "image": "registry.dmz.home/streamforge/visualizer:v0.1.0",
  "telemetry_id": "visualizer__abc123",
  "timestamp": 1722346211.177
}
```

---

### Example Telemetry (`queue-events`)

```json
{
  "queue_id": "visualize-btcusdt-2024_06_01-abc123",
  "status": "started",
  "telemetry_id": "visualizer__abc123",
  "message": "Chart rendering started"
}
```

```json
{
  "queue_id": "visualize-btcusdt-2024_06_01-abc123",
  "status": "finished",
  "telemetry_id": "visualizer__abc123",
  "output_path": "s3://visuals/btcusdt/2024_06_01/index.html"
}
```
