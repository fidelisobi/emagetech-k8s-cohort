# Lab 23 — Scaling: HPA and Topology Spread

## Overview

In this lab you will:

1. Deploy a workload with a **HorizontalPodAutoscaler** configured for CPU-based scaling
2. Run a load generator to trigger the HPA to scale up
3. Observe the stabilization window delaying scale-down
4. Deploy a workload with **topology spread constraints** for zone-level high availability

**Time estimate:** 45–60 minutes

---

## Prerequisites

- GKE cluster with Metrics Server enabled (default on GKE)
- kubectl configured for the cluster
- At least 3 nodes across 3 zones (for topology spread lab)

### Verify Metrics Server

```bash
kubectl get deployment metrics-server -n kube-system
# Expected: AVAILABLE = 1
```

### Check node zones

```bash
kubectl get nodes --label-columns topology.kubernetes.io/zone
```

---

## Part A — HorizontalPodAutoscaler

### Step A1 — Deploy the target app and HPA

```bash
kubectl apply -f 01-hpa.yaml
```

Verify everything is running:

```bash
kubectl get all -n scaling-lab
```

Check the initial HPA state:

```bash
kubectl get hpa php-apache-hpa -n scaling-lab
```

Expected output:

```
NAME             REFERENCE              TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
php-apache-hpa   Deployment/php-apache  0%/70%    2         10        2          30s
```

> If TARGETS shows `<unknown>`, wait 30–60 seconds for Metrics Server to collect data.

---

### Step A2 — Start the Load Generator (Terminal 1)

```bash
chmod +x 02-load-test.sh
./02-load-test.sh
```

The script will:
- Create a `load-generator` pod running a `wget` loop
- Start watching the HPA and pod count automatically

---

### Step A3 — Watch the HPA Scale Up (Terminal 2)

Open a second terminal and watch in real time:

```bash
# Watch HPA metrics and replica count
kubectl get hpa php-apache-hpa -n scaling-lab -w

# In a third terminal — watch pods being created
kubectl get pods -n scaling-lab -w
```

Expected progression:

```
NAME             TARGETS    MINPODS   MAXPODS   REPLICAS
php-apache-hpa   0%/70%     2         10        2
php-apache-hpa   148%/70%   2         10        2       ← load detected
php-apache-hpa   148%/70%   2         10        4       ← scaling up
php-apache-hpa   95%/70%    2         10        6       ← still scaling
php-apache-hpa   62%/70%    2         10        6       ← stabilized
```

> Scale-up takes 1–2 minutes from when load starts. The HPA control loop runs every 15 seconds.

---

### Step A4 — Stop the Load and Watch Scale Down

```bash
./02-load-test.sh --stop
```

The HPA will NOT scale down immediately. It waits for the `stabilizationWindowSeconds: 300` (5 minutes) of sustained low load before reducing replicas.

```bash
kubectl get hpa php-apache-hpa -n scaling-lab -w
# Watch REPLICAS column decrease back to 2 after ~5 minutes
```

This delay is intentional — it prevents flapping when load is intermittent.

---

### HPA Internals — How the Math Works

Given:
- Current replicas: 4
- Current average CPU: 210% of request
- Target CPU: 70%

```
desiredReplicas = ceil(4 * (210 / 70)) = ceil(12) = 12
# But maxReplicas=10, so it caps at 10
```

---

## Part B — Topology Spread Constraints

### Step B1 — Deploy the zone-spread app

```bash
kubectl apply -f 03-topology-spread.yaml
```

### Step B2 — Verify zone distribution

```bash
# Check which zone each pod landed in
for pod in $(kubectl get pod -n scaling-lab -l app=zone-spread -o name); do
  node=$(kubectl get $pod -n scaling-lab -o jsonpath='{.spec.nodeName}')
  zone=$(kubectl get node $node \
    -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
  echo "$pod  -->  node: $node  -->  zone: $zone"
done
```

Expected: pods distributed evenly — 2 pods per zone (with 6 replicas across 3 zones).

### Step B3 — Simulate a zone failure

```bash
# Cordon all nodes in one zone (simulates zone outage)
ZONE="us-central1-a"   # change to match your cluster
kubectl get nodes -l topology.kubernetes.io/zone=$ZONE \
  -o name | xargs kubectl cordon

# Now scale up — new pods should NOT land in the cordoned zone
kubectl scale deployment zone-spread-app -n scaling-lab --replicas=9
kubectl get pods -n scaling-lab -l app=zone-spread -o wide
```

### Step B4 — Uncordon nodes

```bash
kubectl get nodes -l topology.kubernetes.io/zone=$ZONE \
  -o name | xargs kubectl uncordon
```

---

## Discussion Questions

1. What is the difference between `DoNotSchedule` and `ScheduleAnyway`?
2. Can you use topology spread constraints with stateful workloads (StatefulSet)?
3. What happens to HPA behavior if Metrics Server goes down?
4. How does `maxSkew` interact with `minReplicas` on the HPA?

---

## Cleanup

```bash
./02-load-test.sh --stop   # if load generator is still running
kubectl delete namespace scaling-lab
```

---

## Key Concepts

| Concept | Description |
|---|---|
| `minReplicas` / `maxReplicas` | Hard bounds on pod count |
| `averageUtilization: 70` | Target 70% of requested CPU across all pods |
| `stabilizationWindowSeconds` | Delay before acting on metric changes (prevents flapping) |
| `topologyKey` | Node label defining the failure domain (zone, node, rack) |
| `maxSkew` | Maximum allowed pod-count imbalance between topology domains |
| `DoNotSchedule` | Strict enforcement — pod stays Pending if constraint unmet |
| `ScheduleAnyway` | Best-effort — pod is placed but imbalance is logged |
