+++
date = '2025-08-24T20:26:06+02:00'
draft = true
title = 'Szczegóły techniczne'
weight = 5
+++

## Część V: Szczegóły techniczne i dodatki

Ta sekcja zawiera szczegółowe specyfikacje techniczne, przykłady konfiguracji i przewodniki operacyjne przeznaczone do dogłębnego przestudiowania architektury i implementacji platformy StreamForge.

### Dodatek A: Schematy danych i API

Ten dodatek zawiera pełną specyfikację techniczną interfejsu API `queue-manager`, w tym szczegółowe schematy JSON dla wszystkich typów komunikatów wymienianych za pośrednictwem Apache Kafka. Informacje te są niezbędne dla programistów i architektów systemów wymagających kompleksowego zrozumienia wewnętrznych struktur danych i interakcji komponentów.

### Dodatek B: Przykłady manifestów Kubernetes

Ten dodatek zawiera przykładowe manifesty Kubernetes, które ilustrują wdrażanie i konfigurację różnych komponentów StreamForge w klastrze.

#### Przykład: Zadanie Kubernetes dla `arango-candles`

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job-arango-candles-btcusdt-abc123
  namespace: stf
  labels:
    app: streamforge
    queue_id: "wf-btcusdt-api_candles_1m-20240801-abc123"
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: arango-candles
          image: registry.dmz.home/streamforge/arango-candles:v0.1.5
          env:
            - name: QUEUE_ID
              value: "wf-btcusdt-api_candles_1m-20240801-abc123"
            - name: SYMBOL
              value: "BTCUSDT"
            - name: TYPE
              value: "api_candles_1m"
            - name: KAFKA_TOPIC
              value: "wf-btcusdt-api_candles_1m-20240801-abc123-data"
            - name: COLLECTION_NAME
              value: "btcusdt_api_candles_1m_2024_08_01"
            # ... inne zmienne z ConfigMap i Secret ...
      nodeSelector:
        streamforge-worker: "true" # Przykładowy selektor dla dedykowanych węzłów
  backoffLimit: 2
  ttlSecondsAfterFinished: 3600
```

### Dodatek C: Szczegóły potoku CI/CD i najlepsze praktyki

W tym dodatku szczegółowo opisano znormalizowane procesy CI/CD wdrożone na platformie StreamForge, podkreślając najlepsze praktyki stosowane w celu wydajnego i spójnego rozwoju, budowania i wdrażania mikroserwisów.

**Kluczowe zasady i wdrożenia:**

*   **Ujednolicony obraz bazowy dla usług i testów:** Pojedynczy, kompleksowy obraz bazowy Docker (`registry.dmz.home/kinga/stream-forge/base:latest`, zbudowany z `platform/Dockerfile`) jest wykorzystywany we wszystkich usługach Pythona zarówno do obsługi aplikacji, jak i do testowania. Ten obraz preinstaluje popularne zależności Pythona, w tym wszystkie niezbędne frameworki testowe (np. `pytest`, `httpx`, `python-arango`) i integruje bibliotekę `streamforge_utils` za pomocą solidnej instalacji koła. Takie podejście zapewnia spójność środowiska, skraca czas budowy i upraszcza zarządzanie zależnościami.

*   **Zoptymalizowane kompilacje Kaniko:** Kompilacje obrazów kontenerów wykorzystują `kaniko` do bezpiecznych operacji bezdemonicznych bezpośrednio w klastrze Kubernetes. Procesy budowania są zoptymalizowane poprzez:
    *   Użycie katalogu głównego projektu (`$CI_PROJECT_DIR`) jako kontekstu budowy, co pozwala plikom Dockerfile na wydajny dostęp do współdzielonych bibliotek i zasobów w całym repozytorium.
    *   Wdrożenie jawnego buforowania warstw obrazu (`--cache=true --cache-repo "$CI_REGISTRY_IMAGE/cache"`) w celu znacznego przyspieszenia kolejnych kompilacji poprzez ponowne wykorzystanie niezmienionych warstw.

*   **Usprawnione testowanie:** Testy jednostkowe i integracyjne są wykonywane w ramach ujednoliconego obrazu bazowego, korzystając z preinstalowanych zależności testowych. Eliminuje to zbędne instalacje zależności podczas wykonywania potoku, co prowadzi do szybszych i bardziej niezawodnych cykli testowych.

*   **Modułowa konfiguracja CI/CD:** Konfiguracja CI/CD jest ustrukturyzowana za pomocą wspólnych szablonów (np. `.build_python_service` w `.gitlab/ci-templates/Python-Service.gitlab-ci.yml`), które są rozszerzane przez określone potoki dla każdego mikroserwisu. Ta modułowość promuje ponowne wykorzystanie, upraszcza konserwację i zapewnia spójne stosowanie najlepszych praktyk CI/CD na całej platformie.


### Dodatek D: Słowniczek terminów

Ten słowniczek zawiera definicje kluczowych terminów i pojęć używanych w całej dokumentacji StreamForge, w tym takich terminów jak przepływ pracy, zadanie, oddzielenie i idempotencja, aby zapewnić spójne i technicznie dokładne zrozumienie.

### Dodatek E: Przewodnik po wdrażaniu i obsłudze

Ten przewodnik zawiera instrukcje krok po kroku dotyczące wdrażania platformy StreamForge od podstaw, a także zalecenia dotyczące najlepszych praktyk w zakresie monitorowania, procedur tworzenia kopii zapasowych i aktualizacji systemu, zapewniając kompleksowe zarządzanie cyklem życia.

### Dodatek F: Procedura testowania

Testowanie funkcjonalne i integracyjne systemu StreamForge jest ułatwione dzięki zestawowi specjalistycznych narzędzi, w tym `dummy-service` i `debug_producer.py`. Narzędzia te są najskuteczniej wykorzystywane w znormalizowanym środowisku programistycznym `devcontainer`.

**1. `dummy-service`: Mikroserwis diagnostyczny i symulacyjny**

`dummy-service` ma na celu symulowanie zachowania różnych usług, weryfikację łączności z Apache Kafka i symulowanie różnych scenariuszy obciążenia.

*   **Uruchomienie:** Usługę można uruchomić w Kubernetes jako `Job` lub `Pod`. Do testowania lokalnego w `devcontainer` używana jest następująca komenda:
    ```bash
    python3.11 -m app.main --debug --simulate-loading
    ```
*   **Dalsze informacje:** Szczegółowy opis jest dostępny w `services/dummy-service/README.md`.

**2. `debug_producer.py`: Interfejs wiersza poleceń do wstrzykiwania poleceń i walidacji odpowiedzi**

To narzędzie CLI służy do wysyłania poleceń testowych (`ping`, `stop`) do Apache Kafka, a następnie weryfikowania otrzymanych odpowiedzi.

*   **Testowanie łączności z Kafką (ping/pong):**
    ```bash
    python3.11 services/dummy-service/debug_producer.py \
      --queue-id <your-queue-id> \
      --command ping \
      --expect-pong
    ```
*   **Testowanie polecenia zatrzymania (stop):**
    ```bash
    python3.11 services/dummy-service/debug_producer.py \
      --queue-id <your-queue-id> \
      --command stop
    ```
*   **Testowanie symulacji obciążenia i śledzenia stanu:** Uruchomienie `dummy-service` z flagą `--simulate-loading` pozwala na monitorowanie zdarzeń w temacie `queue-events`.

*   **Testowanie symulacji awarii:** Uruchomienie `dummy-service` z parametrem `--fail-after N` pozwala na obserwację wysyłania zdarzeń `error`.
*   **Testowanie metryk Prometheus:** Metryki są sprawdzane za pomocą `curl localhost:8000/metrics`.

**3. `devcontainer`: Znormalizowane środowisko programistyczne**

Specyfikacja `devcontainer` służy do udostępniania kompletnego, samodzielnego środowiska programistycznego w kontenerze Docker, ściśle zintegrowanego z VS Code. Takie podejście gwarantuje spójne i odtwarzalne środowisko dla wszystkich programistów projektu.

**Kluczowe cechy:**
*   **Obraz bazowy:** Ubuntu 22.04 LTS.
*   **Narzędzia:** Zawiera preinstalowane narzędzia, takie jak `kubectl`, Helm, `gitlab-runner`, `git`, `curl`, `ssh` i inne.
*   **Dostęp do Kubernetes:** Automatyczna konfiguracja dostępu do klastra Kubernetes.
*   **Użytkownicy i SSH:** Utworzenie oddzielnego użytkownika i konfiguracja dostępu SSH.
*   **Certyfikaty:** Instalacja certyfikatów CA w celu zapewnienia zaufania do usług wewnętrznych.

**Instrukcje użytkowania:**
1.  Zainstaluj Docker Desktop i rozszerzenie „Dev Containers” dla VS Code.
2.  Otwórz projekt StreamForge w VS Code i wybierz „Reopen in Container”.
3.  VS Code automatycznie zbuduje obraz i uruchomi kontener.

### Dodatek G: Zarządzanie zasobami Kafki

Manifesty Kubernetes znajdujące się w katalogu `cred-kafka-yaml/` służą do deklaratywnego zarządzania zasobami Apache Kafka za pośrednictwem operatora Strimzi. Obejmuje to tworzenie tematów (`queue-control`, `queue-events`), zarządzanie użytkownikami Kafki (`user-streamforge`) i ich listami kontroli dostępu (ACL) oraz bezpieczne zarządzanie poświadczeniami za pośrednictwem wpisów tajnych Kubernetes.

### Dodatek H: Środowisko debugowania Kubernetes

Do debugowania w klastrze i sesji interaktywnych StreamForge wykorzystuje następujące narzędzia i metodologie:

*   **JupyterHub:** Umożliwia udostępnianie na żądanie interaktywnych sesji Jupyter Notebook bezpośrednio w klastrze Kubernetes. Obrazy kontenerów używane do tych sesji są wstępnie skonfigurowane z niezbędnymi narzędziami wiersza poleceń, w tym `kubectl` i `helm`.

    **Kluczowe cechy konfiguracji JupyterHub:**
    *   **Zarządzanie bezczynnymi serwerami:** Automatyczne kończenie bezczynnych serwerów Jupyter w celu optymalizacji wykorzystania zasobów.
    *   **Uwierzytelnianie:** Do środowiska testowego używana jest prosta, „fikcyjna” metoda uwierzytelniania.
    *   **Baza danych podstawowa:** Używana jest baza `sqlite-memory`, ale dane są utrwalane na hoście.
    *   **Umieszczanie zasobników:** Serwery koncentratora i użytkownika są uruchamiane na węźle `k2w-8`.
    *   **Dostęp:** Za pośrednictwem Ingress pod adresem `jupyterhub.dmz.home` z TLS.
    *   **Obrazy serwerów użytkowników:** Używany jest niestandardowy obraz `registry.dmz.home/streamforge/core-modules/jupyter-python311:v0.0.2` z niezbędnymi narzędziami.
    *   **Zasoby:** Gwarantowana alokacja pamięci dla każdego serwera — `1G`.
    *   **Przechowywanie danych:** Do `/home/`, `/data/project`, `/data/venv` używane są woluminy trwałe zamontowane z hosta.
    *   **Bezpieczeństwo:** Zasobniki są uruchamiane z `UID: 1001` i `FSGID: 100`.
    *   **Rejestr Docker:** Do uwierzytelniania używany jest wpis tajny `regcred`.

*   **Kontener deweloperski (VS Code):** Szczegółowo opisany w dodatku F.

*   **Kontener debugowania ogólnego przeznaczenia:** Utrzymywany jest obraz Docker ogólnego przeznaczenia, zawierający szeroką gamę narzędzi (`kubectl`, `helm`, `kafkacat`, `python`). Ten obraz można wdrożyć jako efemeryczny zasobnik (`kubectl run -it ...`) do interaktywnego debugowania i zadań administracyjnych bezpośrednio w klastrze.