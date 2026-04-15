# Session 23 — Scaling: Pods & Nodes

---

## Autoscaling Dimensions

| Dimension | What Scales | Controller |
|-----------|------------|------------|
| **Vertical Pod Scaling** | CPU/Memory of containers | VPA (VerticalPodAutoscaler) |
| **Horizontal Pod Scaling** | Number of pod replicas | HPA (HorizontalPodAutoscaler) |
| **Horizontal Node Scaling** | Number of cluster nodes | Cluster Autoscaler or Karpenter |

---

## Vertical Pod Autoscaler (VPA)

- Created by a CustomResourceDefinition (CRD)
- Vertically adjusts the amount of compute resources

**Components:**
- **Recommender** — monitors current and past resource consumption, provides recommended CPU/memory request values
- **Updater** — checks for pods with incorrect resources, deletes them so new pods are created with updated values
- **Admission Plugin** — sets correct resource requests/limits on new pods

**Update Modes:**
| Mode | Behavior |
|------|----------|
| **Off** | Recommendations only, no pod recreation |
| **Initial** | Sets resources on pod creation, never changes again |
| **Recreate** | Evicts and recreates pods based on recommendations |
| **Auto** | Recreates pods based on recommendations |

> **Note:** VPA `Auto` mode currently requires pod eviction to apply new resource values. In the future, it may support in-place updates via the `InPlacePodVerticalScaling` feature gate — no pod restart required.

---

## Horizontal Pod Autoscaler (HPA)

- **Not** a CustomResourceDefinition — standard Kubernetes API primitive
- Monitors configured metrics via metrics-server
- Calculates average of current metrics from all pods
- Determines whether to add or remove replicas based on target value
- **Target value is a percentage of `resource.requests`** (important!)

**Analogy:** Like a restaurant adding waitstaff based on the ratio of customers to waiters — if the target is 10 customers per waiter and 30 arrive, you hire 3 waiters. If only 5 show up, you send some home.

**Limitations:**
- Does not work with DaemonSets
- If cluster is out of capacity, cannot scale up until new nodes are added
- If requests/limits are not efficiently set — pods could terminate frequently or resources get wasted

**Imperative (quick test):**
```bash
kubectl autoscale deployment <name> --min=2 --max=10 --cpu-percent=70
```

**Declarative HPA YAML (preferred for GitOps):**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

---

## HPA + Cluster Autoscaler Interplay

HPA and Cluster Autoscaler work together — HPA scales pods, CA scales nodes:

```
More traffic arrives
     │
     ▼
HPA: CPU > 70% target → scale pods 3 → 6
     │
     ▼
Pods 4,5,6: Pending (no room on existing nodes)
     │
     ▼
Cluster Autoscaler / Karpenter: provision new node
     │
     ▼
Pods 4,5,6 scheduled on new node
```

Without node scaling, HPA hits a ceiling and pods stay Pending. Without pod scaling, you waste new nodes running the same number of replicas.

---

## Cluster Autoscaler (CA)

- Used to scale the cluster itself
- Frequently checks the status of Pods and Nodes
  - Pods stuck in "Pending" due to insufficient resources → **add nodes**
  - Nodes underutilized → **remove nodes**, pods evicted and rescheduled
- Some cloud providers have CA pre-installed
- Complements HPA

**Other implementations:** Karpenter

---

## Karpenter

- Just-in-time node provisioning — faster than Cluster Autoscaler
- Provisions right-sized nodes based on pending pod requirements
- No pre-defined node groups/pools required
- Supports: EKS (GA), AKS (preview)
- GKE uses native GKE Autopilot instead

**GKE Autopilot vs Standard:**
- **Autopilot** — Google manages nodes, per-pod billing, automatic scaling
- **Standard** — you manage node pools, Cluster Autoscaler for scaling

---

## Advanced Scheduling

The following methods influence where Pods are scheduled:

### Node Selector
- Simplest recommended form of node selection constraint
- Matches pod to nodes with specific labels

### Node Affinity
- More expressive than nodeSelector
- `requiredDuringSchedulingIgnoredDuringExecution` — hard requirement
- `preferredDuringSchedulingIgnoredDuringExecution` — soft preference (with weight 1-100)

### Inter-Pod Affinity / Anti-Affinity
- Constrain which nodes pods are scheduled on based on **labels of pods already running** on that node
- Same `required` and `preferred` types as node affinity
- Anti-affinity: spread replicas across nodes/zones

---

## Topology Spread Constraints

Defines how to spread pods across failure domains (regions, zones, nodes).

**Key Fields:**
- `maxSkew` — degree to which pods may be unevenly distributed
- `whenUnsatisfiable` — `DoNotSchedule` or `ScheduleAnyway`
- `topologyKey` — nodes with matching label key/value are in the same topology
- `labelSelector` — which pods to consider when calculating spread

**Example — spread across zones, tolerate at most 1 skew:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 6
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: my-app
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: my-app
      containers:
        - name: my-app
          image: my-app:latest
```

This ensures pods are spread evenly across availability zones (hard) and across nodes within a zone (soft).

---

## Taints and Tolerations

**Taints** allow nodes to repel a set of pods. Format: key/value pair + effect.

**Effects:**
| Effect | Behavior |
|--------|----------|
| `NoSchedule` (hard) | New pods won't be scheduled |
| `PreferNoSchedule` (soft) | Scheduler tries to avoid but not guaranteed |
| `NoExecute` | Existing pods are evicted if they don't tolerate |

**Tolerations** allow the scheduler to schedule pods matching taints.

**Use Cases:**
- Dedicated nodes (GPU, high-memory)
- Nodes with special hardware
- Taint-based evictions (NoExecute effect)

---

## Pod Priority and Preemption

- **PriorityClass** — defines priority value for pods
- Higher priority pods can **preempt** (evict) lower priority pods when resources are scarce
- `preemptionPolicy: PreemptLowerPriority` (default) or `Never`
- System-critical pods use built-in priority classes:
  - `system-cluster-critical`
  - `system-node-critical`

---

## Key Takeaways

- **HPA** scales pod count based on metrics; **VPA** tunes individual pod resource requests — they solve different problems and can complement each other (though using both on CPU simultaneously requires care).
- **HPA + Cluster Autoscaler / Karpenter** are the standard production combination: HPA reacts first, then CA/Karpenter provisions nodes for pending pods.
- Always set **resource requests** on your containers — HPA and CA both depend on them to make accurate decisions.
- **Topology Spread Constraints** are the modern, flexible replacement for pod anti-affinity rules when spreading across zones or nodes.
- **Taints/tolerations** and **node affinity** give you fine-grained control for dedicated workloads (GPUs, spot nodes, compliance-isolated nodes).
- In GKE, **Autopilot** removes node management entirely; in Standard mode you manage node pools and wire in Cluster Autoscaler yourself.
