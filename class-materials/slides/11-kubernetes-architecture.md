# Session 11 — Kubernetes Architecture

---

## Kubernetes

Kubernetes is an open source container orchestration engine for automating deployment, scaling, and management of containerized applications. The open source project is hosted by the Cloud Native Computing Foundation (CNCF).

---

## Big Picture - What is Kubernetes?

- Container Orchestrator
- Workload Placement
- Infrastructure Abstraction
- Desired State

**Definition:**
Kubernetes is a portable, extensible, open source platform for managing containerized workloads and services, that facilitates both declarative configuration and automation. It has a large, rapidly growing ecosystem. Kubernetes services, support, and tools are widely available.

---

## Big Picture - Benefits of using Kubernetes

- Speed of deployment
- Ability to recover quickly - controllers
- Ability to absorb change quickly
- Hide complexity in the cluster

**Principles:**
- Desired State & Declarative Configuration
- Controllers/Control Loop
- Kubernetes API or API Server

---

## Big Picture - Kubernetes API Server

- Collection of primitives to represent your system state
- Enabled configuration of state
  - Declaratively or Imperatively
- RESTful API of HTTP over JSON
- Sole way Kubernetes interacts with the cluster
- Serialized and Persisted
- API Objects (Key Components)
  - Pods, Controllers, Services, Storage etc

---

## Big Picture - Pods

- Contain one or more containers
- Represents an application or service
- Most basic unit of work
- Ephemeral
- K8s keeps pods up and running
  - State - Running
  - Health - is the app up and running?
    - Probes

---

## Big Picture - Pods (Desired State)

How does Kubernetes manage a pod's desired state?
- **Controllers**
  - Defines desired state
  - Creates and manages Pods
  - Responds to Pod State and Health
    - ReplicaSet - number of replicas
    - Deployment - manages rollout of ReplicaSet(s)
  - There are many more controllers and API objects

**Reconciliation Loop — how controllers maintain desired state:**

```
        ┌──────────┐
        │ Observe  │ ◄── What is the current state?
        └────┬─────┘
             ▼
        ┌──────────┐
        │   Diff   │ ◄── Does it match desired state?
        └────┬─────┘
             ▼
        ┌──────────┐
        │   Act    │ ◄── Take action to fix any drift
        └────┬─────┘
             │
             └──────────► (repeat forever)
```

---

## Big Picture - Pod Persistency

**Services:**
- Adds persistency to an ephemeral world
- Networking abstraction for Pod access
- IP and DNS name for the service
- Dynamic updates based on Pod lifecycle
- Scaled by adding and removing Pods
- Load Balancing

**Storage:**
- Volumes
- Persistent Volumes
- Persistent Volume Claims
- Secrets
- ConfigMaps

---

## Big Picture - What is a Cluster?

A group of one or more computers, or nodes, that can run in parallel to achieve the same goal. A group of interconnected computers or nodes that work together to support applications and middleware.

**Advantages:**
- High availability (Availability, Resilience, Reliability, Redundancy)
- Load Balancing
- Scaling
- Performance

**Challenges:**
- Complex Installation
- Complex Maintenance

---

## K8s Architecture - Control Plane (Master) Nodes

> Think of the control plane as an airport control tower — it doesn't fly any planes, it watches everything, gives instructions, and responds to problems. Worker nodes are the planes and their crews.

- **API Server**
  - Central and core to the cluster
  - Stateless — the API server holds no in-memory application state; all persistent state lives in etcd
  - Exposes RESTful APIs
  - Updates etcd
- **etcd**
  - Persists state of API objects as key-value pairs
  - Stores cluster state
  - Highly available distributed key-value store
  - Must always have odd number of etcd members → 2n + 1
  - Elects a leader; other members are followers
  - Has a "watch operation" — how controllers inspect keys/values
  - > etcd is the building's master blueprint vault — every decision refers back to it. If it's lost, no one knows what the system is supposed to look like.
- **Scheduler**
  - Watches the API Server
  - Schedules Pods
  - Evaluates resources on the worker nodes
  - Respects constraints
  - Uses filtering and scoring (predicate and priority algorithms)
  - > The Scheduler is a hotel concierge assigning guests to rooms — it knows which rooms are occupied, which have special features, and which guests have requirements.
- **Controller Manager**
  - Executes controller loops
  - Lifecycle functions & desired state
  - Watches and updates the API Server
  - Examples: Node, Deployment, Replication, Endpoint, DaemonSet, ReplicaSet, Service, Namespace, Persistent Volume Controllers
- **Cloud Controller Manager**
  - Executes cloud-specific logic
  - Nodes Controller — creating and deleting virtual machines
  - Routes Controller — creating and deleting routes between nodes
  - Service Controller — creating and deleting external Load Balancers

**Full Cluster Architecture:**

```
┌─────────────────────────────────────────────────────────────┐
│                      Control Plane                          │
│  ┌───────────┐  ┌───────┐  ┌───────────┐  ┌─────────────┐  │
│  │ API Server│◄─►│ etcd │  │ Scheduler │  │ Ctrl Manager│  │
│  └─────┬─────┘  └───────┘  └───────────┘  └─────────────┘  │
└────────┼────────────────────────────────────────────────────┘
         │ HTTPS
┌────────▼────────────────────────────────────────────────────┐
│  Worker Node 1                                              │
│  ┌─────────┐  ┌───────────┐  ┌──────────────────┐          │
│  │ kubelet │  │kube-proxy │  │Container Runtime │          │
│  └─────────┘  └───────────┘  └──────────────────┘          │
│  ┌───────────────────────────────────────────────┐          │
│  │  Pod          ┌───────┐  ┌───────┐            │          │
│  │               │Cont-A │  │Cont-B │            │          │
│  │               └───────┘  └───────┘            │          │
│  └───────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

---

## K8s Architecture - Worker Nodes

- **Kubelet**
  - Primary "node agent" running on each node
  - Registers nodes with the API server
  - Communicates with control plane and manages pods on the node
    - Receives Pod Specs
    - Downloads Pod Secrets from API Server
    - Mounting Volumes
    - Running Pod containers (via Container Runtime)
    - Reporting the status of the node and each Pod
    - Running container startup, liveness, and readiness probes
- **Kube-Proxy**
  - A networking agent that runs on each node
  - Core component of the Kubernetes networking stack
  - Manipulates iptables on the node
  - Ensures network packets get to the Pods
  - Acts as a "lazy" load balancer
  - Does NOT route network packets — manipulates iptables
  - Watches for changes to Services + Endpoints/EndpointSlices
- **Container Runtime (CRI)**
  - Manages the pod/container lifecycle
  - Receives instructions from kubelet via CRI
  - Examples: containerd (default), CRI-O
  - Creates a parent container — Pause Container (infrastructure container)

---

## Cluster Add-Ons

- DNS — CoreDNS or KubeDNS
- Ingress Controllers
- Metrics Server
- Logging Solution
- Monitoring Solution
- Dashboard — e.g., Rancher, Lens

---

## Kubernetes Distros

- **Upstream Kubernetes**
- **Downstream Kubernetes:**
  - GKE, EKS, AKS
  - RKE, Tanzu
  - Kind, K3s, etc.

---

## Managed Kubernetes — What the Cloud Abstracts Away

- Control plane is fully managed (API server, etcd, scheduler, controller manager)
- etcd backups and maintenance handled by provider
- Control plane upgrades simplified (one-click or automatic)
- Node provisioning via managed node pools
- Cloud Controller Manager pre-configured
- You focus on: workloads, networking config, RBAC, and application lifecycle

---

## Cluster Setup

- **GKE** (Production Ready, Highly Available & Resilient with GCP Best Practices)
  - gcloud CLI
  - GCP Console
  - Terraform (Very Important)
- **EKS** (Production Ready)
- **Kind** — used for local testing

---

## Key Takeaways

- The **control plane** (API server, etcd, scheduler, controller manager) is the brain of the cluster — it manages desired state but does not run workloads directly.
- **etcd** is the single source of truth; losing it means losing all knowledge of what the cluster is supposed to look like.
- **Worker nodes** run the actual workloads via kubelet, kube-proxy, and a container runtime; they take instructions from the control plane.
- Kubernetes operates on a **reconciliation loop** — it constantly observes current state, compares it to desired state, and acts to close any gap.

---

## Review Questions

### Beginner

1. What is Kubernetes and what problem does it solve for teams running containerized applications?
2. Name the four components of the Kubernetes control plane and describe what each one does.
3. What is the role of the kubelet on a worker node, and how does it differ from kube-proxy?
4. Why must etcd always have an odd number of members (e.g., 3, 5, 7)?
5. What is the difference between a managed Kubernetes service (like GKE or EKS) and running upstream Kubernetes yourself?

### Intermediate

1. A new pod is submitted to the cluster but never gets scheduled. Walk through the control-plane components that would be involved in diagnosing this — what would each component's role be?
2. The reconciliation loop is described as "observe → diff → act." Give a concrete example of what each step looks like when a Deployment's desired replica count is changed from 3 to 5.
3. Why is the API server described as "stateless," and what implications does that have for cluster resilience and scalability?
