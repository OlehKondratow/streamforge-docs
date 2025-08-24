+++
date = '2025-06-13T20:14:52+02:00'
draft = true
title = 'Architektura i analiza danych kryptowalutowych w czasie rzeczywistym'
weight = 1
+++

### Status usługi

| Usługa | Wersja | Kompilacja | Test | Wdrożenie |
| :--- | :---: | :---: | :--: | :----: |
| **queue-manager** | ![version-queue-manager](badges/main/version-queue-manager.svg) | ![build-queue-manager](badges/main/build-queue-manager.svg) | ![test-queue-manager](badges/main/test-queue-manager.svg) | ![deploy-queue-manager](badges/main/deploy-queue-manager.svg) |
| **dummy-service** | ![version-dummy-service](badges/main/version-dummy-service.svg) | ![build-dummy-service](badges/main/build-dummy-service.svg) | ![test-dummy-service](badges/main/test-dummy-service.svg) | ![deploy-dummy-service](badges/main/deploy-dummy-service.svg) |
| **arango-connector** | ![version-arango-connector](badges/main/version-arango-connector.svg) | ![build-arango-connector](badges/main/build-arango-connector.svg) | ![test-loader-arango-connector](badges/main/test-loader-arango-connector.svg) | ![deploy-arango-connector](badges/main/deploy-arango-connector.svg) |
| **loader-api-candles** | ![version-loader-api-candles](badges/main/version-loader-api-candles.svg) | ![build-loader-api-candles](badges/main/build-loader-api-candles.svg) | ![test-loader-arango-connector](badges/main/test-loader-arango-connector.svg) | ![badges/main/deploy-api-candles.svg](badges/main/deploy-api-candles.svg) |
| **loader-api-trades** | ![version-loader-api-trades](badges/main/version-loader-api-trades.svg) | ![build-loader-api-trades](badges/main/build-loader-api-trades.svg) | ![test-loader-api-trades](badges/main/test-loader-api-trades.svg) | ![deploy-api-trades.svg](badges/main/deploy-api-trades.svg) |


# StreamForge: Wysokowydajna, sterowana zdarzeniami platforma do analizy danych kryptowalutowych w czasie rzeczywistym

**StreamForge** to zaawansowana, sterowana zdarzeniami platforma zaprojektowana do wysokoprzepustowego pozyskiwania, przetwarzania i analizy danych rynkowych kryptowalut w czasie rzeczywistym. Zbudowana w oparciu o nowoczesne technologie Cloud-Native i wzorce architektoniczne, StreamForge dostarcza skalowalne, odporne i elastyczne rozwiązanie do sprostania wyjątkowym wyzwaniom krajobrazu aktywów cyfrowych.

## Przegląd architektury

```mermaid
%% StreamForge — Cykl życia danych (poprawiony)
%% Zmiany: bezpieczne etykiety, zachowaj gwiazdkę tylko wewnątrz etykiety węzła
flowchart LR
    B[(Binance API)]:::ext --> LP[loader-producer]:::svc
    QM[Queue Manager]:::svc --> K
    LP --> K[[Kafka: market-candles-*]]:::topic
    K --> AC[arango-connector]:::svc
    A --> VIS[Visualizer UI]:::svc
    K --> VIS
    QM --> VIS
    QM --> AC
    QM --> LP
    AC --> A[(ArangoDB)]:::core
classDef svc fill:#2B90D9,stroke:#0E4F88,color:#FFFFFF
classDef topic fill:#6B8E23,stroke:#2F4F2F,color:#FFFFFF
classDef core fill:#333344,stroke:#9999AA,color:#FFFFFF
classDef ext fill:#555555,stroke:#333333,color:#FFFFFF
```

## 1.1. Wyzwanie danych kryptowalutowych

W szybko zmieniającym się świecie aktywów cyfrowych dane kryptowalutowe są siłą napędową analityki i zautomatyzowanego podejmowania decyzji. Dane te charakteryzują się ekstremalną zmiennością, dostępnością 24/7 i ogromną objętością, obejmując wszystko, od transakcji o wysokiej częstotliwości po ciągłe aktualizacje księgi zamówień. Cechy te wymagają nowej generacji potoków danych — takich, które są nie tylko wysokowydajne, ale także wyjątkowo niezawodne.

Kluczowe przeszkody techniczne obejmują:
- **Heterogeniczne pozyskiwanie danych:** Integracja rozbieżnych strumieni danych z wielu źródeł, w tym interfejsów API REST dla danych historycznych i kanałów WebSocket dla zdarzeń rynkowych w czasie rzeczywistym.
- **Ekstremalna skalowalność:** Architektura systemu zdolnego do przetwarzania ogromnych, gwałtownych strumieni danych bez wprowadzania opóźnień.
- **Integralność danych i odporność na błędy:** Zapewnienie gwarantowanej dostawy danych i projektowanie w celu szybkiego, zautomatyzowanego odzyskiwania po awariach komponentów.
- **Złożona orkiestracja przepływu pracy:** Zarządzanie zaawansowanymi, wieloetapowymi przepływami pracy przetwarzania danych, takimi jak sekwencja „załadowanie -> utrwalenie -> budowa grafu -> trenowanie modelu”, w skoordynowany i niezawodny sposób.

## 1.2. Rozwiązanie StreamForge: oddzielona, sterowana zdarzeniami architektura

StreamForge jest zaprojektowany jako w pełni sterowana zdarzeniami platforma, zaprojektowana od podstaw z myślą o maksymalnej wydajności i odporności. Podstawową zasadą jest całkowite oddzielenie usług za pośrednictwem centralnego układu nerwowego: **Apache Kafka**. Zamiast bezpośrednich, kruchych wywołań między usługami, komponenty komunikują się asynchronicznie. Każdy mikroserwis jest samodzielną jednostką, która publikuje zdarzenia (swoją pracę).

Zastosowanie tego podejścia gwarantuje wysoką skalowalność, zdolność adaptacji do zmieniających się wymagań i zwiększoną odporność na błędy całego systemu.

## 1.3. Misja projektu

1.  **Stworzenie ujednoliconego źródła danych:** Konsolidacja procesów gromadzenia, weryfikacji i przechowywania danych rynkowych w celu zapewnienia szybkiego i wygodnego dostępu do informacji wysokiej jakości.
2.  **Stworzenie innowacyjnego środowiska dla nauki o danych:** Zapewnienie wyspecjalizowanej platformy do rozwoju, testowania i walidacji modeli analitycznych, w tym zaawansowanych architektur grafowych sieci neuronowych (GNN).
3.  **Zbudowanie niezawodnej podstawy dla handlu algorytmicznego:** Opracowanie wysokowydajnego i odpornego na błędy potoku danych, o kluczowym znaczeniu dla funkcjonowania zautomatyzowanych systemów transakcyjnych.
4.  **Kompleksowa automatyzacja procesów:** Minimalizacja interwencji manualnej na wszystkich etapach cyklu życia danych, od gromadzenia po przetwarzanie analityczne, w celu zwiększenia wydajności operacyjnej.

## 1.4. Praktyczne przypadki użycia

- **Scenariusz 1: Trenowanie modelu na danych historycznych.**
  - **Cel:** Wytrenowanie modelu GNN na retrospektywnych danych transakcyjnych i zagregowanych 5-minutowych świecach dla pary handlowej `BTCUSDT` w ciągu ostatniego miesiąca.
  - **Metoda:** Pełny cykl przetwarzania danych jest aktywowany za pośrednictwem `queue-manager`. Zadania są wykonywane przez zadania Kubernetes: `loader-producer` ładuje dane do Apache Kafka, `arango-connector` zapewnia ich trwałe przechowywanie w ArangoDB, `graph-builder` tworzy strukturę grafu, a `gnn-trainer` przeprowadza trenowanie modelu.

- **Scenariusz 2: Monitorowanie rynku w czasie rzeczywistym.**
  - **Cel:** Uzyskanie danych strumieniowych o transakcjach i stanie księgi zamówień w czasie rzeczywistym dla pary handlowej `ETHUSDT`.
  - **Metoda:** Moduł `loader-ws` nawiązuje połączenie z WebSocket i przesyła dane do Apache Kafka. Rozwijany moduł wizualizacji subskrybuje odpowiednie tematy, aby wyświetlać dane na interaktywnym pulpicie nawigacyjnym.

- **Scenariusz 3: Szybka analiza danych.**
  - **Cel:** Weryfikacja hipotezy dotyczącej korelacji między wolumenami obrotu a zmiennością rynku.
  - **Metoda:** Użycie `Jupyter Server` do nawiązania połączenia z ArangoDB i przeprowadzenia badań analitycznych na podstawie danych już zagregowanych i przetworzonych przez system StreamForge.

Te potężne funkcje sprawiają, że StreamForge jest niezbędnym narzędziem dla każdego, kto dąży do maksymalnej wydajności w pracy z danymi kryptowalutowymi.

## Obrazy kontenerów

Następujące obrazy Docker są publikowane w GitHub Container Registry (GHCR):

| Usługa | Status | Obraz | Polecenie pobierania |
|---|---|---|---|
| dummy-service | [![CI](https://github.com/0leh-kondratov/stream-forge/actions/workflows/dummy-service-ci.yml/badge.svg)](https://github.com/0leh-kondratov/stream-forge/actions/workflows/dummy-service-ci.yml) | `ghcr.io/0leh-kondratov/dummy-service:latest` | `docker pull ghcr.io/0leh-kondratov/dummy-service:latest` |
| streamforge-base | ![Rozmiar obrazu](https://img.shields.io/docker/image-size/0leh-kondratov/stream-forge-base/latest?label=size) ![Pobrania](https://img.shields.io/docker/pulls/0leh-kondratov/stream-forge-base) | `ghcr.io/0leh-kondratov/stream-forge-base:v0.1.3` | `docker pull ghcr.io/0leh-kondratov/stream-forge-base:v0.1.3` |


---