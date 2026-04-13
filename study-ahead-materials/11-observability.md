# Observability in Kubernetes

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Overview
Observability is how you understand what's happening inside your Kubernetes cluster and applications — without observability, you're operating blind. This section covers the three pillars: **Logs** (Grafana Loki/Promtail), **Metrics** (Prometheus, PromQL, Alertmanager, kube-state-metrics), and **Traces** (OpenTelemetry, Jaeger/Tempo). Together, these tools form the foundation of production monitoring for any Kubernetes platform team.

---

## 🎥 YouTube Videos

### Kubernetes Monitoring with Prometheus and Grafana — Complete Setup Guide for Beginners
[![Thumbnail](https://img.youtube.com/vi/tqI6m8wwCUw/0.jpg)](https://www.youtube.com/watch?v=tqI6m8wwCUw)
**Channel:** KodeKloud
> Published October 2025 — comprehensive walkthrough of deploying Prometheus and Grafana on Kubernetes from scratch, with dashboards, alerts, and scrape config explained.

### Kubernetes Monitoring with Prometheus and Grafana | Beginners Guide
[![Thumbnail](https://img.youtube.com/vi/dzBGhlF4M1U/0.jpg)](https://www.youtube.com/watch?v=dzBGhlF4M1U)
**Channel:** Anton Putra
> Beginner-friendly guide to setting up the full Prometheus + Grafana monitoring stack on Kubernetes, including node-exporter and kube-state-metrics.

### Kubernetes Monitoring Made Easy with Prometheus | KodeKloud
[![Thumbnail](https://img.youtube.com/vi/6xmWr7p5TE0/0.jpg)](https://www.youtube.com/watch?v=6xmWr7p5TE0)
**Channel:** KodeKloud
> Accessible free lab-based course on Prometheus monitoring for Kubernetes — covers scrape configs, labels, PromQL basics, and Grafana dashboard creation.

### Project 5: Setup Monitoring and Alerting on Kubernetes | Prometheus and Grafana Tutorial
[![Thumbnail](https://img.youtube.com/vi/gBdyIv9d_O8/0.jpg)](https://www.youtube.com/watch?v=gBdyIv9d_O8)
**Channel:** Abhishek Veeramalla
> Real-world project implementing a complete monitoring and alerting stack on Kubernetes — covers Alertmanager configuration and alert routing.

### Kubernetes Monitoring with Prometheus | Edureka Rewind
[![Thumbnail](https://img.youtube.com/vi/gjpCDP5lyig/0.jpg)](https://www.youtube.com/watch?v=gjpCDP5lyig)
**Channel:** Edureka
> February 2024 training session covering the complete Prometheus + Grafana stack on Kubernetes, including custom dashboards and node monitoring.

---

## 📚 Articles & Documentation

### Prometheus Documentation
🔗 [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
**Source:** prometheus.io | **Level:** Intermediate
> Official Prometheus docs — covers the data model, metric types (counter, gauge, histogram, summary), PromQL, scrape configuration, and Alertmanager integration.

### Grafana Loki Documentation
🔗 [Grafana Loki Documentation](https://grafana.com/docs/loki/latest/)
**Source:** grafana.com | **Level:** Intermediate
> Official Loki docs — the log aggregation system designed to be cost-effective and highly available. Covers Promtail, LogQL, and integration with Grafana.

### OpenTelemetry Documentation
🔗 [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
**Source:** opentelemetry.io | **Level:** Intermediate
> Official OpenTelemetry docs — the CNCF standard for instrumentation. Covers the collector, SDKs, traces, metrics, and logs with Kubernetes integration guides.

### Production-Ready Observability with Prometheus, Loki & Grafana
🔗 [Production-Ready Observability with Prometheus, Loki & Grafana](https://medium.com/@neamulkabiremon/production-ready-observability-with-prometheus-loki-grafana-2ce1ba9f7423)
**Source:** medium.com | **Level:** Intermediate
> Comprehensive 2025 guide to building a complete observability stack on Kubernetes — covers deployment, configuration, and integration of Prometheus, Loki, and Grafana.

### kube-state-metrics
🔗 [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics)
**Source:** github.com/kubernetes | **Level:** Intermediate
> Official repo and documentation for kube-state-metrics — generates metrics about Kubernetes object state (deployment replicas, pod status, PVC binding) for Prometheus to scrape.

### End-to-End Observability with Prometheus, Grafana, Loki, OpenTelemetry and Tempo
🔗 [End-to-End Observability with Prometheus, Grafana, Loki, OpenTelemetry and Tempo](https://dev.to/improving/end-to-end-observability-with-prometheus-grafana-loki-opentelemetry-and-tempo-3fpf)
**Source:** dev.to | **Level:** Advanced
> 2026 guide showing how Prometheus, Grafana, Loki, Tempo, kube-state-metrics, and OpenTelemetry work together as a complete open-source observability platform.

---

## 🗝️ Key Concepts to Know Before Class
- **The three pillars of observability**: *Logs* (what happened), *Metrics* (how much/how many), *Traces* (how a request flowed through the system).
- **Prometheus** scrapes metrics from endpoints (pull model), stores them as time-series, and evaluates alerting rules. **kube-state-metrics** exposes Kubernetes object state; **node-exporter** exposes host metrics.
- **PromQL** is Prometheus's query language. Key patterns: `rate()` for counter rates, `increase()` for totals, label selectors `{namespace="prod"}`, and `histogram_quantile()` for latency percentiles.
- **Alertmanager** handles alerts fired by Prometheus — routes, deduplicates, groups, and silences them, then sends to Slack/PagerDuty/email.
- **Grafana Loki** is a log aggregation system that indexes only metadata (labels), making it far cheaper than Elasticsearch. **Promtail** is the agent that ships logs to Loki.
- **OpenTelemetry** is the CNCF standard for distributed tracing and instrumentation — replacing vendor-specific clients (Jaeger client, Zipkin client) with a single unified API.
