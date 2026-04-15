# Session 25 — Observability

---

## Observability Overview

- **Monitoring** — something is happening
- **Logging** — what is happening?
- **Tracing** — where is it happening?

**Definition:** The capability to continuously generate and discover actionable insights based on signals from the system under observation, with the goal to influence the system.

**Analogy:** Think of a car dashboard — metrics are the gauges (speed, temperature — they tell you something is wrong), logs are the black box recorder (what happened step by step), traces are the GPS track (the path the journey took). You need all three to understand a problem fully.

---

## Key Definitions

| Term | Description |
|------|-------------|
| **System** | The platform we care about (Kubernetes) |
| **Signals** | Information observable from outside the system (logs, metrics, traces) |
| **Sources** | Components from which we retrieve signals |
| **Agents** | Responsible for signal collection and routing |
| **Destinations** | Where signals are stored, visualized, and used for analytics |
| **Telemetry** | Process of collecting signals from sources, routing via agents, and ingesting to destinations |

---

## Signal Correlation

Effective observability requires correlating signals across the three pillars:
- **Metrics** tell you something is wrong (alert)
- **Logs** tell you what went wrong (detail)
- **Traces** tell you where it went wrong (distributed path)

---

## Logs

Signals with a textual payload that capture an event. Usually structured and timestamped with contextual data as labels.

**Log Levels:** DEBUG, INFO, WARNING, ERROR, CRITICAL

**Log Standards:** Syslog, JSON (Kubernetes/Docker), Apache, Text, OTLP

**Log Routers/Agents:**
- CNCF: FluentD, Grafana Alloy, Promtail, FluentBit, OpenTelemetry Collector
- Cloud: Amazon CloudWatch, Azure Monitor, Google Cloud Operations Suite
- Proprietary: Logstash/Filebeat (Elastic), Datadog Agent, Splunk Forwarder

**Use Cases:**
- Developer — debugging and testing (performance or soak test)
- SRE — identify code or bug responsible for an outage

---

## Grafana Loki

A horizontally scalable, multi-tenant log aggregation system. Designed by Grafana Labs — "like Prometheus, but for logs."

**Key Design Principle:**
- Does NOT index log content — only indexes labels (metadata)
- Much cheaper to operate than Elasticsearch-based solutions

**Architecture:**
- **Agents** (Promtail / Grafana Alloy) — collect and ship logs
- **Loki** — stores and indexes log streams by labels
- **Grafana** — queries and visualizes logs

**How it works in Kubernetes:**
- Agent runs as DaemonSet on every node
- Collects container logs from `/var/log/pods`
- Enriches with K8s metadata labels (namespace, pod, container)
- Ships to Loki for storage and querying

---

## LogQL

LogQL is Loki's query language — inspired by PromQL.

**Log Stream Selector (filter by labels):**
```
{namespace="production", app="frontend"}
{job="kubernetes-pods"} |= "error"
```

**Line Filters:**
```
|= "error"      # line contains "error"
!= "debug"      # line does NOT contain "debug"
|~ "err.*"       # line matches regex
!~ "health"      # line does NOT match regex
```

**Log Pipeline (parse and transform):**
```
| json                           # parse JSON logs
| logfmt                         # parse logfmt logs
| line_format "{{.message}}"     # reformat output
| label_format level=severity    # rename labels
```

**Metric Queries (aggregate logs into metrics):**
```
rate({app="frontend"} |= "error" [5m])     # errors per second
count_over_time({app="api"} [1h])          # log count per hour
```

---

## Metrics

Numerical signals sampled at regular intervals. Comprise a name, numerical value, and metadata for context.

**Retrieval:** Push or pull model. Prometheus uses **pull** (HTTP endpoint scraping).

**Important Metric Frameworks:**

| Framework | Metrics | Best For |
|-----------|---------|----------|
| **USE** | Utilization, Saturation, Errors | Infrastructure (nodes, disks) |
| **RED** | Rate, Errors, Duration | Services (APIs, microservices) |
| **LETS** (Four Golden Signals) | Latency, Traffic, Errors, Saturation | Google SRE methodology |

---

## Prometheus

A monitoring system and time-series database. Provides a full monitoring pipeline:
- Tracking and exposing metrics (instrumentation)
- Collecting metrics
- Storing metrics
- Querying metrics for alerting, dashboarding, etc.

**Key Concepts:**
- Each time series is uniquely identified by a **metric name** and a set of **labels** (key/value pairs)
- Metrics exposed over HTTP endpoints (usually `/metrics`)
- Query language: **PromQL**
- Integrated alerting: **Alertmanager**

---

## Prometheus Scrape Pipeline

```
┌──────────┐     ┌────────────┐     ┌──────────┐     ┌───────────┐
│ App      │     │ Prometheus │     │Alertmgr  │     │ Grafana   │
│ /metrics │────►│ scrape +   │────►│ route +  │     │ visualize │
│ endpoint │     │ store TSDB │     │ notify   │     │ + query   │
└──────────┘     └──────┬─────┘     └──────────┘     └─────┬─────┘
                        │                                   │
                        └───────────── PromQL ──────────────┘
```

1. Your app (or exporter) exposes a `/metrics` HTTP endpoint
2. Prometheus scrapes it on a configurable interval (default: 15s)
3. Data is stored in its time-series database (TSDB)
4. PromQL queries feed both Alertmanager rules and Grafana dashboards
5. Alertmanager routes firing alerts to the right notification channel

---

## Prometheus - Exporters

- Agents that fetch non-Prometheus metrics, translate them, and expose via HTTP endpoint
- Kubernetes components (API Server, kubelet, etcd) expose native Prometheus metrics endpoints
- Prometheus implements native Kubernetes service discovery

---

## Prometheus Operator

Simplifies and automates Prometheus deployment and management.

**Custom Resource Definitions:**

| CRD | Purpose |
|-----|---------|
| `Prometheus` | Desired state of Prometheus StatefulSet |
| `Alertmanager` | Desired state of Alertmanager StatefulSet |
| `ServiceMonitor` | Set of services to monitor |
| `PodMonitor` | Set of pods to monitor |
| `PrometheusRule` | Recording or alerting rules |

**Installation:** `kube-prometheus-stack` Helm chart (includes Prometheus, Alertmanager, Grafana, and default dashboards)

**Metric Sources:**
- Container metrics — from kubelet's cAdvisor
- Pod & K8s API metrics — **kube-state-metrics** (queries kube-apiserver)
- Control plane components (API server, etcd) — monitored directly

---

## ServiceMonitor Example

A `ServiceMonitor` tells the Prometheus Operator which services to scrape and how. The application just needs a Service with a named port exposing `/metrics`.

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-monitor
  namespace: production
  labels:
    release: kube-prometheus-stack   # must match Prometheus selector
spec:
  selector:
    matchLabels:
      app: my-app                    # selects Services with this label
  namespaceSelector:
    matchNames:
      - production
  endpoints:
    - port: http-metrics             # named port on the Service
      path: /metrics
      interval: 30s
      scrapeTimeout: 10s
```

The corresponding Service must expose the port with the same name:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: production
  labels:
    app: my-app
spec:
  selector:
    app: my-app
  ports:
    - name: http-metrics
      port: 8080
      targetPort: 8080
```

---

## PromQL Examples

PromQL is a functional query language for slicing and aggregating time-series data.

**HTTP request rate (requests per second, 5-minute window):**
```promql
rate(http_requests_total{job="my-app"}[5m])
```

**HTTP error percentage (5xx errors as % of total traffic):**
```promql
100 * sum(rate(http_requests_total{job="my-app", status=~"5.."}[5m]))
  /
sum(rate(http_requests_total{job="my-app"}[5m]))
```

**Container CPU usage as % of its request:**
```promql
100 * sum by (pod, namespace) (
  rate(container_cpu_usage_seconds_total{container!=""}[5m])
)
/
sum by (pod, namespace) (
  kube_pod_container_resource_requests{resource="cpu", container!=""}
)
```

**Container memory usage (bytes) by namespace:**
```promql
sum by (namespace) (
  container_memory_working_set_bytes{container!="", container!="POD"}
)
```

**P99 request latency (histogram):**
```promql
histogram_quantile(0.99,
  sum by (le, job) (
    rate(http_request_duration_seconds_bucket{job="my-app"}[5m])
  )
)
```

---

## Alertmanager

Aggregates, routes, throttles, and sends notifications for alerts generated by Prometheus.

**Key Concepts:**
- **Alerting rules** — defined in PrometheusRule CRD, evaluated by Prometheus
- **Routing** — directs alerts to the right receiver based on labels
- **Grouping** — combines related alerts into a single notification
- **Silencing** — temporarily suppress specific alerts
- **Inhibition** — suppress alerts when a related alert is already firing

**Notification Channels:** Slack, PagerDuty, email, webhooks, OpsGenie, etc.

---

## Grafana

Open-source visualization and analytics platform. The standard dashboarding tool for Kubernetes observability.

**Key Concepts:**
- **Data Sources** — connections to backends (Prometheus, Loki, Tempo, etc.)
- **Dashboards** — collections of panels visualizing data
- **Panels** — individual visualizations (graphs, tables, gauges, heatmaps)
- **Variables** — template variables for dynamic, reusable dashboards

**Common Kubernetes Dashboards:**
- Cluster overview — node CPU, memory, pod count
- Namespace workload dashboards — per-deployment metrics
- Pod resource usage — CPU/memory vs requests/limits
- CoreDNS, etcd, API server dashboards

**Installation:** Part of `kube-prometheus-stack` Helm chart

---

## OpenTelemetry Overview

A CNCF project providing a vendor-neutral observability framework. Merges OpenTracing + OpenCensus.

**Three Signal Types:** Traces, Metrics, Logs

**Components:**
- **SDKs** — instrument your application code (auto or manual)
- **Collector** — receive, process, and export telemetry data
- **OTLP Protocol** — standard protocol for sending telemetry

**Why it matters:**
- Instrument once, export to any backend (Prometheus, Jaeger, Datadog, etc.)
- Avoids vendor lock-in
- Becoming the standard for cloud-native observability

---

## Key Takeaways

- Observability has three pillars — metrics, logs, and traces. Each answers a different question. Effective incident response uses all three together: metrics fire the alert, logs explain what happened, traces show where across services.
- **Prometheus** is the de-facto standard for Kubernetes metrics. It scrapes `/metrics` endpoints on a pull model and stores data in a time-series database queryable with PromQL.
- **ServiceMonitors** (from the Prometheus Operator) are the GitOps-native way to configure scrape targets — no manual Prometheus config edits required.
- Learn PromQL basics — `rate()`, `sum by()`, `histogram_quantile()`, and ratio queries cover the vast majority of real-world alerting and dashboarding needs.
- **Grafana Loki** keeps log costs low by indexing only labels, not log content — the trade-off is that full-text search is slower than Elasticsearch but sufficient for label-driven workflows.
- The **kube-prometheus-stack** Helm chart is the fastest path to a production-grade observability stack (Prometheus + Alertmanager + Grafana + pre-built K8s dashboards) on any cluster.
- **OpenTelemetry** is the emerging standard for instrumentation — instrument your application once with the OTel SDK and route signals to whatever backend you choose.
