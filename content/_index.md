+++
date = '2025-08-25T13:00:00+02:00'
draft = false
title = 'StreamForge Architectural Manifesto: Why Were Betting Everything on Asynchronicity'
weight = 55
+++

### Colleagues,

This document is our architectural manifesto. Its goal is not just to describe, but to **justify** the fundamental choice that defines our entire engineering culture: **the rejection of synchronous interaction in favor of a 100% asynchronous, event-driven model**.

I want to show in detail, at the level of principles and practical consequences, why the classic approach with direct API calls is a path to creating a fragile, unscalable, and hard-to-maintain "distributed monolith" in our domain. And why **Apache Kafka**, in the role of a "central nervous system," is not just a trendy technology, but a strategic investment in **reliability, scalability, and development speed** for years to come.

---

### Part 1: The Anatomy of Pain. The Deep Problems of Synchronous Systems.

Let's be frank. Building a system on direct API calls (be it REST or gRPC) is the most obvious and fastest way to start. Service A calls Service B. Simple and clear. But for our domain, it's an architectural dead end.

The crypto market is a perfect storm: 24/7 volatility, gigantic data volumes, and unpredictable peak loads. Trying to build something on synchronous calls here inevitably leads to the following problems:

1.  **Cascading Failures:** Imagine the chain: `loader` (receives data from the exchange) -> `parser` (converts it to our format) -> `writer` (writes to the DB). If the `writer` starts to slow down due to database load or restarts, it creates **backpressure**. The `parser` waits, its buffers overflow. It stops accepting data from the `loader`. The `loader` is also forced to stop. In the end, a one-minute failure at the database level leads to a complete halt in data ingestion and data loss. We are building a "house of cards."

2.  **"Chatty" Microservices and the "Distributed Monolith":** In a synchronous model, services are forced to constantly "chat" with each other. This creates rigid, implicit dependencies. Service A must know the address of Service B. It must know its API, handle its specific errors. Over time, this turns into a "distributed monolith" — changing something in one service is scary because it's unclear where and how it will have repercussions.

3.  **The Scaling Problem:** How do you scale such a system? If the `parser` becomes a bottleneck, we can run 10 instances of it. But now the `loader` needs to know how to balance the load between them. What if one of the `parser`s dies? The `loader` must implement retry logic and switch to a live instance. We start duplicating complex fault-tolerance logic in every service.

---

### Part 2: Our Bet — A Persistent Log as the Heart of the System.

Realizing this, we made a strategic bet on an **Event-Driven Architecture (EDA)**. But not just any "message queue," but on **Apache Kafka** as an implementation of the "distributed persistent log" pattern.

**What is the key difference from, say, RabbitMQ?**
-   **RabbitMQ (and similar brokers)** is essentially a postman. It takes a message, delivers it to the first recipient, and the message disappears. This is great for distributing tasks, but not for data streaming.
-   **Kafka** is more like a "central archive" or a "company-wide logbook." Every event ("BTCUSDT trade at 12:05:03") is written to this log (a topic) and remains there for a set time (e.g., 7 days), even after being read.

This fundamental difference changes everything. Our services no longer communicate with each other directly. They interact with this central archive:
-   **Producers** simply append new events to the end of the log. They don't care who reads their message, when, or how many times.
-   **Consumers** read this log, each at its own pace. Kafka remembers for each consumer (or more accurately, for each `consumer group`) where it left off in the log (this is called an `offset`).

#### 2.1. The Anatomy of Kafka: Partitions, Keys, Offsets, and Consumer Groups

To understand the full power, you need to grasp four concepts:
-   **Partitions:** A topic in Kafka is not one big log, but a set of N parallel, ordered logs called partitions. **A partition is the unit of parallelism.**
-   **Keys:** When a producer sends an event, it can specify a key (e.g., `symbol="BTCUSDT"`). Kafka guarantees that all events with the same key will always land in the same partition. This **preserves the order of events within a single entity** (all trades for BTCUSDT will follow each other strictly).
-   **Offsets:** Each consumer is responsible for tracking the last message it read in each partition. It periodically saves the number of this message (`offset`) back to Kafka. This gives consumers full control over the reading process.
-   **Consumer Groups:** Multiple instances of one service (e.g., 5 `arango-connector` pods) can join a single consumer group (by specifying the same `group.id`). Kafka will automatically distribute all partitions of the topic among these 5 instances. If one of them fails, Kafka will **rebalance** its partitions among the remaining ones in a fraction of a second. This is the mechanism for fault tolerance and scalability.

---

### Part 3: The Superpowers We Gain.

This architecture gives us three strategic advantages that are unattainable in a synchronous world.

#### 3.1. Absolute Fault Tolerance and Self-Healing

Kafka acts as a giant shock absorber between services.
**Example:** Our `gnn-trainer` service (training graph models) is heavy and resource-intensive. It reads data from the `graph-features` topic. Let's say we want to deploy a new version of it. We just stop the old one and deploy the new one. This takes 5 minutes. For all these 5 minutes, the `graph-builder` service continues to work calmly and publish new graph features to the topic. They accumulate there. When the `gnn-trainer` starts up, it sees its old `offset`, realizes it's behind, and begins to process the accumulated data at high speed. **From the system's perspective, there was no failure. There was a processing delay, but no data loss or stoppage.**

#### 3.2. Elasticity and Linear Scaling

This is no longer theory, but operational reality.
**Example:** Our `raw-orderbooks` topic has 64 partitions. In quiet times, it is processed by 8 instances of `orderbook-processor`. Each processes 8 partitions. The Fed chairman begins to speak, volatility goes off the charts, and the data stream grows 20-fold. Our Grafana dashboard shows that the `consumer lag` is increasing.
**Our actions:** `kubectl scale deployment/orderbook-processor --replicas=64`.
**What happens next:** Kubernetes creates 56 new pods. They join the same consumer group. Kafka initiates a rebalance, and within seconds, we have 64 instances, each processing one partition. The processing throughput increases 8-fold. When the load subsides, we just as easily return the number of replicas to 8. **We have moved from a complex software engineering problem of performance to a trivial operational task.**

#### 3.3. Architectural Evolution and the "Data Mesh" Concept

This is the most powerful strategic advantage. We are turning our data streams into **"products"**.
The team responsible for the loaders owns the "product" — the `raw-trades` topic. Their responsibility is to supply this topic with high-quality, valid data with a specific SLA.
-   Tomorrow, the **Data Science** team wants to build a volatility prediction model. They don't need to go to the loader team. They just create their own `volatility-predictor` service with a new `consumer group` and start reading data from `raw-trades`.
-   The day after tomorrow, the **Security** team wants to implement a fraud monitoring system. They create their `fraud-detector` service and subscribe to the very same topic.

All these teams work **in parallel and independently**. They cannot interfere with each other or break the main data pipeline. This allows us to develop the product with unprecedented speed and flexibility. We are putting into practice the **Data Mesh** concept, where data becomes a decentralized, easily accessible, and reliable resource for the entire company.

---

### Conclusion: We Are Investing in Speed.

The transition to EDA and Kafka is not complication for complication's sake. It is a conscious trade-off. We accept a little more complexity at the start to gain fundamental advantages in the future.

We are building a platform that gives us:
-   **Reliability**, built into the architecture itself.
-   **Scalability**, limited only by the resources of our cluster, not by software design.
-   **Speed and flexibility** in development, allowing us to quickly test hypotheses and bring new products to market.

This is our foundation. And it is rock-solid.
