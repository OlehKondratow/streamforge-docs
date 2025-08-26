+++
title = "Менеджер очередей"
type = "chapter"
weight = 1
+++

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

**Пример 1 — Конвейер обработки исторических данных:**

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

**Пример 2 — Конвейер обработки данных в реальном времени:**

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
