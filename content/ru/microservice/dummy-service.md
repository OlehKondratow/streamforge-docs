+++
title = "Dummy-service"
weight = 12
+++

# Микросервис для симуляции телеметрии и команд

`dummy-service` — это тестовый микросервис в экосистеме **StreamForge**, предназначенный для:

* Получения команд из Kafka (`queue-control`)
* Отправки событий (`started`, `pong`, `interrupted`, `finished`) в Kafka (`queue-events`)
* Симуляции загрузки и ошибок
* Логирования в структурированном формате JSON
* Предоставления метрик Prometheus через HTTP (`/metrics`)
* Запуска в Kubernetes как `Job`, `Pod`, `Deployment` или локально

---

## 1. Основные возможности

| Возможность | Описание |
| --- | --- |
| `ping/pong` | Отвечает на команду `ping`, отправляя `pong` с временной меткой |
| `stop` | Останавливается по команде, публикуя событие `interrupted` |
| `simulate-loading` | Периодически отправляет события `loading` в Kafka |
| `fail-after N` | Отправляет `error` и завершает работу через `N` секунд |
| `/metrics` | Экспортирует метрики Prometheus (счетчики событий, статус) |
| Логирование в JSON | Структурированные логи, совместимые с Fluent Bit / Loki |

---

## 2. Переменные окружения

| Переменная | Описание |
| --- | --- |
| `QUEUE_ID` | Уникальный идентификатор рабочего процесса (например, `loader-...`) |
| `SYMBOL` | Символ, например `BTCUSDT` |
| `TIME_RANGE` | Диапазон, например `2024-01-01:2024-01-02` |
| `TYPE` | Тип источника: `api`, `ws`, `dummy` и т.д. |
| `TELEMETRY_PRODUCER_ID` | Идентификатор сервиса в событиях телеметрии |
| `KAFKA_TOPIC` | Целевой топик Kafka |
| `QUEUE_EVENTS_TOPIC` | Топик Kafka для событий (обычно `queue-events`) |
| `QUEUE_CONTROL_TOPIC` | Топик Kafka для команд (обычно `queue-control`) |
| `KAFKA_BOOTSTRAP_SERVERS` | Адрес брокера Kafka |
| `KAFKA_USER` | Имя пользователя SCRAM |
| `KAFKA_PASSWORD` | Пароль SCRAM |
| `KAFKA_CA_PATH` | Путь к сертификату CA для TLS |
| `ARANGO_*` | Необязательные данные для подключения к ArangoDB |

---

## 3. Пример локального запуска

Чтобы запустить `dummy-service` локально (например, внутри devcontainer), перейдите в каталог сервиса и запустите его как модуль Python:

```bash
cd /data/projects/stream-forge/services/dummy-service/ 
python3.11 -m app.main \
  --debug \
  --simulate-loading \
  --exit-after 30
```

---

## 4. Тестирование с помощью `debug_producer.py`

`debug_producer.py` — это CLI-инструмент для отправки тестовых команд в топик Kafka `queue-control` и ожидания ответов из `queue-events`.
Он используется для отладки и тестирования микросервисов, которые общаются через Kafka.

### Примеры

**4.1 Тест подключения к Kafka (ping/pong)**

```bash
python3.11 debug_producer.py \
  --queue-id <your-queue-id> \
  --command ping \
  --expect-pong
```

**4.2 Тест команды Stop**

```bash
python3.11 debug_producer.py \
  --queue-id <your-queue-id> \
  --command stop
```

---

## 5. Поддерживаемые флаги `main.py`

| Флаг | Описание |
| --- | --- |
| `--debug` | Включает уровень логирования DEBUG |
| `--noop` | Отправляет только событие `started`, не запуская потребителя Kafka |
| `--exit-on-ping` | Завершает работу после получения `ping` и отправки `pong` |
| `--exit-after N` | Завершает работу через `N` секунд |
| `--simulate-loading` | Отправляет событие `loading` каждые 10 секунд |
| `--fail-after N` | Отправляет `error` и завершает работу через `N` секунд |

---

## 6. Метрики (`/metrics`)

Предоставляются на порту `8000` и включают:

* `dummy_events_total{event="started|pong|interrupted|..."}`
* `dummy_pings_total`, `dummy_pongs_total`
* `dummy_status_last{status="loading|interrupted|finished"}`

---

## 7. Пример точки входа `Dockerfile`

```dockerfile
CMD ["python3.11", "main.py", "--simulate-loading", "--exit-after", "30"]
```

---

## 8. Интеграция с Kubernetes

Рекомендуется запускать как `Job` или `Pod` с:

* `envFrom`: ConfigMap + Secret
* Volume mount для CA (`/usr/local/share/ca-certificates/ca.crt`)
* Подключение к Kafka через TLS + SCRAM

---

## 9. Использование в StreamForge

`dummy-service` можно использовать как:

* Эмулятор загрузчика (`loader`)
* Тест подключения к Kafka (`ping/pong`)
* Тест команд CI/CD (`stop`, `interrupted`)
* Инструмент для мониторинга метрик и логов в реальном времени

