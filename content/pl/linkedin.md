+++
date = '2025-08-26T01:30:47+02:00'
draft = false
weight = 89
title = '📌 Od kruchego REST do stabilnego Data Mesh: nasza strategiczna decyzja o Kafka.'
[params]
  menuPre = '<i class="fa-fw fab fa-linkedin"></i> '
+++

# 📌 Od kruchego REST do stabilnego Data Mesh: nasza strategiczna decyzja o Kafka.

✍️ Oleh Kondratov  
25 sierpnia 2025  

REST API to najszybsza droga do stworzenia rozproszonego monolitu.  
Przekonaliśmy się o tym, budując **StreamForge – platformę do automatycznego handlu kryptowalutami w czasie rzeczywistym**.  

Dlatego całkowicie zrezygnowaliśmy z REST i postawiliśmy na **architekturę zdarzeniową opartą o Apache Kafka**.  
To nie była tylko decyzja techniczna, ale **strategiczna inwestycja w niezawodność, skalowalność i szybkość innowacji**.  

---

## Część 1. Anatomia problemu: dlaczego systemy synchroniczne zawodzą  

Na początku StreamForge najłatwiej było użyć REST/gRPC. Loader wywołuje Parser, Parser wywołuje Writer. To działało… do czasu.  

Ale realia rynku krypto szybko pokazały słabości.  

**Historia 1. Kaskadowa awaria**  
Writer zwolnił przez obciążenie bazy. Parser czekał, kolejki się przepełniły. Loader przestał przyjmować dane z giełdy. W kilka minut straciliśmy handel.  
  **Wniosek:** lokalny problem stał się systemową awarią.  

**Historia 2. Rozproszony monolit**  
Każdy serwis znał adresy i API innych. Zmiana jednej odpowiedzi powodowała falę poprawek. Elastyczność znikła.  
  **Wniosek:** budowaliśmy monolit, tylko bardziej skomplikowany.  

**Historia 3. Skalowanie**  
Dodaliśmy Parsery, ale Loader musiał sam równoważyć ruch, robić retry, obsługiwać błędy. Logika odporności była dublowana w każdym serwisie.  
  **Wniosek:** zamiast prostego skalowania produkowaliśmy chaos i dług techniczny.  

💡 Te trzy przypadki przekonały mnie: **synchronizacja w tym domenie to ślepy zaułek**.  

{{< figure src="images/stream-forge2.jpg" title="RestAPI - KAFKA" >}}
---

## Część 2. Dlaczego wybraliśmy Kafka  

Po tych lekcjach było jasne: potrzebowaliśmy fundamentu, który się nie załamie.  

**Historia 1. Kolejka to za mało**  
RabbitMQ dostarczał wiadomości — ale po odczycie znikały. Awaria konsumenta = utrata danych lub lawina retry.  
  **Wniosek:** potrzebowaliśmy nie listonosza, ale *źródła prawdy*.  

**Historia 2. Kafka zmieniła model**  
Producent zapisuje zdarzenia. Konsument czyta w swoim tempie. Kafka pilnuje offsetów i kolejności. Serwisy nie znają się bezpośrednio.  
  **Wniosek:** zbudowaliśmy system nerwowy, a nie pajęczynę kabli.  

**Historia 3. Wartość biznesowa**  
CEO nie interesuje API, tylko szybkość wdrożeń. Kafka dała nam to: Data Science używa `raw-trades`, Security buduje fraud-detector, biznes tworzy analitykę. Równolegle i niezależnie.  
  **Wniosek:** dane stały się *strategicznym aktywem*.  

💡 Kafka to nie middleware, ale **inwestycja w niezawodność i innowacyjność**.  

---

## Część 3. Supermoce, które uzyskaliśmy  

**Historia 1. Niezawodność**  
Zrestartowaliśmy `gnn-trainer` na 10 minut. Dane nadal trafiały do Kafka. Po powrocie nadrobił backlog.  
  **Wniosek:** awaria stała się opóźnieniem, a nie katastrofą.  

**Historia 2. Elastyczność**  
Podczas wystąpienia FED wolumen wzrósł 20x. Lag rósł. Uruchomiliśmy:  
`kubectl scale deployment/orderbook-processor --replicas=64`  
Kafka rozdzieliła partycje, lag zniknął.  
  **Wniosek:** skalowanie stało się operacją, a nie kryzysem.  

**Historia 3. Data Mesh**  
Każdy topic = produkt. Data Science bierze `raw-trades`, Security – `fraud-detector`. Brak blokad.  
  **Wniosek:** wdrożyliśmy Data Mesh: dane jako wspólny zasób firmy.  

---

## Wnioski  

To nie była „komplikacja dla komplikacji”.  
To była **strategiczna decyzja**, która dała nam:  
- niezawodność wbudowaną w architekturę,  
- skalowalność ograniczoną tylko zasobami klastra,  
- szybkość innowacji przez niezależne serwisy.  

Zbudowaliśmy fundament na lata.  
I jest **żelbetowy**.  

---

  **Więcej**  
- {{% icon "fab fa-linkedin" %}} Dokumentacja: [docs.streamforge.dev](http://docs.streamforge.dev)  
- {{% icon "fab fa-github" %}} GitHub: [github.com/0leh-kondratov/stream-forge](https://github.com/0leh-kondratov/stream-forge)  


👉 Pytanie: jak wasza firma radzi sobie z kruchością synchronicznych mikrousług?  

#architektura #kafka #EDA #streaming #crypto #devops  