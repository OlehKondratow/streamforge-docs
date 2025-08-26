+++
title = "Схемы данных и API"
type = "chapter"
weight = 1
+++

# 📘 Queue Manager – Справочник по схемам данных и API

## 📌 Назначение

`queue-manager` — это сервис FastAPI, который управляет жизненным циклом задач по загрузке данных (очередей). Он выполняет следующие функции:

*   Создает записи очередей в ArangoDB.
*   Запускает соответствующее задание Kubernetes.
*   Отслеживает статус и результаты.
*   Предоставляет API и метрики.

# \[Пакет] StreamForge Queue Manager

Микросервис управления для запуска, остановки и мониторинга очередей обработки данных в StreamForge.

## \[Возможности]

* Запуск заданий Kubernetes: `loader-producer`, `arango-connector`, `gnn-trainer`, `visualizer`, `graph-builder`
* Параметризованное выполнение через Swagger
* Управление очередью по `queue_id`
* Поддержка команд через Kafka (`queue-control`, `queue-events`)
* Поддержка метрик Prometheus
* Встроенные конечные точки работоспособности `/health/live`, `/health/ready`, `/health/startup`

## \[Переменные окружения]

Файл `.env`:

```dotenv
KAFKA_BOOTSTRAP_SERVERS=...
KAFKA_USER=...
KAFKA_PASSWORD=...
CA_PATH=...

ARANGO_URL=...
ARANGO_DB=...
ARANGO_USER=...
ARANGO_PASSWORD=...

QUEUE_CONTROL_TOPIC=queue-control
QUEUE_EVENTS_TOPIC=queue-events
```

## \[Структура проекта]

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

## \[Пример: Выполнение группы из нескольких микросервисов]

Сервис поддерживает запуск нескольких микросервисов в рамках одного запроса очереди.
Ниже приведены примеры допустимых полезных данных для различных сценариев.


---

## 🧩 Схемы данных

### `QueueCreate`

Модель для создания новой очереди (получаемая от клиента/API).

```python
class QueueCreate(BaseModel):
    symbol: str        # Название тикера, например, BTCUSDT
    type: str          # Тип источника: 'api', 'ws', 'rest'
    time_range: str    # Диапазон дат: "YYYY-MM-DD:YYYY-MM-DD"
```

**Пример:**

```json
{
  "symbol": "BTCUSDT",
  "type": "api",
  "time_range": "2024-01-01:2024-01-03"
}
```

### `QueueState`

Модель состояния очереди, хранящаяся в ArangoDB.

```python
class QueueState(BaseModel):
    id: str
    symbol: str
    type: str
    status: str                  # loading, finished, stopped, error, etc.
    loader_type: str             # job / stream / connector
    start_time: Optional[str]
    end_time: Optional[str]
    last_loaded_timestamp: Optional[str]
    records_written: int = 0
    error_message: Optional[str]
    kafka_topic: str
    started_at: Optional[datetime]
    finished_at: Optional[datetime]
```

---

# 🌐 Справочник по API (FastAPI)

## ▶️ `POST /queues/start`

Запускает новую очередь.

**Тело запроса:** `QueueCreate`

```json
{
  "symbol": "BTCUSDT",
  "type": "api",
  "time_range": "2024-01-01:2024-01-03"
}
```

**Ответ:**

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

Останавливает очередь по `queue_id` (обновляет статус в ArangoDB).

**Параметр запроса:**

```
?queue_id=b927fa13-3b22-4d44-bc81-1f902a222eee
```

**Ответ:**

```json
{
  "status": "success",
  "message": "Queue stopped",
  "data": {
    "queue_id": "b927fa13-3b22-4d44-bc81-1f902a222eee"
  }
}
```

## 📄 `GET /queues`

Возвращает список всех очередей.

**Ответ:**

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

## 🔍 `GET /queues/{queue_id}`

Получает статус конкретной очереди.

**Ответ:**

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

## ❤️ `GET /health/ready`

Проверка работоспособности (может быть расширена для проверки Kafka, ArangoDB, Binance).

**Ответ:**

```json
{
  "status": "success",
  "message": "All systems operational",
  "data": {}
}
```

## 📈 `GET /metrics`

Предоставляет метрики Prometheus.

```
# HELP http_requests_total Total HTTP requests
# HELP queue_requests_total Total number of queue-related API requests
...
```
**Пример — Конвейер обработки исторических данных:**

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

**Пример — Конвейер обработки данных в реальном времени:**

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

## 🧠 Хранилище: ArangoDB

*   **Коллекция:** `queue_state`
*   **Описание:** Документы создаются при запуске очереди и обновляются при событиях `stop`, `telemetry` и `error`.

---

## 📡 Диспетчер телеметрии Kafka

Диспетчер телеметрии отвечает за:

*   Чтение сообщений `type: telemetry` из топика Kafka `queue-control`.
*   Обновление записи очереди в ArangoDB.
*   Отправку логов в пользовательский интерфейс через WebSocket.

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
    Глобальный слушатель Kafka-топика `queue-control`.
    Обрабатывает только сообщения с типом "telemetry".
    """
    logger.info("📡 Запуск telemetry dispatcher...")

    async for message in subscribe_commands(queue_id="*", component="dispatcher"):
        if message.get("type") != "telemetry":
            continue

        try:
            await _handle_telemetry(message)
        except Exception as e:
            logger.error(f"❌ Ошибка обработки telemetry: {e}")


async def _handle_telemetry(msg: dict):
    queue_id = msg.get("queue_id")
    status = msg.get("status")
    records = msg.get("records_written")
    finished_at = msg.get("finished_at")
    error_message = msg.get("error_message")

    logger.info(f"📊 Telemetry: {queue_id} | status={status} | records={records}")

    # 📝 Обновляем ArangoDB
    await update_queue_telemetry(
        queue_id=queue_id,
        status=status,
        records_written=records,
        finished_at=finished_at,
        error_message=error_message,
    )

    # 🔁 Отправка WebSocket клиентам
    await broadcast_log(f"📡 Queue {queue_id} → {status} ({records or 0} records)")
```

### `app/services/arango_service.py` (дополнение)

Добавьте следующий метод в конец файла `arango_service.py`:

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

### `app/api/routes.py` (дополнение)

Убедитесь, что вы импортировали и используете следующее в `routes.py`:

```python
from fastapi import WebSocket, WebSocketDisconnect
active_websockets = set()

@router.websocket("/ws/topic")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    active_websockets.add(websocket)
    try:
        await websocket.send_text("✅ WebSocket connected")
        while True:
            await asyncio.sleep(10)
            await websocket.send_text("💓 heartbeat")
    except WebSocketDisconnect:
        active_websockets.remove(websocket)


async def broadcast_log(message: str):
    for ws in list(active_websockets):
        try:
            await ws.send_text(message)
        except:
            active_websockets.remove(ws)
```

### `app/main.py` (запуск подписчика)

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

# ✅ Результат

Теперь `queue-manager`:

*   Слушает топик Kafka `queue-control`.
*   Получает сообщения `telemetry` от `loader-producer`.
*   Обновляет `queue_state` в ArangoDB.
*   Отображает события в пользовательском интерфейсе через WebSocket.