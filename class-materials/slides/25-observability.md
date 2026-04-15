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

**Common Exporters:**
| Exporter | What It Exposes |
|----------|----------------|
| **node-exporter** | Host-level CPU, memory, disk, network (runs as DaemonSet) |
| **kube-state-metrics** | Kubernetes object state (pod status, deployment replicas, job completions) |
| **blackbox-exporter** | Probe endpoints for uptime (HTTP, TCP, DNS, ICMP) |
| **mysqld-exporter** | MySQL server metrics |
| **redis-exporter** | Redis metrics |
| **postgres-exporter** | PostgreSQL metrics |

---

## Instrumentation — What It Is and Why It Matters

> **Analogy:** A car's engine doesn't come with a dashboard by default — the manufacturer instruments it by adding sensors (temperature, RPM, oil pressure). Instrumentation is the act of adding those sensors to your application so observability tools have something to read.

**Instrumentation** = adding code or configuration to your application so it emits observability signals (metrics, traces, logs) that monitoring systems can collect.

Without instrumentation, Kubernetes can only tell you about *infrastructure* (CPU, memory, pod status). With instrumentation, you can answer *application-level* questions:
- How many requests per second is my API handling?
- What's the 95th percentile response time?
- Which database query is the bottleneck?
- Where did this request spend time across microservices?

---

## Instrumentation Approaches

There are three main approaches, from least to most effort:

```
┌─────────────────────────────────────────────────────────────────┐
│                     Instrumentation Spectrum                    │
│                                                                 │
│  No code changes              Some code              Deep code  │
│  ◄──────────────────────────────────────────────────────────►   │
│                                                                 │
│  Infrastructure    Exporters/    Auto-         Manual            │
│  metrics           agents        instrument    instrument        │
│  (kubelet,         (node-        (OTel agent,  (Prometheus       │
│   cAdvisor)        exporter,     Datadog,      client, OTel     │
│                    blackbox)     Dynatrace)    SDK)              │
│                                                                 │
│  "Free" with K8s   DaemonSet    Init container  App code changes │
│                    deploy        or sidecar                      │
└─────────────────────────────────────────────────────────────────┘
```

| Approach | What you get | Effort | Best for |
|----------|-------------|--------|----------|
| **Infrastructure metrics** | CPU, memory, disk, network, pod state | Zero — built into K8s | Cluster health, capacity planning |
| **Exporters / agents** | Database stats, uptime probes, host metrics | Deploy a DaemonSet or sidecar | Third-party software (MySQL, Redis, NGINX) |
| **Auto-instrumentation** | HTTP request rate, latency, error rate, traces | Add an annotation | Standard web frameworks (Spring Boot, Express, Flask, Django) |
| **Manual instrumentation** | Custom business metrics, fine-grained spans | Write code | Domain-specific metrics (orders/sec, payment failures, queue depth) |

---

## Prometheus Instrumentation (Client Libraries)

Prometheus uses a **pull model** — your app exposes a `/metrics` HTTP endpoint, and Prometheus scrapes it. You add metrics using **Prometheus client libraries**.

**Supported Languages:** Go, Java, Python, Ruby, .NET, Node.js, Rust, and more

**Four Metric Types:**

| Type | Description | Example |
|------|-------------|---------|
| **Counter** | Only goes up (resets on restart) | `http_requests_total`, `errors_total` |
| **Gauge** | Goes up and down | `temperature`, `active_connections`, `queue_size` |
| **Histogram** | Bucketized distribution of values | `http_request_duration_seconds` (with percentiles) |
| **Summary** | Like histogram but calculates quantiles client-side | `rpc_duration_seconds` (less common, prefer histogram) |

---

## Prometheus Instrumentation — Python Example

```python
from prometheus_client import Counter, Histogram, start_http_server
import time

# Define metrics
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']        # labels
)

REQUEST_LATENCY = Histogram(
    'http_request_duration_seconds',
    'HTTP request latency in seconds',
    ['method', 'endpoint'],
    buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
)

# Instrument your handler
def handle_request(method, endpoint):
    start = time.time()
    try:
        result = process_request()                # your app logic
        REQUEST_COUNT.labels(method, endpoint, '200').inc()
        return result
    except Exception:
        REQUEST_COUNT.labels(method, endpoint, '500').inc()
        raise
    finally:
        REQUEST_LATENCY.labels(method, endpoint).observe(time.time() - start)

# Expose /metrics on port 8080
start_http_server(8080)
```

**What `/metrics` output looks like:**
```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",endpoint="/api/orders",status="200"} 1547
http_requests_total{method="GET",endpoint="/api/orders",status="500"} 12

# HELP http_request_duration_seconds HTTP request latency in seconds
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{method="GET",endpoint="/api/orders",le="0.1"} 1200
http_request_duration_seconds_bucket{method="GET",endpoint="/api/orders",le="0.5"} 1500
http_request_duration_seconds_bucket{method="GET",endpoint="/api/orders",le="+Inf"} 1547
http_request_duration_seconds_sum{method="GET",endpoint="/api/orders"} 312.5
http_request_duration_seconds_count{method="GET",endpoint="/api/orders"} 1547
```

This is the raw text that Prometheus scrapes every 15-30 seconds. Each line is a time series identified by its metric name and labels.

---

## Prometheus Instrumentation — Go Example

```go
package main

import (
    "net/http"
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    requestCount = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )

    requestLatency = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request latency",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "endpoint"},
    )
)

func init() {
    prometheus.MustRegister(requestCount, requestLatency)
}

func main() {
    // Your app routes here...

    // Expose /metrics endpoint for Prometheus to scrape
    http.Handle("/metrics", promhttp.Handler())
    http.ListenAndServe(":8080", nil)
}
```

---

## OpenTelemetry Instrumentation

OpenTelemetry takes a different approach from Prometheus — instead of exposing an endpoint and waiting to be scraped, OTel **pushes** telemetry to a Collector (or directly to a backend).

**Key difference:**
```
Prometheus:     App ──/metrics──► Prometheus pulls
OpenTelemetry:  App ──OTLP push──► Collector ──► Any backend
```

**OTel covers all three signals** (metrics + traces + logs) with a single SDK, while Prometheus only handles metrics.

### Auto-Instrumentation (Zero Code Changes)

Most web frameworks can be auto-instrumented — the OTel agent intercepts HTTP calls, database queries, and gRPC calls automatically:

**Java (agent JAR):**
```bash
java -javaagent:opentelemetry-javaagent.jar \
  -Dotel.service.name=order-service \
  -Dotel.exporter.otlp.endpoint=http://otel-collector:4317 \
  -jar myapp.jar
```

**Python:**
```bash
pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-bootstrap -a install     # auto-install framework instrumentors

OTEL_SERVICE_NAME=order-service \
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317 \
opentelemetry-instrument python app.py
```

**Node.js:**
```bash
npm install @opentelemetry/auto-instrumentations-node
OTEL_SERVICE_NAME=order-service \
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317 \
node --require @opentelemetry/auto-instrumentations-node/register app.js
```

Auto-instrumentation captures: HTTP request/response metrics, database query traces, gRPC call spans, and framework-specific events — with zero application code changes.

---

## OTel Manual Instrumentation — Python Example

When auto-instrumentation isn't enough (custom business metrics, domain-specific spans):

```python
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter

# Setup (typically in app startup)
trace.set_tracer_provider(TracerProvider())
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint="otel-collector:4317"))
)

tracer = trace.get_tracer("order-service")
meter = metrics.get_meter("order-service")

# Custom business metric
orders_placed = meter.create_counter(
    "orders_placed_total",
    description="Total orders placed",
    unit="1"
)

# Custom trace span
def place_order(order):
    with tracer.start_as_current_span("place_order") as span:
        span.set_attribute("order.id", order.id)
        span.set_attribute("order.total", order.total)
        span.set_attribute("order.items", len(order.items))

        validate_inventory(order)     # auto-creates child span if instrumented
        charge_payment(order)         # auto-creates child span if instrumented

        orders_placed.add(1, {"payment_method": order.payment_method})
        return order
```

This produces both a custom metric (`orders_placed_total`) and a trace span (`place_order`) with business context that auto-instrumentation alone cannot capture.

---

## Prometheus vs OTel Instrumentation — When to Use Which

| Aspect | Prometheus Client | OpenTelemetry SDK |
|--------|------------------|-------------------|
| **Signals** | Metrics only | Metrics + Traces + Logs |
| **Model** | Pull (expose `/metrics`) | Push (send to Collector) |
| **Backend lock-in** | Prometheus-specific format | Vendor-neutral (OTLP) |
| **Auto-instrumentation** | No (manual only) | Yes (agent-based) |
| **Maturity** | Battle-tested, very stable | GA for traces/metrics, maturing for logs |
| **K8s ecosystem** | Deep (ServiceMonitor, kube-prometheus-stack) | Growing (OTel Operator) |
| **Best for** | Infrastructure/platform teams already on Prometheus | Greenfield apps, multi-backend environments, when you need tracing |

**Practical Guidance:**
- **Already have Prometheus?** Keep using Prometheus client libraries for metrics. Add OTel SDK for tracing.
- **New application?** Use OTel SDK for everything — it can export metrics in Prometheus format via the Collector's Prometheus exporter.
- **Using Datadog/Dynatrace/Cloud Ops?** Use OTel SDK — these platforms all accept OTLP natively, so you instrument once and switch backends freely.
- **Both can coexist** — many teams use Prometheus client for infrastructure metrics and OTel SDK for application traces in the same cluster.

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

## OpenTelemetry (OTel)

A **CNCF graduated project** providing a vendor-neutral observability framework. Created by merging two earlier projects — OpenTracing and OpenCensus — into a single standard.

> **Analogy:** OpenTelemetry is like a universal power adapter. Your app speaks one "language" (OTLP), and the adapter (Collector) converts it to whatever plug your destination requires — Prometheus, Jaeger, Datadog, Dynatrace, or any other backend.

**Three Signal Types:** Traces, Metrics, Logs

---

## OpenTelemetry - Architecture

```
┌─────────────────────┐
│    Your Application  │
│                      │
│  OTel SDK            │
│  (auto or manual     │
│   instrumentation)   │
└──────────┬───────────┘
           │ OTLP (gRPC/HTTP)
           ▼
┌─────────────────────────────────────────────┐
│          OTel Collector                     │
│                                             │
│  Receivers ──► Processors ──► Exporters     │
│  (OTLP,        (batch,        (Prometheus,  │
│   Jaeger,       filter,        Jaeger,      │
│   Zipkin)       sample)        OTLP,        │
│                                Datadog,     │
│                                Dynatrace,   │
│                                Cloud Ops)   │
└─────────────────────────────────────────────┘
           │                    │
     ┌─────┘                    └─────┐
     ▼                                ▼
┌──────────┐                   ┌──────────────┐
│Prometheus│                   │ Datadog /    │
│+ Grafana │                   │ Dynatrace /  │
│          │                   │ Cloud Ops    │
└──────────┘                   └──────────────┘
```

---

## OpenTelemetry - Key Components

**SDKs (Instrumentation):**
- Available for: Go, Java, Python, Node.js, .NET, Rust, and more
- **Auto-instrumentation** — inject at runtime, zero code changes (Java agent, Python `opentelemetry-instrument`, K8s OTel Operator)
- **Manual instrumentation** — add spans, metrics, and log enrichment in your code for custom business logic

**Collector:**
- A vendor-agnostic proxy that receives, processes, and exports telemetry
- **Receivers** — accept data (OTLP, Jaeger, Prometheus scrape, Zipkin, etc.)
- **Processors** — batch, filter, sample, enrich, transform
- **Exporters** — send to backends (Prometheus, Jaeger, OTLP, Datadog, Dynatrace, Google Cloud, etc.)
- Deployed as DaemonSet (per-node) or Deployment (cluster-level gateway)

**OTLP (OpenTelemetry Protocol):**
- The native wire protocol for OTel — supports all three signal types
- gRPC and HTTP/protobuf transports
- Increasingly supported as a native ingest format by backends (Grafana, Datadog, Dynatrace, Google Cloud)

---

## OpenTelemetry - Auto-Instrumentation in Kubernetes

The **OpenTelemetry Operator** for Kubernetes can automatically inject instrumentation into pods — no application code changes required.

```yaml
# Install the OTel Operator
helm install opentelemetry-operator open-telemetry/opentelemetry-operator

# Create an Instrumentation resource
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: auto-instrumentation
  namespace: production
spec:
  exporter:
    endpoint: http://otel-collector.observability:4317
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "0.25"        # sample 25% of traces
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest
```

**Inject into a Deployment by adding an annotation:**
```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-java: "true"      # for Java apps
    # instrumentation.opentelemetry.io/inject-python: "true"   # for Python apps
    # instrumentation.opentelemetry.io/inject-nodejs: "true"   # for Node.js apps
```

The Operator's mutating webhook injects a sidecar init container that adds the OTel agent to your app at startup — similar to how Istio injects Envoy sidecars.

---

## OpenTelemetry - Distributed Tracing

Traces follow a request as it travels across multiple services — the signal that metrics and logs cannot provide alone.

```
User request
     │
     ▼
┌─────────────────────────────────────────────────────────────┐
│  Trace: abc123                                              │
│                                                             │
│  ├── Span: API Gateway        (12ms)                        │
│  │   ├── Span: Auth Service   (3ms)                         │
│  │   └── Span: Order Service  (8ms)                         │
│  │       ├── Span: Inventory  (2ms)                         │
│  │       └── Span: Payment    (5ms)  ◄── bottleneck here    │
│  └── Total: 12ms                                            │
└─────────────────────────────────────────────────────────────┘
```

**Key Concepts:**
- **Trace** — the full journey of a request across services
- **Span** — a single operation within a trace (one service, one function call)
- **Context propagation** — passing trace IDs across service boundaries via HTTP headers (`traceparent`)
- **Sampling** — controlling what percentage of traces are recorded (100% is expensive at scale)

**Trace Backends:**
- Jaeger (CNCF graduated) — open-source, self-hosted
- Grafana Tempo — pairs with Grafana, uses object storage
- Cloud-native: Google Cloud Trace, AWS X-Ray, Azure Monitor

---

## Observability Platforms - Commercial & Cloud-Native

While Prometheus + Grafana + Loki is the open-source standard, production environments often use managed platforms for scale, correlation, and reduced operational burden.

### Cloud Provider Solutions

| Platform | Provider | Strengths |
|----------|----------|-----------|
| **Google Cloud Operations** (Cloud Monitoring + Cloud Logging + Cloud Trace) | GCP | Native GKE integration, auto-collected metrics, Monitoring Query Language (MQL), no agent for GKE system metrics |
| **Amazon CloudWatch** + **AWS X-Ray** | AWS | Native EKS integration, Container Insights, Embedded Metrics Format, X-Ray for tracing |
| **Azure Monitor** + **Application Insights** | Azure | Native AKS integration, Container Insights, KQL query language, Application Insights for APM |

### Third-Party Platforms

| Platform | Key Strengths |
|----------|--------------|
| **Datadog** | Unified metrics/logs/traces/APM, extensive K8s integration (Datadog Agent DaemonSet), 800+ integrations, AI-powered root cause analysis |
| **Dynatrace** | Full-stack auto-instrumentation (OneAgent), automatic topology mapping, Davis AI engine for anomaly detection, strong enterprise support |
| **New Relic** | Full-stack observability, generous free tier, K8s cluster explorer, NRQL query language |
| **Splunk** (+ SignalFx) | Industry-leading log analytics, real-time streaming metrics, strong compliance/security use cases |
| **Elastic** (ELK Stack) | Elasticsearch + Kibana for logs, Elastic APM for traces, self-hosted or cloud, powerful full-text search |
| **Grafana Cloud** | Managed Prometheus, Loki, Tempo, and Grafana — the open-source stack without the operational burden |

---

## Choosing an Observability Strategy

```
                    Open Source                  Managed / Commercial
                    ───────────                  ─────────────────────
Metrics:           Prometheus                   Datadog, Dynatrace, Cloud Monitoring
Logs:              Grafana Loki                 Splunk, Elastic, Cloud Logging
Traces:            Jaeger, Tempo                Datadog APM, Dynatrace, Cloud Trace
Dashboards:        Grafana                      Datadog, Dynatrace, Cloud Console
Alerting:          Alertmanager                 PagerDuty integration (all platforms)
```

**Decision Factors:**
- **Cost** — open-source is free to run but costs engineer time to operate; commercial platforms charge per host/GB/event
- **Scale** — Prometheus works well to ~10M time series; beyond that, consider Thanos, Cortex, or a managed platform
- **Correlation** — commercial platforms (Datadog, Dynatrace) correlate metrics + logs + traces in a single pane; open-source requires Grafana with multiple data sources
- **Compliance** — some industries require specific log retention, audit trails, or data residency that managed platforms handle out of the box
- **Team size** — small teams benefit from managed platforms; large platform teams can justify operating the open-source stack

**Best Practice:** Regardless of backend, **instrument with OpenTelemetry**. OTel SDKs and the Collector give you the freedom to switch backends without re-instrumenting your applications.

---

## Google Cloud Operations for GKE (Deep Dive)

Since this course uses GKE, here's how Google Cloud's native observability works:

**Auto-collected (no agent needed):**
- System metrics (CPU, memory, disk, network) for nodes and pods
- Kubernetes metadata (pod status, container restarts, node conditions)
- Control plane logs (API server, scheduler, controller manager)
- Audit logs

**Requires configuration:**
- Application logs — written to stdout/stderr are automatically collected by the GKE logging agent
- Custom metrics — expose a Prometheus `/metrics` endpoint; Google Cloud Managed Service for Prometheus scrapes it
- Custom traces — instrument with OpenTelemetry, export to Cloud Trace

**Google Cloud Managed Service for Prometheus:**
- Drop-in replacement for self-managed Prometheus
- Uses the same PromQL, ServiceMonitors, and recording rules
- Data stored in Google Cloud (Monarch) — scales without managing TSDB
- Query from Grafana (via the Managed Prometheus data source) or Cloud Monitoring

```bash
# Enable managed collection on a GKE cluster
gcloud container clusters update my-cluster \
  --enable-managed-prometheus \
  --region us-central1
```

Your existing `ServiceMonitor` and `PodMonitor` CRDs continue to work — no migration required.

---

## Key Takeaways

- Observability has three pillars — metrics, logs, and traces. Each answers a different question. Effective incident response uses all three together: metrics fire the alert, logs explain what happened, traces show where across services.
- **Prometheus** is the de-facto standard for Kubernetes metrics. It scrapes `/metrics` endpoints on a pull model and stores data in a time-series database queryable with PromQL.
- **ServiceMonitors** (from the Prometheus Operator) are the GitOps-native way to configure scrape targets — no manual Prometheus config edits required.
- **OpenTelemetry** is the standard for application instrumentation — instrument once with OTel SDKs, then export to any backend (Prometheus, Jaeger, Datadog, Dynatrace, Cloud Ops). The OTel Operator can auto-instrument Java, Python, and Node.js apps in Kubernetes with zero code changes.
- **Distributed tracing** is essential for debugging latency in microservice architectures — traces follow a request across service boundaries and reveal which service is the bottleneck.
- Commercial platforms (Datadog, Dynatrace, Splunk, New Relic) and cloud-native solutions (Google Cloud Operations, CloudWatch, Azure Monitor) provide unified observability with less operational overhead — choose based on cost, scale, and team capacity.
- **GKE users** get auto-collected system metrics and logs for free, and can use Google Cloud Managed Prometheus for a fully managed PromQL-compatible metrics backend.
- Regardless of which backend you choose, **instrument with OpenTelemetry** — it's the universal adapter that prevents vendor lock-in.

- Observability has three pillars — metrics, logs, and traces. Each answers a different question. Effective incident response uses all three together: metrics fire the alert, logs explain what happened, traces show where across services.
- **Prometheus** is the de-facto standard for Kubernetes metrics. It scrapes `/metrics` endpoints on a pull model and stores data in a time-series database queryable with PromQL.
- **ServiceMonitors** (from the Prometheus Operator) are the GitOps-native way to configure scrape targets — no manual Prometheus config edits required.
- Learn PromQL basics — `rate()`, `sum by()`, `histogram_quantile()`, and ratio queries cover the vast majority of real-world alerting and dashboarding needs.
- **Grafana Loki** keeps log costs low by indexing only labels, not log content — the trade-off is that full-text search is slower than Elasticsearch but sufficient for label-driven workflows.
- The **kube-prometheus-stack** Helm chart is the fastest path to a production-grade observability stack (Prometheus + Alertmanager + Grafana + pre-built K8s dashboards) on any cluster.
- **OpenTelemetry** is the emerging standard for instrumentation — instrument your application once with the OTel SDK and route signals to whatever backend you choose.
