+++
title = "Observability"
type = "chapter"
weight = 1
+++

# Архитектура централизованного логирования в GKE Autopilot

Этот репозиторий содержит полный набор артефактов для развертывания производственной системы логирования для GKE Autopilot кластеров с использованием Google Cloud Logging и Cloud Monitoring.

## 1. Обзор архитектуры

GKE Autopilot автоматически интегрирован с Cloud Logging. Вся стандартная выдача (`stdout`) и поток ошибок (`stderr`) из ваших контейнеров собираются и отправляются в Cloud Logging без необходимости установки агентов, DaemonSet'ов или использования `hostPath`.

Наша архитектура строится поверх этого, настраивая Cloud Logging для эффективного хранения, анализа и маршрутизации логов:

- **Структурированные логи (JSON):** Приложения пишут логи в формате JSON в `stdout`/`stderr`. Cloud Logging автоматически парсит их, делая поля доступными для фильтрации и анализа.
- **Log Buckets:** Мы создаем два кастомных бакета для разделения логов по сроку хранения: один для оперативных логов (30 дней) и один для долгосрочного хранения (365 дней).
- **Log Views:** Для разграничения доступа мы используем Log Views, которые предоставляют командам доступ только к логам их сервисов.
- **Log Sinks:** Для долгосрочного архивирования, аналитики и интеграций мы настраиваем экспорты (sinks) в BigQuery, Cloud Storage и Pub/Sub.
- **Log Exclusions:** Для оптимизации затрат мы исключаем "шумные" и низкоприоритетные логи (например, health checks) из обработки.
- **Logs-based Metrics & Alerts:** Мы создаем метрики на основе логов (например, количество 5xx ошибок) и настраиваем алерты для проактивного мониторинга.

## 2. Компоненты

- **Terraform (`infra/live/dev/logging/`):** Управляет всеми ресурсами GCP (Log Buckets, Sinks, IAM, метрики, алерты).
- **Примеры приложений (`samples/logging/`):** Демонстрируют, как писать структурированные логи на Python, Go и Node.js.
- **Kubernetes-манифесты (`k8s/smoke/`):** Используются для развертывания тестового приложения в кластер для проверки системы логирования.

## 3. Пошаговый запуск

### Шаг 1: Настройка Terraform

1.  Перейдите в каталог с Terraform-кодом:
    ```bash
    cd infra/live/dev/logging/
    ```

2.  Создайте файл `terraform.tfvars` из примера:
    ```bash
    cp terraform.tfvars.example terraform.tfvars
    ```

3.  Заполните `terraform.tfvars` вашими значениями (`project_id`, `region`, `cluster_name` и т.д.).

4.  Аутентифицируйтесь в GCP:
    ```bash
    gcloud auth application-default login
    gcloud config set project <MY_GCP_PROJECT_ID>
    ```

5.  Инициализируйте и примените Terraform:
    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

### Шаг 2: Деплой тестового приложения

1.  Убедитесь, что ваш `kubectl` настроен на работу с вашим GKE Autopilot кластером.
    ```bash
    gcloud container clusters get-credentials <MY_GKE_AUTOPILOT_CLUSTER> --region <MY_REGION>
    ```

2.  Разверните тестовые манифесты:
    ```bash
    kubectl apply -f ../../../../k8s/smoke/
    ```

3.  Сгенерируйте трафик, чтобы появились логи. Пробросьте порт и вызовите эндпоинты:
    ```bash
    # В одном терминале
    kubectl port-forward -n logging-smoke-test svc/sample-logger-py 8080:80

    # В другом терминале
    # Успешный запрос
    curl http://localhost:8080/work
    # Запрос с ошибкой
    curl http://localhost:8080/work?error=true
    # Health check (будет исключен из логов)
    curl http://localhost:8080/healthz
    ```

### Шаг 3: Проверка логов

Используйте ссылки и команды из `terraform apply` или перейдите в **Logs Explorer**.

**Примеры фильтров в Logs Explorer:**

-   **Показать все логи тестового сервиса:**
    ```
    resource.type="k8s_container"
    resource.labels.cluster_name="<MY_GKE_AUTOPILOT_CLUSTER>"
    resource.labels.namespace_name="logging-smoke-test"
    labels.k8s-pod/app="sample-logger-py"
    ```
-   **Показать только ошибки (severity ERROR):**
    ```
    resource.type="k8s_container"
    resource.labels.namespace_name="logging-smoke-test"
    severity="ERROR"
    ```
-   **Найти лог по ID трассировки:**
    ```
    resource.type="k8s_container"
    jsonPayload.trace="00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
    ```

### Шаг 4: Проверка метрик и алертов

1.  **Сгенерируйте ошибки 5xx:** Выполните несколько раз `curl http://localhost:8080/work?error=true`.
2.  **Проверьте метрику:** Перейдите в **Metrics Explorer** и найдите метрику `logging.googleapis.com/user/http_5xx_count`.
3.  **Проверьте алерт:** Через несколько минут (согласно настройкам в `monitoring_alerts.tf`) должен сработать алерт и прийти уведомление на указанный канал.

## 4. Оптимизация стоимости

-   **Исключения (Exclusions):** Самый эффективный способ снизить затраты — исключить ненужные логи. Мы уже настроили исключения для health-чеков. Добавляйте новые правила в `logging_exclusions.tf` для "болтливых" сервисов или логов уровня DEBUG.
-   **Сроки хранения (Retention):** Используйте бакеты с разным сроком хранения. Оперативные логи держите в `default-app-logs` (30 дней), а менее важные или архивные — в `long-app-logs` (365 дней), либо экспортируйте в GCS/BigQuery, что дешевле для долгосрочного хранения.
-   **Сэмплирование:** Для логов уровня DEBUG в dev-окружении можно настроить сэмплирование на уровне приложения или через более сложные фильтры в `logging_exclusions.tf`.

## 5. Безопасность

-   **CMEK (Customer-Managed Encryption Keys):** Если вы указали `kms_key` в `terraform.tfvars`, все Log Buckets будут зашифрованы вашим ключом, что дает вам полный контроль над ключами шифрования данных.
-   **Доступ через Log Views:** Мы не даем прямой доступ к логам. Вместо этого мы создаем `Log Views` для каждой команды и предоставляем IAM-роль `roles/logging.viewAccessor` только на конкретный View. Это гарантирует, что команды видят только логи своих приложений.