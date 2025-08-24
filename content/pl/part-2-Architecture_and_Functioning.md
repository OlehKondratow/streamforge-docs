+++
date = '2025-08-24T20:22:28+02:00'
draft = true
title = 'Architektura i funkcjonowanie'
weight = 2
+++
## Część II: Architektura i funkcjonowanie

### Rozdział 2: Architektura wysokiego poziomu

#### 2.1. Podstawowe zasady architektoniczne

Architektura StreamForge została zaprojektowana w oparciu o kilka podstawowych zasad, aby zapewnić elastyczną, niezawodną i skalowalną platformę:

1.  **Oddzielenie za pomocą modelu sterowanego zdarzeniami:**
    Sercem StreamForge jest model sterowany zdarzeniami, w którym Apache Kafka pełni rolę centralnej magistrali komunikatów. To fundamentalnie oddziela usługi od siebie. `queue-manager` inicjuje przepływ pracy (np. ładowanie danych BTC), a odpowiednie mikroserwisy (takie jak `loader-producer`) reagują na te zdarzenia. Ten paradygmat umożliwia niezależny rozwój, wdrażanie i skalowanie każdego mikroserwisu, wspierając ogólnosystemową odporność i zwinność.

2.  **Skalowalność:**
    Platforma została zaprojektowana z myślą o dynamicznym dostosowywaniu obciążenia. Aplikacje bezstanowe, takie jak `loader-*` i `arango-connector`, są wdrażane jako efemeryczne zadania Kubernetes. Taka konstrukcja pozwala na wykonywanie zadań na żądanie, równolegle, zapewniając wrodzoną skalowalność. W przyszłych iteracjach zostanie zintegrowana **KEDA (Kubernetes Event-driven Autoscaling)**, aby umożliwić proaktywne skalowanie konsumentów w oparciu o zaległości w tematach Kafki, co dodatkowo zoptymalizuje wykorzystanie zasobów.

3.  **Obserwowalność:**
    Solidny stos obserwowalności jest integralną częścią architektury, zapewniając głęboki wgląd w system rozproszony:
    *   **Metryki:** Mikroserwisy eksportują metryki do Prometheus, które są następnie wizualizowane w Grafanie. Obejmuje to zarówno wskaźniki na poziomie systemu (procesor, pamięć), jak i metryki biznesowe (liczba przetworzonych rekordów, opóźnienia).
    *   **Logowanie:** Scentralizowane gromadzenie logów odbywa się za pomocą Fluent-bit, z późniejszą analizą i wizualizacją w Elasticsearch i Kibanie.
    *   **Telemetria na poziomie biznesowym:** Dedykowany temat `queue-events` zapewnia kompleksowe śledzenie procesów biznesowych. Rejestruje on pełny cykl życia każdego przepływu pracy, logując przejścia stanów od inicjacji do zakończenia lub błędu, we wszystkich uczestniczących mikroserwisach.

#### 2.2. Przepływ danych w systemie

Poniższy diagram ilustruje przepływ danych dla typowego przepływu pracy pozyskiwania danych historycznych w ekosystemie StreamForge:

**Opis procesu krok po kroku:**
1.  **Inicjacja przepływu pracy:** Użytkownik lub zautomatyzowany proces inicjuje przepływ pracy przetwarzania danych za pośrednictwem żądania do interfejsu API `queue-manager`.
2.  **Rejestracja stanu:** `queue-manager` rejestruje nowy przepływ pracy w ArangoDB, przypisując mu unikalny `queue_id` i początkowy status `pending`.
3.  **Wysłanie polecenia:** Polecenie `start`, zawierające wszystkie niezbędne parametry zadania, jest publikowane przez `queue-manager` w temacie `queue-control` w Apache Kafka.
4.  **Utworzenie instancji zadania:** `queue-manager` generuje wymagane manifesty zadań Kubernetes, które są następnie planowane do wykonania, uruchamiając niezbędne pody mikroserwisów (np. `loader-producer`, `arango-connector`).
5.  **Konsumpcja polecenia:** Nowo utworzone mikroserwisy konsumują polecenie `start` z tematu `queue-control`, które odpowiada ich przypisanemu `queue_id`.
6.  **Pozyskiwanie danych:** Usługa `loader-producer` nawiązuje połączenie z zewnętrznym źródłem danych (np. Binance API) i rozpoczyna pobieranie danych.
7.  **Publikacja zdarzeń:** `loader-producer` serializuje pozyskane dane do dyskretnych komunikatów i publikuje je w dedykowanym temacie danych w Kafce (np. `btc-klines-1m`).
8.  **Raportowanie telemetrii:** W trakcie swojego cyklu życia wszystkie aktywne usługi (`loader-producer`, `arango-connector`) publikują aktualizacje statusu (np. `loading`, `completed`, `error`) w temacie `queue-events`, zapewniając wgląd w postęp w czasie rzeczywistym.
9.  **Konsumpcja danych w celu utrwalenia:** Usługa `arango-connector` subskrybuje odpowiedni temat danych i konsumuje strumień zdarzeń.
10. **Utrwalanie danych:** `arango-connector` przetwarza i utrwala dane w wyznaczonych kolekcjach w bazie danych ArangoDB.
11. **Monitorowanie i ukończenie przepływu pracy:** `queue-manager` stale monitoruje temat `queue-events`, aktualizując status przepływu pracy w ArangoDB na podstawie otrzymanej telemetrii. Zapewnia to kompletny, audytowalny ślad procesu w czasie rzeczywistym.

### Rozdział 3: Apache Kafka jako centralny komponent

Apache Kafka jest centralnym układem nerwowym architektury StreamForge, zapewniając kluczowe korzyści paradygmatu sterowanego zdarzeniami:

*   **Oddzielenie i asynchroniczność:** Usługi działają z pełną autonomią. Producenci (np. `loader-producer`) publikują zdarzenia w Kafce bez żadnej świadomości ani zależności od konsumentów (np. `arango-connector`). To czasowe oddzielenie pozwala na niezależne opracowywanie, wdrażanie i skalowanie komponentów oraz umożliwia systemowi absorbowanie gwałtownych wzrostów danych bez wpływu na usługi podrzędne.
*   **Odporność i trwałość:** Kafka funkcjonuje jako rozproszony, trwały dziennik. W przypadku awarii usługi konsumującej komunikaty są bezpiecznie przechowywane w temacie. Po odzyskaniu usługa może wznowić przetwarzanie od ostatniego znanego przesunięcia, gwarantując co najmniej jednokrotne dostarczenie i zapobiegając utracie danych.
*   **Skalowalność i rozszerzalność:** Model sterowany zdarzeniami pozwala na płynne skalowanie poziome. Nowe instancje usługi można dodawać do grupy konsumentów w celu zwiększenia przepustowości przetwarzania. Ponadto architektura jest z natury rozszerzalna; nowe funkcje można wprowadzać, wdrażając nowe mikroserwisy, które subskrybują istniejące strumienie zdarzeń, bez konieczności modyfikowania oryginalnych producentów danych.

Orkiestracja i monitorowanie StreamForge są zorganizowane wokół dwóch tematów usług:

##### Temat `queue-control`
*   **Cel:** Główny kanał do przesyłania poleceń z `queue-manager` do usług.
*   **Inicjator:** Wyłącznie `queue-manager`.
*   **Odbiorcy:** Wszystkie komponenty obliczeniowe (`loader-*`, `arango-connector` i inne).
*   **Przykładowa wiadomość:**
    ```json
    {
      "command": "start",
      "queue_id": "wf-btcusdt-api_candles_5m-20240801-a1b2c3",
      "target": "loader-producer",
      "symbol": "BTCUSDT",
      "type": "api_candles_5m",
      "time_range": "2024-08-01:2024-08-02",
      "kafka_topic": "wf-btcusdt-api_candles_5m-20240801-a1b2c3-data",
      "collection_name": "btcusdt_api_candles_5m_2024_08_01",
      "telemetry_id": "loader-producer__a1b2c3",
      "image": "registry.dmz.home/streamforge/loader-producer:v0.2.0",
      "timestamp": 1722500000.123
    }
    ```

##### Temat `queue-events`
*   **Cel:** Kanał raportowania wykonania zadań przez wszystkie usługi.
*   **Inicjator:** Wszystkie komponenty obliczeniowe.
*   **Odbiorcy:** `queue-manager`, który monitoruje proces wykonania w celu aktualizacji statusów.
*   **Przykładowa wiadomość:**
    ```json
    {
      "queue_id": "wf-btcusdt-api_candles_5m-20240801-a1b2c3",
      "producer": "arango-connector__a1b2c3",
      "symbol": "BTCUSDT",
      "type": "api_candles_5m",
      "status": "loading",
      "message": "Saved 15000 records",
      "records_written": 15000,
      "finished": false,
      "timestamp": 1722500125.456
    }
    ```

### Rozdział 4: Mikroserwisy

StreamForge to złożony system składający się ze wyspecjalizowanych mikroserwisów, z których każdy pełni unikalną i jasno zdefiniowaną funkcję.

#### 4.1. `queue-manager`: Silnik orkiestracji

`queue-manager` to mózg platformy, odpowiedzialny za kompleksową orkiestrację przepływów pracy przetwarzania danych. Jego główne funkcje obejmują:
*   **Zarządzanie przepływem pracy:** Zarządza pełnym cyklem życia przepływu pracy, od żądania API do stanu końcowego.
*   **Śledzenie stanu:** Monitoruje postęp przepływu pracy, konsumując z tematu `queue-events`.
*   **Dynamiczne tworzenie instancji zadań:** Współpracuje z interfejsem API Kubernetes w celu dynamicznego uruchamiania i zarządzania zadaniami wymaganymi dla danego przepływu pracy.
*   **API i raportowanie:** Udostępnia interfejs API RESTful do inicjowania przepływów pracy i odpytywania o ich status.

**Technologie:** Python, FastAPI (do implementacji API), Pydantic, `python-kubernetes`, `aiokafka`, ArangoDB.

#### 4.2. Gromadzenie danych: `loader-*`: Usługi pozyskiwania danych

Rodzina mikroserwisów `loader-*` to wyspecjalizowane agenty pozyskiwania danych. Każdy z nich jest odpowiedzialny za łączenie się z zewnętrznym źródłem, pobieranie danych i publikowanie ich jako zdarzeń w Apache Kafka:

*   **`loader-producer`:** Podstawowy moduł przeznaczony do wysokowydajnego ładowania danych masowych.
*   **`loader-api-*`:** Wyspecjalizowane moduły do pracy z danymi historycznymi za pośrednictwem interfejsu API REST.
*   **`loader-ws-*`:** Moduły przetwarzające dane strumieniowe w czasie rzeczywistym za pośrednictwem połączeń WebSocket.

Każdy moduł jest konfigurowany za pomocą zmiennych środowiskowych, współdziała z tematem `queue-control` w celu odbierania poleceń i wysyła raporty o stanie do tematu `queue-events`.

**Technologie:** Python, `aiohttp` (dla REST), `websockets` (dla WebSocket), `aiokafka`, `uvloop`, `orjson`.

#### 4.3. Przechowywanie danych: `arango-connector` — usługa utrwalania

Usługa `arango-connector` działa jako wysoce wydajny odbiornik danych, wypełniając lukę między strumieniem zdarzeń w czasie rzeczywistym w Kafce a warstwą trwałego przechowywania w ArangoDB:
*   **Ekstrakcja danych:** Konsumpcja komunikatów z odpowiednich tematów Kafki.
*   **Optymalizacja przechowywania:** Agregacja danych i ich przechowywanie w ArangoDB z myślą o optymalizacji wydajności.
*   **Zapisy idempotentne:** Wykorzystuje operacje UPSERT, aby zapewnić, że dane mogą być ponownie przetwarzane bez tworzenia zduplikowanych rekordów, co jest kluczową cechą systemów odpornych na błędy.
*   **Obsługa błędów:** Rejestrowanie nieprawidłowych lub uszkodzonych danych przy jednoczesnym zachowaniu ciągłości usługi.

**Technologie:** Python, `aioarango`, `aiokafka`.

#### 4.4. Warstwa analityczna: `graph-builder` i `gnn-trainer` — rdzeń analityki i uczenia maszynowego

Ten zestaw usług stanowi analityczny i uczenia maszynowego rdzeń platformy:

*   **`graph-builder`:** Przekształca przychodzące dane w struktury grafowe odpowiednie do późniejszej analizy.
*   **`gnn-trainer`:** Trenuje modele grafowych sieci neuronowych (GNN) na podstawie utworzonych grafów.

**Technologie:** Python, `aioarango`, `PyTorch`, `PyTorch Geometric (PyG)`, `minio-py`.

#### 4.5. `dummy-service`: Narzędzie diagnostyczne i testowe

`dummy-service` został opracowany jako narzędzie pomocnicze do testowania i symulacji. Służy do sprawdzania łączności z Kafką, symulowania zachowania usług i generowania obciążenia w celu testowania wydajności i odporności systemu.

**Technologie:** Python, FastAPI, `aiokafka`, `loguru`, `prometheus_client`.