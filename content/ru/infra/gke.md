+++
title = "Gke"
weight = 11
+++

## Введение

Эта конфигурация Terraform развертывает кластер Google Kubernetes Engine (GKE) Autopilot в Google Cloud Platform (GCP). Она создает пользовательскую VPC, подсеть с вторичными диапазонами для подов и сервисов, включает необходимые API и настраивает региональный кластер Autopilot. По умолчанию установка минималистична и экономична, что подходит для сред разработки.

**Примечание:** GKE Autopilot управляет пулами узлов автоматически; не создавайте ресурсы вручную в пространстве имен `kube-system`, так как оно управляется GKE.

## Предварительные требования

- Учетная запись Google Cloud Platform (GCP) с включенным платежным аккаунтом (даже для использования бесплатного уровня; проверьте лимиты бесплатного уровня GCP).
- Установленный Terraform (версия >= 1.6).
- Установленный и аутентифицированный Google Cloud SDK (`gcloud`) с помощью `gcloud auth login`.
- Установленный kubectl для взаимодействия с Kubernetes.
- Идентификатор проекта GCP (устанавливается в `terraform.tfvars`).
- Персональный токен доступа GitLab с правами `api`, `read_repository` и `write_repository` для управления состоянием Terraform.

## Структура каталогов

Файлы конфигурации находятся в `infra/live/dev/gke/`:

- `versions.tf`: Указывает версии Terraform и провайдеров.
- `variables.tf`: Определяет входные переменные со значениями по умолчанию.
- `providers.tf`: Настраивает провайдер Google.
- `apis.tf`: Включает необходимые API GCP.
- `network.tf`: Создает VPC и подсеть.
- `cluster.tf`: Развертывает кластер GKE Autopilot.
- `outputs.tf`: Определяет выходные данные, такие как имя кластера и подсказки для подключения.
- `terraform.tfvars`: Пример значений переменных (настройте под свой идентификатор проекта и токен доступа GitLab).
- `backend.tf`: Настраивает бэкенд GitLab HTTP для управления состоянием Terraform.

## Установка и развертывание

Эта конфигурация использует бэкенд GitLab HTTP для хранения состояния Terraform.

1.  **Настройте бэкенд GitLab HTTP (`backend.tf`):**
    Убедитесь, что ваш файл `backend.tf` в `infra/live/dev/gke/` содержит следующее:

    ```terraform
    terraform {
      backend "http" {
      }
    }
    ```

2.  **Инициализируйте Terraform:**
    При инициализации Terraform необходимо указать данные бэкенда GitLab, включая аутентификацию. Замените `glpat-YOUR_ACCESS_TOKEN` вашим фактическим персональным токеном доступа GitLab.

    ```bash
    terraform -chdir=infra/live/dev/gke init \
      -reconfigure \
      -force-copy \
      -backend-config="address=https://gitlab.dmz.home/api/v4/projects/136/terraform/state/gke-dev" \
      -backend-config="lock_address=https://gitlab.dmz.home/api/v4/projects/136/terraform/state/gke-dev/lock" \
      -backend-config="unlock_address=https://gitlab.dmz.home/api/v4/projects/136/terraform/state/gke-dev/lock" \
      -backend-config="lock_method=POST" \
      -backend-config="unlock_method=DELETE" \
      -backend-config="username=kinga" \
      -backend-config="password=glpat-YOUR_ACCESS_TOKEN"
    ```
    *   `-reconfigure`: Повторно инициализирует конфигурацию бэкенда.
    *   `-force-copy`: Автоматически отвечает "да" на запросы о копировании существующего состояния в новый бэкенд. Это полезно для начальной настройки или миграции локального состояния.
    *   `username` и `password`: Используются для аутентификации с бэкендом GitLab HTTP. Паролем должен быть ваш персональный токен доступа GitLab.

3.  **Просмотрите план:**
    ```bash
    terraform -chdir=infra/live/dev/gke plan
    ```

4.  **Примените конфигурацию:**
    ```bash
    terraform -chdir=infra/live/dev/gke apply -auto-approve
    ```
    Это создаст VPC, включит API и развернет кластер GKE. Следите за выводом на предмет ошибок.

## Использование

После развертывания Terraform выведет:
- `cluster_name`: Имя кластера GKE.
- `cluster_region`: Регион кластера.
- `get_credentials_hint`: Готовая к использованию команда `gcloud` для настройки kubectl.

Пример вывода:
```
cluster_name = "gke-free-autopilot"
cluster_region = "us-central1"
get_credentials_hint = "gcloud container clusters get-credentials gke-free-autopilot --region us-central1 --project stream-forge-4"
```

## Доступ к кластеру

1.  **Настройте kubectl:**
    Выполните команду из вывода `get_credentials_hint`, чтобы обновить локальный kubeconfig:
    ```bash
    gcloud container clusters get-credentials ${cluster_name} --region ${cluster_region} --project ${project_id}
    ```
    Замените заполнители фактическими значениями.

2.  **Проверьте доступ:**
    ```bash
    kubectl get nodes
    ```
    Это должно вывести список узлов, управляемых Autopilot.

3.  **Взаимодействуйте с кластером:**
    Используйте команды `kubectl` для развертывания приложений, управления ресурсами и т.д.

## Дымовой тест

Чтобы убедиться, что кластер работает:

1.  Сохраните следующий YAML как `smoke-test.yaml`:
    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: smoke-test-nginx
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: nginx
      template:
        metadata:
          labels:
            app: nginx
        spec:
          containers:
          - name: nginx
            image: nginx:alpine
            resources:
              requests:
                cpu: "100m"
                memory: "128Mi"
              limits:
                cpu: "100m"
                memory: "128Mi"
            ports:
            - containerPort: 80
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: smoke-test-nginx
    spec:
      type: ClusterIP
      selector:
        app: nginx
      ports:
      - port: 80
        targetPort: 80
    ```

2.  Примените манифест:
    ```bash
    kubectl apply -f smoke-test.yaml
    ```

3.  Пробросьте порт для локального доступа:
    ```bash
    kubectl port-forward svc/smoke-test-nginx 8080:80
    ```
    Откройте http://localhost:8080 в браузере, чтобы увидеть страницу приветствия nginx. Нажмите Ctrl+C, чтобы остановить.

4.  Очистка:
    ```bash
    kubectl delete -f smoke-test.yaml
    ```

## Очистка

Чтобы уничтожить ресурсы:
```bash
terraform -chdir=infra/live/dev/gke destroy -auto-approve
```

## Заметки по управлению состоянием Terraform в GitLab

Этот раздел содержит дополнительную информацию и советы по устранению неполадок при управлении состоянием Terraform с помощью GitLab.

### `terraform.tfvars` и `gitlab_access_token`

У вас может быть переменная `gitlab_access_token`, определенная в вашем файле `terraform.tfvars` (например, `infra/live/dev/gke/terraform.tfvars`). Если в вашей конфигурации Terraform нет соответствующего блока `variable "gitlab_access_token"`, вы можете увидеть предупреждение, подобное этому:

```
Warning: Value for undeclared variable

The root module does not declare a variable named "gitlab_access_token" but
a value was found in file "terraform.tfvars". If you meant to use this
value, add a "variable" block to the configuration.
```
Это предупреждение, и оно не мешает работе Terraform, особенно если токен в основном используется для аутентификации бэкенда через флаги командной строки.

### Обработка блокировок состояния

Terraform устанавливает блокировку состояния для предотвращения одновременных изменений. Если команда `terraform init` или `terraform apply` завершается сбоем или прерывается, состояние может остаться заблокированным.

Если вы столкнулись с ошибкой "Error acquiring the state lock", вам потребуется вручную снять блокировку в пользовательском интерфейсе GitLab:

1.  Перейдите в свой проект GitLab.
2.  Перейдите в **Operate** -> **Terraform states**.
3.  Найдите соответствующее состояние (например, `gke-dev`).
4.  Если присутствует активная блокировка, используйте опцию "Unlock" или "Clear lock", чтобы снять ее.

После снятия блокировки повторно выполните команду `terraform init`.

## Выводы:

```
cluster_name = "gke-free-autopilot"
cluster_region = "us-central1"
get_credentials_hint = "gcloud container clusters get-credentials gke-free-autopilot --region us-central1 --project stream-forge-4"

```

# Модуль GKE

Этот каталог содержит модуль Terraform для предоставления кластера Google Kubernetes Engine (GKE).

## Возможности

- Развертывает кластер GKE с настраиваемыми параметрами.
- Управляет пулами узлов, сетью и другими ресурсами, связанными с кластером.

## Использование

Чтобы использовать этот модуль, включите его в свою конфигурацию Terraform:

```terraform
module "gke_cluster" {
  source = "./modules/gke"

  project_id   = var.project_id
  region       = var.region
  cluster_name = "my-gke-cluster"
  # ... другие переменные
}
```

## Входные данные

| Имя | Описание | Тип | По умолчанию |
|--------------|-------------------------------------------|----------|---------|
| `project_id` | Идентификатор проекта GCP. | `string` | n/a |
| `region` | Регион GCP для кластера GKE. | `string` | n/a |
| `cluster_name` | Имя кластера GKE. | `string` | n/a |
| `node_locations` | Список зон, в которых расположены узлы кластера. | `list(string)` | `[]` |
| `initial_node_count` | Количество узлов в кластере. | `number` | `1` |

## Выходные данные

| Имя | Описание |
|------------------|-------------------------------------------|
| `cluster_name` | Имя созданного кластера GKE. |
| `cluster_endpoint` | Конечная точка кластера GKE. |
| `kubeconfig` | Kubeconfig для подключения к кластеру. |
