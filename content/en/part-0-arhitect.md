+++
date = '2025-08-25T13:00:00+02:00'
draft = false
title = 'StreamForge Architectural Manifesto: Why We Bet Everything on Asynchronicity'
weight = 1
+++

## Colleagues,

This document is our architectural manifesto. Its purpose is not just to describe, but to **justify** the fundamental choice that defines our entire engineering culture: **the rejection of synchronous interaction in favor of a 100% asynchronous, event-driven model**.

I want to show in detail, at the level of principles and practical consequences, why the classic approach with direct API calls for our domain is a path to creating a fragile, unscalable, and difficult-to-maintain "distributed monolith". And why **Apache Kafka** as the "central nervous system" is not just a trendy technology, but a strategic investment in **reliability, scalability, and development speed** for years to come.

---

## Part 1: The Anatomy of Pain. The Deep Problems of Synchronous Systems.

Let's be honest. Building a system on direct API calls (whether REST or gRPC) is the most obvious and fastest way to start. Service A calls service B. Simple and clear. But for our domain, it's an architectural dead end.

The crypto market is a perfect storm: 24/7 volatility, huge volumes of data, and unpredictable peak loads. Trying to build something here on synchronous calls inevitably leads to the following problems:

1.  **Cascading Failures:** Imagine a chain: `loader` (receives data from the exchange) -> `parser` (converts it to our format) -> `writer` (writes to the DB). If the `writer` starts to slow down due to database load or restarts, it creates **backpressure**. The `parser` waits, its buffers overflow. It stops accepting data from the `loader`. The `loader` is also forced to stop. As a result, a one-minute failure at the database level leads to a complete halt in data reception and its loss. We are building a "house of cards".

2.  **"Chatty" Microservices and the "Distributed Monolith":** In a synchronous model, services are forced to constantly "chat" with each other. This creates rigid, implicit dependencies. Service A must know the address of service B. It must know its API, handle its specific errors. Over time, this turns into a "distributed monolith" - changing something in one service is scary because it's unclear where and how it will backfire.

3.  **The Scaling Problem:** How do you scale such a system? If the `parser` becomes a bottleneck, we can run 10 instances of it. But now the `loader` needs to know how to balance the load between them? And what if one of the `parser`s dies? The `loader` must implement retry logic and switch to a live instance. We start duplicating complex fault tolerance logic in every service.

---

## Part 2: Our Bet - The Persistent Log as the Heart of the System.

Realizing this, we made a strategic bet on an **event-driven architecture (EDA)**. But not just on a "message queue", but on **Apache Kafka** as an implementation of the "distributed persistent log" pattern.

**What is the key difference from, say, RabbitMQ?**
-   **RabbitMQ (and similar brokers)** is essentially a postman. It took a message, delivered it to the first recipient, and the message disappeared. This is great for distributing tasks, but not for streaming data processing.
-   **Kafka** is more like a "central archive" or "logbook" for the entire company. Every event ("BTCUSDT trade at 12:05:03") is written to this log (topic) and remains there for a specified time (e.g., 7 days), even after it has been read.

This fundamental difference changes everything. Our services no longer communicate with each other. They interact with this central archive:
-   **Producers** simply append new events to the end of the log. They don't care who, when, or how many times will read this event.
-   **Consumers** read this log, each at its own pace. Kafka remembers for each consumer (or rather, for a `consumer group`) where it left off in the log (this is called an `offset`).

#### 2.1. Anatomy of Kafka: Partitions, Keys, Offsets, and Consumer Groups

To understand the full power, you need to understand four concepts:
-   **Partitions:** A topic in Kafka is not one large log, but a set of N parallel, ordered logs called partitions. **A partition is the unit of parallelism.**
-   **Keys:** When a producer sends an event, it can specify a key (e.g., `symbol="BTCUSDT"`). Kafka guarantees that all events with the same key will always go to the same partition. This **preserves the order of events within a single entity** (all BTCUSDT trades will go strictly one after another).
-   **Offsets:** Each consumer is responsible for tracking the last message it read in each partition. It periodically saves the message number (`offset`) back to Kafka. This gives consumers full control over the reading process.
-   **Consumer Groups:** Multiple instances of the same service (e.g., 5 `arango-connector` pods) can be combined into one consumer group (by specifying the same `group.id`). Kafka will automatically distribute all partitions of the topic among these 5 instances. If one of them fails, Kafka will **rebalance** its partitions among the remaining ones in a fraction of a second. This is the mechanism for fault tolerance and scaling.

---

## Part 3: The Superpowers We Get.

This architecture gives us three strategic advantages that are unattainable in the synchronous world.

### 3.1. Absolute Fault Tolerance and Self-Healing

Kafka acts as a giant shock absorber between services.
**Example:** Our `gnn-trainer` service (training graph models) is heavy and resource-intensive. It reads data from the `graph-features` topic. Let's say we want to deploy a new version of it. We just stop the old one and deploy the new one. This takes 5 minutes. For all these 5 minutes, the `graph-builder` service continues to work calmly and publish new graph features to the topic. They accumulate there. When `gnn-trainer` starts, it sees its old `offset`, realizes it's behind, and starts processing the accumulated data at an accelerated pace. **From the perspective of the system as a whole, there was no failure. There was a delay in processing, but not data loss or a shutdown.**

### 3.2. Elasticity and Linear Scaling

This is no longer a theory, but an operational reality.
**Example:** Our `raw-orderbooks` topic has 64 partitions. In quiet times, it is processed by 8 instances of `orderbook-processor`. Each processes 8 partitions. The Fed chairman begins to speak, volatility goes off the charts, the data stream increases 20-fold. Our Grafana dashboard shows that the `consumer lag` is growing.
**Our actions:** `kubectl scale deployment/orderbook-processor --replicas=64`.
**What happens next:** Kubernetes creates 56 new pods. They join the same consumer group. Kafka starts a rebalance, and in a few seconds, we have 64 instances, each processing one partition. The processing throughput increases 8-fold. When the load subsides, we can just as easily return the number of replicas to 8. **We have moved from a complex engineering problem of performance to a trivial operational task.**

### 3.3. Architectural Evolution and the "Data Mesh" Concept

This is the most powerful strategic advantage. We are turning our data streams into **"products"**.
The team responsible for the loaders owns the "product" - the `raw-trades` topic. Their responsibility is to deliver high-quality, valid data to this topic with a specific SLA.
-   Tomorrow, the **Data Science** team will want to build a volatility prediction model. They don't need to go to the loader team. They just create their own `volatility-predictor` service with a new `consumer group` and start reading data from `raw-trades`.
-   The day after tomorrow, the **Security** team will want to implement a fraud monitoring system. They create their own `fraud-detector` service and subscribe to the same topic.

All these teams work **in parallel and independently**. They cannot interfere with each other or break the main data pipeline. This allows us to develop the product with unprecedented speed and flexibility. We are putting into practice the concept of a **Data Mesh**, where data becomes a decentralized, easily accessible, and reliable resource for the entire company.

---

### Conclusion: We Are Investing in Speed.

The transition to EDA and Kafka is not about making things more complex for the sake of complexity. It is a conscious trade-off. We accept a little more complexity at the start to gain fundamental advantages in the future.

We are building a platform that gives us:
-   **Reliability** built into the architecture itself.
-   **Scalability** limited only by the resources of our cluster, not by the software design.
-   **Speed and flexibility** in development, allowing us to quickly test hypotheses and bring new products to market.

This is our foundation. And it is rock solid.