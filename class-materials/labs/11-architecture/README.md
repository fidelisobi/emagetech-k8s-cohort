# Lab 11: Explore Your Cluster

## Overview

In this lab you will connect to a live GKE cluster and explore its architecture from the
outside in — starting at the control plane, working down to nodes, and finally into the
system namespaces that keep the cluster running. You will not deploy any workloads; the
goal is to build intuition about what is already there.

**Estimated time:** 30 minutes

**Prerequisites:**
- `gcloud` CLI installed and authenticated
- `kubectl` installed (v1.28 or later recommended)
- Access to the shared GKE cluster provided by your instructor

---

## Part 1: Connect to the GKE Cluster

### 1.1 Authenticate and fetch credentials

Your instructor will provide the project ID, cluster name, and zone/region. Substitute them
below.

```bash
# Authenticate to GCP (skip if you are already authenticated)
gcloud auth login

# Set the active project
gcloud config set project <PROJECT_ID>

# Download cluster credentials into your local kubeconfig (~/.kube/config)
# --region is used for regional clusters; use --zone for zonal clusters
gcloud container clusters get-credentials <CLUSTER_NAME> \
  --region <REGION> \
  --project <PROJECT_ID>
```

### 1.2 Verify the connection

```bash
# Show the API server URL and the in-cluster DNS service
kubectl cluster-info
```

Expected output (addresses will differ):
```
Kubernetes control plane is running at https://34.x.x.x
CoreDNS is running at https://34.x.x.x/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

```bash
# Confirm your identity — shows which user/service-account kubectl is acting as
kubectl auth whoami
```

---

## Part 2: Explore the Control Plane

### 2.1 Inspect nodes

```bash
# List all nodes with extra columns (internal/external IPs, OS image, kernel, container runtime)
kubectl get nodes -o wide
```

Take note of:
- The **ROLES** column — on GKE the control-plane nodes are hidden (Google manages them);
  you will only see worker nodes labelled `<none>`.
- The **VERSION** column — kubelet version on each node.
- The **CONTAINER-RUNTIME** column — GKE uses `containerd`.

```bash
# Show a detailed view of the first node (replace <NODE_NAME> with a name from the list above)
kubectl describe node <NODE_NAME>
```

Sections to focus on in the `describe` output:

| Section | What to look for |
|---|---|
| **Labels** | GKE-managed labels: `topology.kubernetes.io/zone`, `node.kubernetes.io/instance-type` |
| **Taints** | Any NoSchedule taints that prevent pods landing here |
| **Capacity** | Total CPU, memory, pods the node hardware provides |
| **Allocatable** | Capacity minus what the OS and system daemons reserve |
| **Conditions** | `Ready`, `MemoryPressure`, `DiskPressure`, `PIDPressure` — all should be `False` except `Ready=True` |
| **Non-terminated Pods** | Every pod currently running on this specific node |

> **Question:** What is the difference between `Capacity` and `Allocatable`? Why does it matter
> when you set resource requests on your pods?

### 2.2 Component statuses (deprecated but educational)

```bash
# This command is deprecated in newer Kubernetes versions but still informative.
# It queries /componentstatuses on the API server.
kubectl get componentstatuses
```

On GKE the response is typically short because Google manages etcd and the scheduler
internally. You may see `Healthy` or a "connection refused" message — both are normal.
The purpose of this command is to understand that the control plane has distinct
components (scheduler, controller-manager, etcd) even when you cannot see them directly.

### 2.3 Check API server health endpoints

The API server exposes two well-known health endpoints you can query directly:

```bash
# /healthz — liveness check; returns "ok" when the API server is running
kubectl get --raw /healthz

# /readyz — readiness check; returns "ok" when the API server can serve requests
kubectl get --raw /readyz

# /livez — a more granular liveness check (Kubernetes 1.19+)
kubectl get --raw /livez

# Verbose breakdown showing each individual check
kubectl get --raw /readyz?verbose
```

---

## Part 3: Explore System Pods in kube-system

### 3.1 List all system pods

```bash
# The kube-system namespace holds components that run Kubernetes itself
kubectl get pods -n kube-system
```

### 3.2 Identify key components

Look for pods whose names start with the following prefixes and note how many replicas
are running and which nodes they are on:

```bash
# Show pods with node placement (-o wide) so you can see scheduling
kubectl get pods -n kube-system -o wide
```

| Component | Name pattern | Purpose |
|---|---|---|
| **CoreDNS** | `coredns-*` | Cluster-internal DNS resolution |
| **kube-proxy** | `kube-proxy-*` | Programs iptables/ipvs rules for Service ClusterIPs |
| **metrics-server** | `metrics-server-*` | Aggregates CPU/memory metrics for HPA and `kubectl top` |
| **fluentbit / fluentd** | `fluentbit-*` or `fluentd-*` | GKE log forwarding to Cloud Logging |
| **pdcsi-node** | `pdcsi-node-*` | GCP Persistent Disk CSI driver (DaemonSet — one per node) |

```bash
# Inspect the CoreDNS pod in detail (replace <POD_NAME> with an actual coredns pod name)
kubectl describe pod <coredns-POD_NAME> -n kube-system
```

Notice the `Controlled By` line — it will show `ReplicaSet/...`, confirming CoreDNS is
managed by a Deployment.

### 3.3 View CoreDNS configuration

```bash
# CoreDNS reads its configuration from a ConfigMap
kubectl get configmap coredns -n kube-system -o yaml
```

The `Corefile` key inside the ConfigMap defines forwarding rules, cache TTLs, and the
`cluster.local` domain that all in-cluster DNS queries use.

---

## Part 4: Explore Namespaces

### 4.1 List all namespaces

```bash
kubectl get namespaces
```

The four default namespaces in every Kubernetes cluster:

| Namespace | Purpose |
|---|---|
| `default` | Where resources land if you do not specify a namespace |
| `kube-system` | Kubernetes control plane and infrastructure components |
| `kube-public` | Readable by all users (including unauthenticated); holds the `cluster-info` ConfigMap |
| `kube-node-lease` | Holds Lease objects — one per node — used for efficient node heartbeats |

```bash
# Inspect the publicly readable cluster-info ConfigMap
kubectl get configmap cluster-info -n kube-public -o yaml

# Inspect a node lease (replace <NODE_NAME>)
kubectl get lease <NODE_NAME> -n kube-node-lease -o yaml
```

> **Question:** The `kube-node-lease` namespace exists to reduce load on the API server.
> How does a Lease object differ from the node heartbeat mechanism that existed before
> Kubernetes 1.14?

---

## Part 5: Explore the API

### 5.1 List all API resources

```bash
# Show every resource type the API server knows about, with API group and version
kubectl api-resources

# Filter to only core (no API group) resources
kubectl api-resources --api-group=""

# Show only namespaced resources
kubectl api-resources --namespaced=true
```

### 5.2 Check API versions

```bash
# List all API groups and their available versions
kubectl api-versions | sort
```

### 5.3 Explore a resource definition inline

```bash
# kubectl explain walks the OpenAPI schema — no internet needed
kubectl explain node
kubectl explain node.spec
kubectl explain node.status.conditions
```

---

## Clean Up

No resources were created in this lab — nothing to delete.

---

## Summary

After completing this lab you should be able to:

- Connect to a GKE cluster using `gcloud container clusters get-credentials`
- Read node capacity vs allocatable and explain the difference
- Identify the core system components running in `kube-system`
- Name the four default namespaces and explain what each is used for
- Query the API server health endpoints with `kubectl get --raw`
- Use `kubectl api-resources` and `kubectl explain` to discover resource types
