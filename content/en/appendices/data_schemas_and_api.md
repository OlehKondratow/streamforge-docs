+++
title = "Data Schemas and API"
weight = 1
[params]
  menuPre = '<i class="fa-fw fas fa-table"></i> '
+++

#  Queue Manager – Data Schemas & API Reference

##  Purpose

`queue-manager` is a crucial component of the StreamForge ecosystem, acting as a central control plane for data processing workflows. This FastAPI-based microservice is responsible for orchestrating the entire lifecycle of data loading and processing tasks, referred to as "queues." Its primary functions are:

*   **State Management:** It translates incoming requests into persistent state records within ArangoDB, serving as the single source of truth for all queue-related activities.
*   **Execution Orchestration:** It dynamically launches and parameterizes Kubernetes Jobs, effectively decoupling the request for work from the execution of the work itself. This allows for greater scalability and resilience.
*   **Real-time Monitoring:** It provides a real-time view into the status and results of ongoing tasks, offering both a pull-based API and push-based WebSocket notifications.
*   **Observability:** It exposes key operational metrics in a Prometheus-compatible format, enabling robust monitoring and alerting.

# \[Package] StreamForge Queue Manager

This microservice is designed for managing the initiation, cessation, and observation of data processing queues within the StreamForge platform.

## \[Features]

*   **Dynamic Job Orchestration:** Launches a variety of Kubernetes Jobs, including `loader-producer`, `arango-connector`, `gnn-trainer`, `visualizer`, and `graph-builder`, based on incoming requests.
*   **API-Driven Configuration:** Leverages a Swagger/OpenAPI interface for clear, parameterized job execution, promoting ease of integration and testing.
*   **Stateful Queue Management:** Assigns a unique `queue_id` to each workflow, allowing for granular tracking and control.
*   **Asynchronous Command Bus:** Utilizes Kafka topics (`queue-control`, `queue-events`) for a decoupled, event-driven command and control architecture.
*   **Comprehensive Observability:** Integrates with Prometheus for metrics and provides standardized health endpoints (`/health/live`, `/health/ready`, `/health/startup`) for Kubernetes-native monitoring.

## \[Environment Variables]

The service is configured via environment variables, following the 12-Factor App methodology. A `.env` file is used for local development.

```dotenv
# Kafka Connection Details
KAFKA_BOOTSTRAP_SERVERS=...
KAFKA_USER=...
KAFKA_PASSWORD=...
CA_PATH=...

# ArangoDB Connection Details
ARANGO_URL=...
ARANGO_DB=...
ARANGO_USER=...
ARANGO_PASSWORD=...

# Kafka Topic Definitions
QUEUE_CONTROL_TOPIC=queue-control
QUEUE_EVENTS_TOPIC=queue-events
```

## \[Project Structure]

The project follows a standard Python project structure, with a clear separation of concerns between API routes, business logic (services), data models, and infrastructure-related code (Kafka, metrics).

``` treeview
queue-manager/
├── app/
│   ├── __init__.py
│   ├── config.py
│   ├── main.py
│   ├── logging_config.py
│   ├── models/
│   │   ├── __init__.py
│   │   ├── base.py
│   │   ├── commands.py
│   │   ├── telemetry.py
│   ├── routes/
│   │   ├── __init__.py
│   │   ├── queues.py
│   │   ├── health.py
│   ├── services/
│   │   ├── __init__.py
│   │   ├── job_launcher.py
│   │   ├── arango_service.py
│   │   ├── telemetry_dispatcher.py
│   │   ├── queue_id_generator.py
│   ├── utils/
│   │   ├── __init__.py
│   │   ├── naming.py
│   │   ├── validators.py
│   ├── kafka/
│   │   ├── __init__.py
│   │   ├── kafka_command.py
│   │   ├── kafka_telemetry.py
│   ├── metrics/
│   │   ├── __init__.py
│   │   ├── prometheus_metrics.py
├── .env
├── Dockerfile
├── .gitlab-ci.yml
├── requirements.txt
└── README.md
```

## \[Example: Multiple Microservice Group Execution]

The service is capable of orchestrating complex, multi-step workflows involving several microservices from a single API request. This is achieved by accepting a list of `requests`, each targeting a specific microservice with its own set of parameters.

---

##  Data Schemas

### `QueueCreate`

This Pydantic model defines the contract for initiating a new data processing workflow. It captures the essential parameters required to launch a job.

```python
class QueueCreate(BaseModel):
    symbol: str        # The financial instrument to be processed, e.g., BTCUSDT
    type: str          # The data acquisition method: 'api', 'ws', or 'rest'
    time_range: str    # The inclusive date range for the data, in "YYYY-MM-DD:YYYY-MM-DD" format
```

**Example:**

```json
{
  "symbol": "BTCUSDT",
  "type": "api",
  "time_range": "2024-01-01:2024-01-03"
}
```

### `QueueState`

This model represents the complete state of a queue, as persisted in ArangoDB. It serves as a comprehensive record of the workflow's execution, including its status, timing, and any resulting artifacts or errors.

```python
class QueueState(BaseModel):
    id: str                      # Unique identifier for the queue
    symbol: str                  # The financial instrument being processed
    type: str                    # The data acquisition method
    status: str                  # The current status of the queue (e.g., loading, finished, stopped, error)
    loader_type: str             # The type of loader used (e.g., job, stream, connector)
    start_time: Optional[str]    # The start time of the data processing
    end_time: Optional[str]      # The end time of the data processing
    last_loaded_timestamp: Optional[str] # The timestamp of the last piece of data loaded
    records_written: int = 0     # The number of records written to the target
    error_message: Optional[str] # Any error message that occurred during processing
    kafka_topic: str             # The Kafka topic used for this queue
    started_at: Optional[datetime] # The timestamp when the queue was started
    finished_at: Optional[datetime]# The timestamp when the queue was finished
```

#  API Reference (FastAPI)

##  `POST /queues/start`

Initiates a new data processing workflow. This endpoint is the primary entry point for all data loading and processing tasks.

**Request Body:** `QueueCreate`

**Response:**

```json
{
  "status": "success",
  "message": "Queue started",
  "data": {
    "queue_id": "b927fa13-3b22-4d44-bc81-1f902a222eee"
  }
}
```

## ⏹ `POST /queues/stop`

Terminates an ongoing data processing workflow. This is achieved by updating the queue's status in ArangoDB, which is then acted upon by the running job.

**Query Param:**

```
?queue_id=b927fa13-3b22-4d44-bc81-1f902a222eee
```

**Response:**

```json
{
  "status": "success",
  "message": "Queue stopped",
  "data": {
    "queue_id": "b927fa13-3b22-4d44-bc81-1f902a222eee"
  }
}
```

##  `GET /queues`

Retrieves a list of all known queues, providing a high-level overview of all past and present data processing workflows.

**Response:**

```json
{
  "status": "success",
  "message": "Queues fetched",
  "data": [
    {
      "id": "b927fa13...",
      "symbol": "BTCUSDT",
      "status": "loading",
      ...
    },
    ...
  ]
}
```

##  `GET /queues/{queue_id}`

Fetches the detailed status of a specific queue, providing a granular view of its progress and any associated metadata.

**Response:**

```json
{
  "status": "success",
  "message": "Queue status",
  "data": {
    "id": "b927fa13...",
    "status": "finished",
    "records_written": 378,
    ...
  }
}
```

##  `GET /health/ready`

Provides a readiness probe for Kubernetes, indicating whether the service is ready to accept traffic. This can be extended to include checks for downstream dependencies like Kafka and ArangoDB.

**Response:**

```json
{
  "status": "success",
  "message": "All systems operational",
  "data": {}
}
```

##  `GET /metrics`

Exposes a wide range of operational metrics in a Prometheus-compatible format, enabling detailed monitoring and alerting on the service's performance.

**Example — Historical Data Processing Pipeline:**

```json
{
  "symbol": "BTCUSDT",
  "time_range": "2024-06-01:2024-06-30",
  "requests": [
    {
      "target": "loader-producer",
      "type": "api_candles_5m",
      "interval": "5m"
    },
    {
      "target": "loader-producer",
      "type": "api_trades"
    },
    {
      "target": "arango-connector",
      "type": "api_candles_5m"
    },
    {
      "target": "arango-connector",
      "type": "api_trades"
    },
    {
      "target": "graph-builder",
      "type": "gnn_graph",
      "collection_inputs": [
        "btc_candles_5m_2024_06",
        "btc_trades_2024_06"
      ],
      "collection_output": "btc_graph_2024_06"
    },
    {
      "target": "gnn-trainer",
      "type": "gnn_train",
      "graph_collection": "btc_graph_2024_06",
      "model_output": "gnn_model_btc_2024_06"
    }
  ]
}
```

**Example — Real-Time Data Processing Pipeline:**

```json
{
  "symbol": "BTCUSDT",
  "time_range": "2024-08-01:2024-08-01",
  "requests": [
    {
      "target": "loader-producer",
      "type": "ws_candles_1m"
    },
    {
      "target": "loader-producer",
      "type": "ws_trades"
    },
    {
      "target": "arango-connector",
      "type": "ws_candles_1m"
    },
    {
      "target": "arango-connector",
      "type": "ws_trades"
    },
    {
      "target": "graph-builder",
      "type": "realtime_graph",
      "collection_inputs": [
        "btc_ws_candles_1m_2024_08_01",
        "btc_ws_trades_2024_08_01"
      ],
      "collection_output": "btc_graph_rt_2024_08_01"
    },
    {
      "target": "gnn-trainer",
      "type": "realtime_gnn_infer",
      "graph_collection": "btc_graph_rt_2024_08_01",
      "inference_interval": "5m"
    },
    {
      "target": "visualizer",
      "type": "graph_metrics_stream",
      "source": "btc_graph_rt_2024_08_01"
    }
  ]
}
```

---

##  Storage: ArangoDB

*   **Collection:** `queue_state`
*   **Description:** This collection serves as the single source of truth for all data processing workflows. Each document in this collection represents a single queue and is updated throughout its lifecycle, from initiation to completion or failure.

---

##  Kafka Telemetry Dispatcher

The telemetry dispatcher is a background process that operates on an event-driven architecture, consuming messages from a Kafka topic to update the state of the system in real-time. Its responsibilities include:

*   **Asynchronous State Updates:** It consumes `type: telemetry` messages from the `queue-control` Kafka topic, allowing for non-blocking updates to the state of a queue.
*   **Database Persistence:** It updates the corresponding queue record in ArangoDB, ensuring that the system's state is always up-to-date.
*   **Real-time Notifications:** It broadcasts status updates to connected clients via WebSockets, providing a real-time view into the progress of each queue.

### `app/services/telemetry_dispatcher.py`

```python
# app/services/telemetry_dispatcher.py

import asyncio
from typing import Optional
from services.arango_service import update_queue_telemetry
from kafka.kafka_command import subscribe_commands
from api.routes import broadcast_log  # WebSocket
from logging_config import logger


async def start_telemetry_dispatcher():
    """
    Global listener for the `queue-control` Kafka topic.
    Only processes messages with type "telemetry".
    """
    logger.info(" Starting telemetry dispatcher...")

    async for message in subscribe_commands(queue_id="*", component="dispatcher"):
        if message.get("type") != "telemetry":
            continue

        try:
            await _handle_telemetry(message)
        except Exception as e:
            logger.error(f"Error processing telemetry: {e}")


async def _handle_telemetry(msg: dict):
    queue_id = msg.get("queue_id")
    status = msg.get("status")
    records = msg.get("records_written")
    finished_at = msg.get("finished_at")
    error_message = msg.get("error_message")

    logger.info(f" Telemetry: {queue_id} | status={status} | records={records}")

    #  Update ArangoDB
    await update_queue_telemetry(
        queue_id=queue_id,
        status=status,
        records_written=records,
        finished_at=finished_at,
        error_message=error_message,
    )

    #  Send to WebSocket clients
    await broadcast_log(f" Queue {queue_id} → {status} ({records or 0} records)")
```

### `app/services/arango_service.py` (addition)

This function is responsible for updating the state of a queue in ArangoDB. It is designed to be idempotent, ensuring that repeated updates do not have unintended side effects.

```python
async def update_queue_telemetry(
    queue_id: str,
    status: str,
    records_written: Optional[int] = None,
    finished_at: Optional[str] = None,
    error_message: Optional[str] = None,
):
    update = {"status": status}
    if records_written is not None:
        update["records_written"] = records_written
    if finished_at:
        update["finished_at"] = finished_at
    if error_message:
        update["error_message"] = error_message

    db.collection(QUEUE_COLLECTION).update_match({"_key": queue_id}, update)
```

### `app/api/routes.py` (addition)

This section of the code implements the WebSocket endpoint, which allows for real-time, bidirectional communication with clients. This is used to push status updates to the UI as they happen.

```python
from fastapi import WebSocket, WebSocketDisconnect
active_websockets = set()

@router.websocket("/ws/topic")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    active_websockets.add(websocket)
    try:
        await websocket.send_text(" WebSocket connected")
        while True:
            await asyncio.sleep(10)
            await websocket.send_text("heartbeat")
    except WebSocketDisconnect:
        active_websockets.remove(websocket)


async def broadcast_log(message: str):
    for ws in list(active_websockets):
        try:
            await ws.send_text(message)
        except:
            active_websockets.remove(ws)
```

### `app/main.py` (subscriber startup)

This is the main entry point for the application. It sets up the FastAPI application, includes the API router, configures Prometheus metrics, and starts the telemetry dispatcher as a background task.

```python
# app/main.py

from fastapi import FastAPI
from api.routes import router as api_router
from metrics.prometheus_metrics import setup_metrics
from services.telemetry_dispatcher import start_telemetry_dispatcher
import uvicorn
import asyncio

app = FastAPI(title="Queue Manager")

app.include_router(api_router)
setup_metrics(app)

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(start_telemetry_dispatcher())

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000)
```

---

#  Result

As a result of this architecture, the `queue-manager` is a robust, scalable, and observable service that is capable of orchestrating complex data processing workflows in a distributed environment. It effectively decouples the various components of the system, allowing for independent development, deployment, and scaling of each microservice.