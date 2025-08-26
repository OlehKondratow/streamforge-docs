+++
date = '2025-08-25T13:00:00+02:00'
draft = false
title = 'Manifest Architektoniczny StreamForge: Dlaczego stawiamy wszystko na asynchroniczność'
weight = 1
+++

### Koledzy,

Ten dokument to nasz manifest architektoniczny. Jego celem jest nie tylko opisanie, ale **uzasadnienie** fundamentalnego wyboru, który definiuje całą naszą kulturę inżynierską: **odrzucenie synchronicznej interakcji na rzecz 100% asynchronicznego, sterowanego zdarzeniami modelu**.

Chcę szczegółowo, na poziomie zasad i praktycznych konsekwencji, pokazać, dlaczego klasyczne podejście z bezpośrednimi wywołaniami API dla naszej domeny to droga do stworzenia kruchego, nieskalowalnego i trudnego w utrzymaniu "rozproszonego monolitu". I dlaczego **Apache Kafka** w roli "centralnego układu nerwowego" to nie tylko modna technologia, ale strategiczna inwestycja w **niezawodność, skalowalność i szybkość rozwoju** na lata.

---

### Część 1: Anatomia bólu. Głębokie problemy systemów synchronicznych.

Bądźmy szczerzy. Zbudowanie systemu na bezpośrednich wywołaniach API (czy to REST, czy gRPC) to najbardziej oczywista i najszybsza droga na start. Usługa A wywołuje usługę B. Proste i zrozumiałe. Ale dla naszej domeny to architektoniczny ślepy zaułek.

Rynek kryptowalut to idealna burza: zmienność 24/7, gigantyczne wolumeny danych i nieprzewidywalne szczytowe obciążenia. Próba zbudowania tu czegoś na wywołaniach synchronicznych nieuchronnie prowadzi do następujących problemów:

1.  **Kaskadowe awarie (Cascading Failures):** Wyobraźmy sobie łańcuch: `loader` (odbiera dane z giełdy) -> `parser` (przekształca je do naszego formatu) -> `writer` (zapisuje do bazy danych). Jeśli `writer` zaczyna zwalniać z powodu obciążenia bazy danych lub restartuje się, tworzy **ciśnienie zwrotne (backpressure)**. `parser` czeka, jego bufory się przepełniają. Przestaje przyjmować dane od `loader`. `loader` również jest zmuszony się zatrzymać. W rezultacie minutowa awaria na poziomie bazy danych prowadzi do całkowitego zatrzymania odbioru danych i ich utraty. Budujemy "domek z kart".

2.  **"Gadatliwe" mikroserwisy i "rozproszony monolit":** W modelu synchronicznym usługi są zmuszone do ciągłego "rozmawiania" ze sobą. Tworzy to sztywne, niejawne zależności. Usługa A musi znać adres usługi B. Musi znać jej API, obsługiwać jej specyficzne błędy. Z czasem to przekształca się w "rozproszony monolit" - zmiana czegoś w jednej usłudze jest przerażająca, ponieważ nie wiadomo, gdzie i jak to się odbije.

3.  **Problem skalowania:** Jak skalować taki system? Jeśli `parser` stał się wąskim gardłem, możemy uruchomić 10 jego instancji. Ale teraz `loader` musi wiedzieć, jak równoważyć obciążenie między nimi? A co, jeśli jeden z `parser`-ów umrze? `loader` musi zaimplementować logikę ponownych prób (retry) i przełączania na działającą instancję. Zaczynamy duplikować złożoną logikę odporności na awarie w każdej usłudze.

---

### Część 2: Nasz zakład — trwały log jako serce systemu.

Uświadomiwszy to sobie, strategicznie postawiliśmy na **architekturę sterowaną zdarzeniami (EDA)**. Ale nie tylko na "kolejkę wiadomości", lecz na **Apache Kafka** jako implementację wzorca "rozproszonego trwałego logu".

**Jaka jest kluczowa różnica w stosunku do, powiedzmy, RabbitMQ?**
-   **RabbitMQ (i podobne brokery)** to w zasadzie listonosz. Wziął wiadomość, dostarczył ją pierwszemu odbiorcy, a wiadomość zniknęła. To doskonale nadaje się do dystrybucji zadań, ale nie do przetwarzania strumieniowego danych.
-   **Kafka** to raczej "centralne archiwum" lub "dziennik pokładowy" całej firmy. Każde zdarzenie ("transakcja BTCUSDT o 12:05:03") jest zapisywane w tym dzienniku (temacie) i pozostaje tam przez określony czas (np. 7 dni), nawet po jego odczytaniu.

Ta fundamentalna różnica zmienia wszystko. Nasze usługi nie komunikują się już ze sobą. Współdziałają z tym centralnym archiwum:
-   **Producenci** po prostu dopisują nowe zdarzenia na koniec dziennika. Nie obchodzi ich, kto, kiedy i ile razy odczyta to zdarzenie.
-   **Konsumenci** czytają ten dziennik, każdy we własnym tempie. Kafka dla każdego konsumenta (a dokładniej, dla `consumer group`) pamięta, w którym miejscu w dzienniku się zatrzymał (nazywa się to `offset`).

#### 2.1. Anatomia Kafki: Partycje, Klucze, Offsety i Grupy Konsumentów

Aby zrozumieć pełną moc, trzeba zrozumieć cztery koncepcje:
-   **Partycje:** Temat w Kafce to nie jeden duży log, ale zbiór N równoległych, uporządkowanych logów, zwanych partycjami. **Partycja to jednostka równoległości.**
-   **Klucze:** Gdy producent wysyła zdarzenie, może określić klucz (np. `symbol="BTCUSDT"`). Kafka gwarantuje, że wszystkie zdarzenia z tym samym kluczem zawsze trafią do tej samej partycji. To **zachowuje kolejność zdarzeń w ramach jednej encji** (wszystkie transakcje BTCUSDT będą następować ściśle jedna po drugiej).
-   **Offsety:** Każdy konsument sam odpowiada za to, którą ostatnią wiadomość odczytał w każdej partycji. Numer tej wiadomości (`offset`) jest okresowo zapisywany z powrotem do Kafki. Daje to konsumentom pełną kontrolę nad procesem odczytu.
-   **Grupy Konsumentów:** Kilka instancji tej samej usługi (np. 5 podów `arango-connector`) może połączyć się w jedną grupę konsumentów (określając ten sam `group.id`). Kafka automatycznie rozdzieli wszystkie partycje tematu między te 5 instancji. Jeśli jedna z nich ulegnie awarii, Kafka w ułamku sekundy **przerzuci (rebalance)** jej partycje między pozostałe. To jest mechanizm odporności na awarie i skalowania.

---

### Część 3: Supermoce, które zyskujemy.

Ta architektura daje nam trzy strategiczne przewagi, nieosiągalne w świecie synchronicznym.

#### 3.1. Absolutna odporność na awarie i samonaprawa

Kafka działa jak gigantyczny amortyzator między usługami.
**Przykład:** Nasza usługa `gnn-trainer` (szkolenie modeli grafowych) — ciężka i zasobożerna. Odczytuje dane z tematu `graph-features`. Załóżmy, że chcemy wdrożyć jej nową wersję. Po prostu zatrzymujemy starą, wdrażamy nową. Zajmuje to 5 minut. Przez te 5 minut usługa `graph-builder` nadal spokojnie pracuje i publikuje nowe cechy dla grafów w temacie. Tam się gromadzą. Kiedy `gnn-trainer` startuje, widzi swój stary `offset`, rozumie, że jest w tyle, i zaczyna w przyspieszonym tempie przetwarzać zgromadzone dane. **Z punktu widzenia całego systemu nie było awarii. Było opóźnienie w przetwarzaniu, ale nie utrata danych ani zatrzymanie.**

#### 3.2. Elastyczność i skalowanie liniowe

To już nie teoria, ale rzeczywistość operacyjna.
**Przykład:** Nasz temat `raw-orderbooks` ma 64 partycje. W spokojnym czasie jest przetwarzany przez 8 instancji `orderbook-processor`. Każda przetwarza po 8 partycji. Zaczyna się wystąpienie szefa Fed, zmienność szaleje, strumień danych rośnie 20-krotnie. Nasz pulpit nawigacyjny w Grafanie pokazuje, że `consumer lag` (opóźnienie konsumentów) rośnie.
**Nasze działania:** `kubectl scale deployment/orderbook-processor --replicas=64`.
**Co dzieje się dalej:** Kubernetes tworzy 56 nowych podów. Dołączają one do tej samej grupy konsumentów. Kafka uruchamia rebalansowanie, a po kilku sekundach mamy już 64 instancje, z których każda przetwarza jedną partycję. Przepustowość przetwarzania wzrasta 8-krotnie. Kiedy obciążenie spadnie, równie łatwo przywrócimy liczbę replik do 8. **Przeszliśmy od złożonego problemu inżynierskiego wydajności do trywialnego zadania operacyjnego.**

#### 3.3. Ewolucja architektury i koncepcja "Data Mesh"

To najpotężniejszy strategiczny plus. Przekształcamy nasze strumienie danych w **"produkty"**.
Zespół odpowiedzialny za ładowarki jest właścicielem "produktu" - tematu `raw-trades`. Ich obowiązkiem jest dostarczanie do tego tematu wysokiej jakości, ważnych danych z określonym SLA.
-   Jutro zespół **Data Science** będzie chciał zbudować model przewidywania zmienności. Nie muszą iść do zespołu ładowarek. Po prostu tworzą swoją usługę `volatility-predictor` z nową `consumer group` i zaczynają czytać dane z `raw-trades`.
-   Pojutrze zespół **Security** będzie chciał wdrożyć system monitorowania oszustw. Tworzą swoją usługę `fraud-detector` i subskrybują ten sam temat.

Wszystkie te zespoły pracują **równolegle i niezależnie**. Nie mogą sobie nawzajem przeszkadzać ani zepsuć głównego potoku danych. Pozwala nam to rozwijać produkt z niespotykaną szybkością i elastycznością. Wdrażamy w praktyce koncepcję **Data Mesh**, gdzie dane stają się zdecentralizowanym, łatwo dostępnym i niezawodnym zasobem dla całej firmy.

---

### Podsumowanie: Inwestujemy w szybkość.

Przejście na EDA i Kafkę to nie komplikowanie dla komplikowania. To świadomy kompromis. Akceptujemy nieco większą złożoność na początku, aby uzyskać fundamentalne korzyści w przyszłości.

Budujemy platformę, która daje nam:
-   **Niezawodność**, wbudowaną w samą architekturę.
-   **Skalowalność**, ograniczoną tylko zasobami naszego klastra, a nie projektem oprogramowania.
-   **Szybkość i elastyczność** w rozwoju, pozwalającą nam szybko weryfikować hipotezy i wprowadzać na rynek nowe produkty.

To nasz fundament. I jest on solidny jak skała.