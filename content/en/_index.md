+++
date = '2025-08-24T21:13:04+02:00'
draft = false
title = 'Prerequisites and goals of the StreamForge project'
+++

# Part I: Prerequisites and goals of the "StreamForge" project

## 1.1. Cryptocurrency data: challenges and solutions

In the modern landscape of digital assets, cryptocurrency data serves as the fundamental basis for analytical processes and real-time decision-making. The characteristic features of this data are high volatility, continuous availability, and significant volumes of transactions and state updates (for example, the dynamics of the order book, high-frequency trading operations, aggregation of time series). This leads to increased requirements for the methodologies of their collection, processing, and extraction of valuable information, emphasizing the need to create reliable and high-performance data pipelines.

Key challenges include:
- **Variety of sources:** Data comes from various points through a REST API for historical data and WebSocket for real-time data, requiring the integration of heterogeneous streams.
- **Scalability and speed:** The system must support extreme loads, processing intensive data streams without delay.
- **Reliability:** Guarantee of data integrity and rapid recovery after possible failures.
- **Orchestrational complexity:** Effective coordination of complex sequences of tasks is necessary, such as "load -> save -> build graph -> train model".

## 1.2. StreamForge: Event-driven platform

StreamForge is an innovative event-driven platform designed for highly efficient data processing. The key architectural principle is decentralized interaction between components, which excludes direct service calls. All inter-service communication is carried out through the distributed message broker **Apache Kafka**. Each microservice publishes the generated data to the corresponding topics of the common bus, while other services subscribe to the data streams of interest to them. This paradigm provides exceptional flexibility, autonomy, and interchangeability of system components. Task orchestration is implemented through `queue-manager`, which dynamically activates the appropriate modules to perform specified operations.

The application of this approach guarantees high scalability, adaptability to changing requirements, and increased fault tolerance of the entire system.

## 1.3. Project Mission

1.  **Creation of a unified data source:** Consolidation of the processes of collecting, verifying, and storing market data to ensure prompt and convenient access to high-quality information.
2.  **Formation of an innovative environment for Data Science:** Providing a specialized platform for the development, testing, and validation of analytical models, including advanced architectures of graph neural networks (GNN).
3.  **Building a reliable foundation for algorithmic trading:** Development of a high-performance and fault-tolerant data pipeline, which is critically important for the functioning of automated trading systems.
4.  **Comprehensive process automation:** Minimization of manual intervention at all stages of the data life cycle, from collection to analytical processing, to increase operational efficiency.

## 1.4. Practical use cases

- **Scenario 1: Training models on historical data.**
  - **Objective:** Training a GNN model on retrospective transaction data and aggregated 5-minute candles for the `BTCUSDT` trading pair over the last month.
  - **Method:** Activation of a full data processing cycle through `queue-manager`. Tasks are performed by Kubernetes Jobs: `loader-producer` loads data into Apache Kafka, `arango-connector` ensures their persistent storage in ArangoDB, `graph-builder` forms the graph structure, and `gnn-trainer` performs model training.

- **Scenario 2: Real-time market monitoring.**
  - **Objective:** Obtaining streaming data on transactions and the state of the order book in real time for the `ETHUSDT` trading pair.
  - **Method:** The `loader-ws` module establishes a connection with WebSocket and transmits data to Apache Kafka. The developing visualization module subscribes to the corresponding topics to display data on an interactive dashboard.

- **Scenario 3: Express data analysis.**
  - **Objective:** Verification of the hypothesis about the correlation between trading volumes and market volatility.
  - **Method:** Using `Jupyter Server` to establish a connection with ArangoDB and conduct analytical research based on data already aggregated and processed by the StreamForge system.

These powerful functional capabilities make StreamForge an indispensable tool for anyone who strives for maximum efficiency in working with cryptocurrency data.