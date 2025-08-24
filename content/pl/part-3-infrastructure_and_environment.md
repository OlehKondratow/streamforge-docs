+++
date = '2025-08-24T20:23:59+02:00'
draft = true
title = 'Infrastruktura i środowisko'
weight = 3
+++

## Część III: Infrastruktura i środowisko

Platforma **StreamForge** jest wdrażana w wysokowydajnym, lokalnym środowisku zaprojektowanym z myślą o maksymalnej niezawodności, skalowalności i wydajności operacyjnej. Infrastruktura opiera się na wyselekcjonowanym stosie technologii open-source klasy korporacyjnej. U jej podstaw leży klaster **Kubernetes**, działający w środowisku zwirtualizowanym i zarządzany za pomocą nowoczesnych metodologii GitOps oraz wzorców architektonicznych natywnych dla chmury.

### Rozdział 5: Podstawy platformy: Kubernetes i wirtualizacja

#### 5.1. Fundament: Proxmox VE

**Proxmox VE** służy jako podstawowa warstwa wirtualizacji — dojrzała platforma klasy korporacyjnej, która zapewnia solidną izolację środowisk obliczeniowych, wysoką dostępność i scentralizowane zarządzanie zasobami. Maszyny wirtualne wdrożone na Proxmox VE służą jako hosty dla węzłów klastra Kubernetes.

#### 5.2. Wdrażanie klastra: Kubespray

Klaster Kubernetes jest wdrażany przy użyciu **Kubespray** — zgodnego z CNCF, zautomatyzowanego narzędzia do środowisk gotowych do produkcji. Kubespray zapewnia idempotentny i powtarzalny proces wdrażania, obejmujący instalację płaszczyzny sterowania, konfigurację topologii sieci i integrację TLS, gwarantując w ten sposób spójność i odtwarzalność klastra.

#### 5.3. Infrastruktura sieciowa

Infrastruktura sieciowa StreamForge została zaprojektowana z myślą o wysokiej niezawodności i zdolności adaptacji, z naciskiem na odporność na błędy i przejrzysty dostęp zewnętrzny:

- **kube-vip** zapewnia wirtualny adres IP dla dostępu wysokiej dostępności (HA) do interfejsu API Kubernetes, umożliwiając automatyczne przekierowanie ruchu w przypadku awarii węzła płaszczyzny sterowania.
- **MetalLB** w wersji `0.14.9` jest używany w trybie Layer2 do obsługi usług typu `LoadBalancer` w środowisku bare-metal, eliminując potrzebę stosowania sprzętowego load balancera.

#### 5.4. Ingress i Gateway API: Zarządzanie ruchem

W StreamForge stosowana jest podwójna strategia kontrolerów Ingress do zarządzania ruchem przychodzącym, zapewniając elastyczne trasowanie i wysoką dostępność:

- **Traefik** (v36.1.0) — główny kontroler Ingress, wykorzystujący nowy **Gateway API** do deklaratywnego trasowania i zarządzania ruchem na warstwach L7 (HTTP/HTTPS) i L4 (TCP/UDP).
- **ingress-nginx** (v4.12.1) — zapasowy kontroler Ingress, zapewniający kompatybilność i dodatkową odporność na błędy.

Ustawienia obejmują:
- TLS za pośrednictwem `cert-manager` i wewnętrznego urzędu certyfikacji `homelab-ca-issuer`
- Zewnętrzny adres IP: `192.168.1.153`
- Pamięć ACME: 1Gi NFS
- Monitorowanie za pośrednictwem `/dashboard`
- Obsługa usług TCP (`ssh`, `kafka`)

#### 5.5. DNS i TLS

- **Technitium DNS Server** zapewnia lokalny resolver z obsługą dowolnych stref DNS, w tym `*.dmz.home`, zapewniając dostęp do usług za pomocą nazw czytelnych dla człowieka.
- **cert-manager** automatyzuje zarządzanie certyfikatami TLS, zmniejszając ryzyko błędów i zwiększając bezpieczeństwo komunikacji między komponentami.

##### `script.sh` do generowania certyfikatów TLS

Skrypt `/platform/base/cert/script.sh` automatyzuje pełny cykl życia generowania certyfikatów TLS, w tym:
1. Konfigurację parametrów generowania i przechowywania;
2. Utworzenie CSR z polami SAN (FQDN + IP);
3. Utworzenie zasobu `CertificateRequest` i przesłanie go do `cert-manager`;
4. Oczekiwanie na wykonanie i zapisanie plików PEM;
5. Walidację certyfikatu za pomocą `openssl`.

---

### Rozdział 6: Zarządzanie danymi: strategie przechowywania i dostępu

Trwałe przechowywanie danych jest niezwykle ważnym aspektem zapewniającym długoterminową analitykę i efektywne trenowanie modeli. W StreamForge przechowywanie danych jest podzielone na strefy funkcjonalne w celu optymalizacji wydajności i dostępności.

#### 6.1. Przegląd rozwiązań pamięci masowej

- **Linstor Piraeus** — odporna na błędy pamięć blokowa (RWO) dla usług krytycznych, takich jak PostgreSQL i ArangoDB, zapewniająca wysoką dostępność i integralność danych.
- **GlusterFS** i **NFS Subdir External Provisioner** (v4.0.18) — zapewniają współdzielone woluminy z trybem dostępu RWX (ReadWriteMany), co jest idealne dla środowisk współpracy, takich jak JupyterHub, oraz dla współdzielonych zestawów danych. Główna ścieżka dostępu to `192.168.1.6:/data0/k2`.

#### 6.2. Pamięć obiektowa Minio

- **Minio** — kompatybilna z S3 pamięć obiektowa, służy jako główne repozytorium do:
- przechowywania artefaktów modeli (np. GNN, PPO),
- tworzenia kopii zapasowych usług i metadanych.

Zapewnia wysoką dostępność i integrację z Kubernetes za pośrednictwem StatefulSet.

---

### Rozdział 7: Platforma danych: zarządzanie informacjami

#### 7.1. Operator Strimzi Kafka

**Strimzi** automatyzuje pełne zarządzanie cyklem życia Apache Kafka w środowisku Kubernetes, w tym wdrażanie, aktualizacje, konfigurację tematów, szyfrowanie i monitorowanie. Integracja jest osiągana deklaratywnie za pomocą zasobów niestandardowych, takich jak `KafkaUser`, `KafkaTopic` i `KafkaConnect`.

#### 7.2. ArangoDB: Baza danych wielomodelowa

ArangoDB to wielomodelowa baza danych, która natywnie integruje modele danych dokumentów i grafów w jednym silniku:
- **Dokumenty**: używane do przechowywania historycznych świec i zdarzeń, zapewniając elastyczność i skalowalność.
- **Grafy**: stosowane do opisywania złożonych relacji między aktywami a operacjami handlowymi, co ma kluczowe znaczenie dla funkcjonowania grafowych sieci neuronowych (GNN).

#### 7.3. PostgreSQL (Operator Zalando)

**Operator Zalando** zarządza wdrażaniem i działaniem klastrów PostgreSQL z wysoką dostępnością, zautomatyzowanymi kopiami zapasowymi i mechanizmami przełączania awaryjnego. To rozwiązanie służy do przechowywania ustrukturyzowanych danych relacyjnych, w tym tabel zwrotu z inwestycji (ROI), dzienników działań agentów i metadanych eksperymentów.

#### 7.4. Autoskalowanie za pomocą KEDA

**KEDA** (Kubernetes Event-driven Autoscaling) umożliwia dynamiczne, sterowane zdarzeniami skalowanie zasobników konsumentów w oparciu o zaległości komunikatów w Apache Kafka. Zapewnia to optymalne dostosowanie do zmiennych obciążeń bez ręcznej interwencji, co optymalizuje wykorzystanie zasobów, obniża koszty operacyjne i minimalizuje opóźnienia w przetwarzaniu.

#### 7.5. Interfejs użytkownika Kafki

**Kafka UI**, interfejs internetowy od `provectuslabs`, oferuje intuicyjną wizualną płaszczyznę sterowania do zarządzania tematami, grupami konsumentów, użytkownikami i komunikatami w Apache Kafka.

Parametry:
- Dostęp pod adresem `https://kafka-ui.dmz.home`
- Integracja przez SASL_SSL (SCRAM-SHA-512)
- Połączenie z klastrem `k3`
- Działa na `k2w-7`, 1 replika

---

### Rozdział 8: Monitorowanie i obserwowalność: kompleksowa kontrola systemu

Aby zapewnić stabilne działanie i umożliwić szybką reakcję na incydenty, StreamForge wykorzystuje kompleksowy stos obserwowalności.

#### 8.1. Metryki: Prometheus, NodeExporter, cAdvisor

- **Prometheus** — podstawowa baza danych szeregów czasowych do gromadzenia i przechowywania metryk systemowych i aplikacyjnych.
- **cAdvisor** — narzędzie do monitorowania zasobów i wydajności kontenerów.
- **NodeExporter** — eksporter metryk systemu operacyjnego i hosta.

Komponenty:
- kube-prometheus-stack `v71.1.0`
- TLS + Ingress dla Prometheus (`prometheus.dmz.home`) i Grafana (`grafana.dmz.home`)
- Woluminy trwałe: Prometheus — 20Gi, Grafana — 1Gi

#### 8.2. Dzienniki: Fluent-bit, Elasticsearch, Kibana

Scentralizowany potok rejestrowania oparty na stosie **EFK** (Elasticsearch, Fluent-bit, Kibana) jest zaimplementowany do agregacji, routingu i analizy dzienników w całym systemie:

- **Fluent-bit** stosuje filtr Lua do dynamicznego tworzenia indeksów na podstawie tagów (np. `internal-myapp-2025.08.07`), zapewniając elastyczność w indeksowaniu dzienników.
- **Elasticsearch** zapewnia wyszukiwanie pełnotekstowe, agregacje i przechowywanie dzienników.
- **Kibana** wizualizuje dzienniki, oferując wygodny interfejs do analizy według tagów, indeksów i zakresów czasowych.

#### 8.3. Grafana i Alertmanager

- **Grafana** — główna platforma do wizualizacji danych, zintegrowana z Prometheus, Elasticsearch i PostgreSQL w celu zapewnienia ujednoliconego widoku metryk i dzienników systemowych.
- **Alertmanager** — zarządza routingiem, grupowaniem i wysyłaniem alertów za pośrednictwem poczty e-mail i Telegrama na podstawie predefiniowanych reguł.

---

### Rozdział 9: Automatyzacja i GitOps: optymalizacja procesów wdrażania

StreamForge jest zarządzany za pomocą ścisłej metodologii GitOps, która automatyzuje i usprawnia wdrażanie i zarządzanie infrastrukturą, minimalizując w ten sposób ręczną interwencję i zwiększając niezawodność systemu.

#### 9.1. GitLab Runner

Potoki CI/CD są zasilane przez GitLab CI, wykorzystując `kaniko` do bezpiecznego, bezdemonicznego budowania obrazów kontenerów bezpośrednio w klastrze Kubernetes. Aby zoptymalizować czas budowy i zapewnić spójność w środowiskach programistycznych, testowych i produkcyjnych, stosowany jest **ujednolicony obraz bazowy**. Ten obraz, zbudowany z `platform/Dockerfile`, preinstaluje popularne zależności Pythona, w tym wszystkie niezbędne frameworki i biblioteki testowe, oraz integruje bibliotekę `streamforge_utils` za pomocą solidnej instalacji koła.

- Runner działa w egzekutorze `kubernetes` z `nodeSelector` na węźle `k2w-9` w celu optymalnego rozkładu zasobów.
- **Procesy budowania Kaniko są zoptymalizowane** poprzez użycie katalogu głównego projektu jako kontekstu budowy i wykorzystanie jawnego buforowania warstw obrazu (`--cache=true`) w celu znacznego przyspieszenia kolejnych kompilacji.
- Konfiguracja CI/CD jest podzielona na wspólne szablony (`.build_python_service`) i określone potoki dla każdej usługi, zapewniając modułowość i możliwość ponownego wykorzystania.

##### 9.1.1. Runner: Funkcje konfiguracyjne

- Prawa uprzywilejowane
- ServiceAccount: `full-access-sa`
- Pule: `runner-home`, `docker-config`, `home-certificates`
- Repozytorium: `https://gitlab.dmz.home/`

##### 9.1.2. Struktura potoku

- `setup` → `build` → `test` → `deploy`
- Używane są pliki dołączane ze ścieżkami do usług
- Szablony wielokrotnego użytku `.gitlab/ci-templates/`

##### 9.1.3. Integracja i modułowość

Każda usługa (np. `dummy-service`) używa zmiennych `SERVICE_NAME`, `SERVICE_PATH` i rozszerza wspólny szablon.

#### 9.2. ArgoCD

**ArgoCD** to deklaratywny silnik GitOps odpowiedzialny za zautomatyzowane zarządzanie stanem klastra Kubernetes w oparciu o repozytorium Git. Zapewnia:

- **Pojedyncze źródło prawdy:** Repozytorium `iac_kubeadm` (`gitlab.dmz.home`) służy jako jedyne źródło prawdy dla konfiguracji klastra.
- **Obsługa TLS:** Bezpieczna komunikacja z GitLab jest zapewniona przez TLS.
- **Dostęp przez Internet:** Dostęp do interfejsu użytkownika ArgoCD jest dostępny pod adresem `argocd.dmz.home`.

- **Kontrola wersji:** Wszystkie komponenty infrastruktury są pod kontrolą wersji, co upraszcza śledzenie zmian i przywracanie poprzednich stanów.

#### 9.3. Reloader

**Reloader** to lekki kontroler, który automatyzuje kroczącą aktualizację zasobników po zmodyfikowaniu powiązanych z nimi obiektów `Secret` lub `ConfigMap`. Gwarantuje to, że aplikacje zawsze używają najnowszej konfiguracji bez ręcznej interwencji.

---

### Rozdział 10: Bezpieczeństwo i dodatkowe możliwości

#### 10.1. HashiCorp Vault

**HashiCorp Vault** jest zintegrowany z `Vault CSI Driver`, aby ułatwić bezpieczne i dynamiczne wstrzykiwanie tymczasowych wpisów tajnych do zasobników Kubernetes, zapobiegając ich trwałemu przechowywaniu w klastrze.

#### 10.2. Keycloak

**Keycloak** służy jako centralne rozwiązanie do zarządzania tożsamością i dostępem (IAM) dla wszystkich usług platformy. Obsługuje standardy SSO (Single Sign-On) i OpenID Connect, integrując się z Grafaną, Kibaną i ArgoCD w celu scentralizowanego zarządzania użytkownikami i uprawnieniami.

#### 10.3. Operator NVIDIA GPU

**Operator NVIDIA GPU** automatyzuje zarządzanie zasobami NVIDIA GPU w klastrze Kubernetes, w tym instalację i konfigurację sterowników, abstrahując w ten sposób od złożoności sprzętowej.

- Wersja: `v24.9.2`
- Obsługa trenowania GNN: Zapewnia niezbędną infrastrukturę do wydajnego trenowania grafowych sieci neuronowych.
- Łatwe aktualizacje za pomocą Helm: Upraszcza proces aktualizacji i zarządzania operatorem.

#### 10.4. Inne narzędzia

- `kubed` — kontroler do synchronizacji zasobów Kubernetes (np. wpisów tajnych, ConfigMaps) między przestrzeniami nazw, zapewniający spójność konfiguracji.
- `Mailrelay` — scentralizowany przekaźnik SMTP do wysyłania powiadomień z różnych komponentów systemu, w tym Alertmanagera, CronJobs i potoków CI/CD.