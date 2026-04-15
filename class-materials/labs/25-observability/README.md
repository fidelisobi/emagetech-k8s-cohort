# Lab 25 — Observability in Practice

## Overview

In this lab you will use the full observability stack already deployed on the
`cluster-dreams` GKE cluster: **Prometheus** for metrics collection, **Grafana** for
dashboards and alerts, **Alertmanager** for alert routing, and **Loki** for log aggregation.

You will:

1. Access the Grafana UI via port-forward
2. Import a pre-built Kubernetes dashboard
3. Deploy the student-app ServiceMonitor and verify Prometheus discovers it
4. Run PromQL queries to explore cluster and application metrics
5. Deploy a PrometheusRule, trigger it, and watch the alert fire
6. Deploy a structured log generator and query logs with LogQL

**Time estimate:** 75–90 minutes

---

## Prerequisites

- kubectl configured for `cluster-dreams` in `us-central1`
- kube-prometheus-stack deployed in the `monitoring` namespace
- Loki deployed in the `monitoring` namespace (or `loki` namespace — verify below)

### Verify the stack is healthy

```bash
# Check Prometheus
kubectl get pods -n monitoring -l app=kube-prometheus-stack-prometheus
# Expected: STATUS = Running

# Check Grafana
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
# Expected: STATUS = Running

# Check Alertmanager
kubectl get pods -n monitoring -l app=kube-prometheus-stack-alertmanager
# Expected: STATUS = Running

# Check Loki
kubectl get pods -n monitoring -l app=loki
# If not in monitoring, try:
kubectl get pods -A -l app=loki | head -5
```

---

## Part A — Access Grafana

### Step A1 — Port-forward Grafana to your local machine

```bash
kubectl port-forward svc/prometheus-monitoring-grafana -n monitoring 3000:80
```

Keep this terminal open. Grafana is now available at: http://localhost:3000

> If the service name differs on your cluster, find it with:
> `kubectl get svc -n monitoring | grep grafana`

### Step A2 — Log in to Grafana

Default credentials for kube-prometheus-stack:
- **Username:** `admin`
- **Password:** retrieve with:

```bash
kubectl get secret prometheus-monitoring-grafana -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 --decode; echo
```

### Step A3 — Explore the pre-built dashboards

Grafana ships with several dashboards pre-configured by kube-prometheus-stack:

1. In the left sidebar click **Dashboards** (four-squares icon)
2. Browse **Kubernetes / Compute Resources / Cluster** — shows CPU and memory for every namespace
3. Browse **Kubernetes / Networking / Cluster** — shows network I/O
4. Notice the **Data Source** dropdown at the top — it is set to `Prometheus`

---

## Part B — Import a Community Dashboard

The Grafana community publishes thousands of dashboards at https://grafana.com/grafana/dashboards.
You can import them by ID.

### Step B1 — Import Kubernetes Cluster Monitoring (ID 6417)

1. In Grafana, click **+** (plus icon in left sidebar) → **Import**
2. In the "Import via grafana.com" field, enter: `6417`
3. Click **Load**
4. In the dropdown, select **Prometheus** as the data source
5. Click **Import**

The dashboard shows nodes, pods, CPU requests vs limits, memory usage, and network I/O.

### Step B2 — Try dashboard ID 315 (Kubernetes Cluster Overview)

Repeat the import steps with ID `315`. This one shows resource quotas, persistent volumes,
and a cluster-wide health summary.

> **Discussion:** What is the difference between CPU *requests* and CPU *usage*?
> Which one is used for scheduling decisions? Which for billing?

---

## Part C — ServiceMonitor and Prometheus Target Discovery

### Step C1 — Create the lab namespace and deploy the student-app

```bash
kubectl apply -f 01-servicemonitor.yaml
```

This applies:
- Namespace `observability-lab`
- The `student-app` Deployment (2 replicas)
- The `student-app` Service (port 5000)
- The `student-app-monitor` ServiceMonitor

### Step C2 — Verify the ServiceMonitor was created

```bash
kubectl get servicemonitor -n observability-lab
# Expected: NAME                  AGE
#           student-app-monitor   30s
```

### Step C3 — Verify the target appears in Prometheus

Open a second terminal and port-forward Prometheus:

```bash
kubectl port-forward svc/prometheus-monitoring-kube-prometheus -n monitoring 9090:9090
```

Now go to: http://localhost:9090/targets

1. Look for a section called `serviceMonitor/observability-lab/student-app-monitor`
2. It should show 2 targets (one per pod replica) with state **UP**

> If targets show state **DOWN** or are missing:
> - Verify the Service labels match the ServiceMonitor selector
> - Verify the ServiceMonitor has `release: prometheus-monitoring` label
> - Check Prometheus logs: `kubectl logs -n monitoring -l app=kube-prometheus-stack-prometheus`

### Step C4 — Browse scraped metrics

In the Prometheus UI (http://localhost:9090):

1. Click **Graph**
2. In the query box, type: `up{namespace="observability-lab"}`
3. Click **Execute**
4. You should see a value of `1` for each scrape target (1 = up, 0 = down)

---

## Part D — PromQL Queries

Run these queries in Prometheus (http://localhost:9090/graph) or in Grafana
(Explore → Prometheus data source).

### Cluster-wide queries

```promql
# Total CPU cores requested by all pods in the cluster
sum(kube_pod_container_resource_requests{resource="cpu", unit="core"})

# CPU usage (cores) per namespace
sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (namespace)

# Memory usage (bytes) per namespace
sum(container_memory_working_set_bytes{container!=""}) by (namespace)

# Node CPU utilization %
(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance)) * 100
```

### Pod and container queries

```promql
# Number of running pods per namespace
sum(kube_pod_status_phase{phase="Running"}) by (namespace)

# Pods that have been restarting (more than 3 restarts)
kube_pod_container_status_restarts_total > 3

# Deployments with fewer replicas than desired
kube_deployment_status_replicas_available < kube_deployment_spec_replicas
```

### student-app queries (after app exposes real metrics)

```promql
# Request rate per second (5-minute window)
rate(http_requests_total{namespace="observability-lab"}[5m])

# Error rate (%) — 5xx responses as a percentage of total
rate(http_requests_total{namespace="observability-lab", status=~"5.."}[5m])
/ rate(http_requests_total{namespace="observability-lab"}[5m]) * 100

# P99 latency (seconds)
histogram_quantile(0.99,
  sum(rate(http_request_duration_seconds_bucket{namespace="observability-lab"}[5m]))
  by (le)
)
```

> **Tip:** In Prometheus, switch from **Table** to **Graph** view to see the metric
> over time. Set the time range to "Last 15 minutes" to see recent data.

---

## Part E — Alerting Rules

### Step E1 — Apply the PrometheusRule

```bash
kubectl apply -f 02-prometheusrule.yaml
```

### Step E2 — Verify rules are loaded in Prometheus

```bash
# Check the PrometheusRule resource was created
kubectl get prometheusrule -n observability-lab
```

In the Prometheus UI: http://localhost:9090/rules

1. Find the group `student-app.rules`
2. Verify all three alerts are listed: `HighHTTPErrorRate`, `HighP99Latency`, `StudentAppDown`
3. State should be `inactive` (condition not met yet)

### Step E3 — Trigger the StudentAppDown alert

```bash
# Scale the deployment to 0 replicas — no pods running
kubectl scale deployment student-app -n observability-lab --replicas=0
```

Watch the alert transition:

```bash
# Poll the alert status every 10 seconds
watch -n 10 kubectl get pods -n observability-lab
```

In Prometheus (http://localhost:9090/alerts):
1. After ~30s: alert transitions from `inactive` → `pending`
2. After 1 more minute: alert transitions `pending` → `firing`

The `for: 1m` in the rule means the condition must hold for 1 minute before firing.

### Step E4 — Restore the deployment

```bash
kubectl scale deployment student-app -n observability-lab --replicas=2
```

Watch the alert transition back to `inactive` as pods recover.

### Step E5 — View alerts in Grafana (Alerting section)

1. In Grafana, click **Alerting** (bell icon in left sidebar)
2. Click **Alert rules**
3. Find the rules imported from Prometheus (they appear under the Prometheus data source)

---

## Part F — Loki and LogQL

### Step F1 — Deploy the log generators

```bash
kubectl apply -f 03-loki-test.yaml
```

Verify both pods are running:

```bash
kubectl get pods -n observability-lab
# Expected:
# NAME                    READY   STATUS    RESTARTS
# log-generator           1/1     Running   0
# error-burst-generator   1/1     Running   0
# student-app-xxx         1/1     Running   0  (x2)
```

### Step F2 — Confirm logs are being emitted

```bash
kubectl logs -f log-generator -n observability-lab
# Expected: one JSON line per second
# {"timestamp":"2026-...","level":"info","message":"request completed","request_id":"req-00001",...}
```

```bash
kubectl logs -f error-burst-generator -n observability-lab
# Expected: mostly info during healthy phase, burst of errors every 90s
```

### Step F3 — Access Grafana Explore for LogQL

In Grafana:
1. Click **Explore** (compass icon) in the left sidebar
2. At the top, switch the data source from **Prometheus** to **Loki**
3. You are now in the LogQL query editor

### Step F4 — LogQL queries to run

Start with label selectors — these filter which log streams to query:

```logql
# All logs from the observability-lab namespace
{namespace="observability-lab"}

# Logs from the log-generator pod specifically
{namespace="observability-lab", app="log-generator"}

# Logs from either generator
{namespace="observability-lab"} |= "log-generator"
```

Now add filters using the JSON parser:

```logql
# Only ERROR level logs (JSON field extraction)
{namespace="observability-lab"} | json | level="error"

# Only WARN and ERROR
{namespace="observability-lab"} | json | level=~"warn|error"

# Requests to a specific path
{app="log-generator"} | json | path="/api/orders"

# Slow requests (latency > 300ms) — note: numbers are strings after JSON parse
# Use line_format or pattern for numeric comparisons
{app="log-generator"} | json | latency_ms > 300
```

Aggregation queries (switch to **Metrics** mode in Explore):

```logql
# Error log rate per minute
sum(rate({namespace="observability-lab"} | json | level="error" [1m]))

# Log volume by level (for a log volume panel in a dashboard)
sum by (level) (
  rate({namespace="observability-lab"} | json [1m])
)
```

### Step F5 — Observe the error-burst-generator cycle

The `error-burst-generator` pod alternates between healthy and degraded phases every 90 seconds.

In Grafana Explore with LogQL:

```logql
{app="error-burst"} | json | level="error"
```

Switch the time range to "Last 5 minutes" and click the **Live** button (top right) to watch
logs stream in real time. You should see quiet periods followed by bursts of error messages.

---

## Part G — Build a Simple Dashboard

### Step G1 — Create a new dashboard

1. In Grafana: **+** → **New Dashboard** → **Add visualization**
2. Select **Prometheus** as the data source
3. Enter query: `sum(rate(container_cpu_usage_seconds_total{namespace="observability-lab"}[5m]))`
4. Change the panel title to "student-app CPU Usage"
5. Click **Apply**

### Step G2 — Add a Loki log panel

1. Click **Add panel** → **Add visualization**
2. Select **Loki** as the data source
3. Enter query: `{namespace="observability-lab"} | json | level="error"`
4. Change visualization type from "Time series" to **Logs**
5. Title it "Error Logs"
6. Click **Apply**

### Step G3 — Save the dashboard

1. Click the **Save** icon (floppy disk) at top right
2. Name it: `student-app-observability-lab`
3. Click **Save**

---

## Cleanup

```bash
kubectl delete namespace observability-lab
```

---

## Discussion Questions

1. What is the difference between a ServiceMonitor and pod annotations for Prometheus scraping?
   When would you use each?
2. What is the `for` duration in an alerting rule? Why is it important?
   What happens if you set it to `0s`?
3. What is the difference between `rate()` and `irate()` in PromQL?
4. In Loki, what is the difference between a label filter (`| app="foo"`) and a
   line filter (`|= "foo"`)? Which is faster?
5. What are recording rules? Why should you use them for production dashboards?

---

## Key Concepts

| Concept | Description |
|---|---|
| ServiceMonitor | CRD that instructs Prometheus Operator to add a scrape job |
| PrometheusRule | CRD that defines alerting and recording rules |
| `rate()` | Per-second average rate of a counter over a time window |
| `histogram_quantile()` | Computes a percentile from a histogram metric |
| PENDING → FIRING | Alert must satisfy `for` duration before Alertmanager is notified |
| LogQL stream selector | `{label="value"}` — filters which log streams to include |
| LogQL JSON parser | `\| json` — extracts JSON fields as queryable labels |
| Recording rule | Pre-computed metric — speeds up dashboards and alert evaluation |
