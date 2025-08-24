+++
title = "Kafka"
type = "chapter"
weight = 1
+++

# Kafka (Strimzi) Infra Module

## What this does
- Installs Strimzi Operator (Helm).
- Creates a Kafka cluster with external `ingress` listener (TLS passthrough + SCRAM).
- Creates topics and a shared `user-streamforge` with ACLs.
- Outputs secret names for SCRAM password and Cluster CA.

## Prereqs
- `one-prime` already deployed (MetalLB, Traefik, cert-manager).
- DNS records pointing to Traefik LB IP for:
  - `k3-kafka-bootstrap.kafka.dmz.home`
  - `k3-kafka-{0,1,2}.kafka.dmz.home`

## Usage
```bash
cd infra/kafka
terraform init
terraform apply -var-file=tfvars/dev.tfvars