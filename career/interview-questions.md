# 🎙️ Interview Questions — Kubernetes Engineer

60+ questions across 5 categories, with model answers. Practice these out loud — saying it matters as much as knowing it.

---

## Category 1: Core Kubernetes Concepts

**Q: What is Kubernetes and why do organizations use it?**
> Kubernetes is a container orchestration platform that automates deploying, scaling, and managing containerized applications. Organizations use it because it provides self-healing (restarts failed containers), horizontal scaling (adds replicas under load), rolling deployments (zero-downtime updates), and a declarative configuration model that makes infrastructure reproducible and auditable.

**Q: Explain the difference between a Pod, Deployment, and StatefulSet.**
> A Pod is the smallest deployable unit — one or more containers sharing network and storage. A Deployment manages stateless Pods: it ensures a desired number of replicas are running and handles rolling updates and rollbacks. A StatefulSet is for stateful workloads (databases, queues) that need stable network identities, ordered deployment, and persistent storage that survives pod restarts.

**Q: How does Kubernetes handle a failing container?**
> Through the kubelet and liveness/readiness probes. If a liveness probe fails, Kubernetes restarts the container. If a readiness probe fails, the Pod is removed from Service endpoints (stops receiving traffic) but isn't restarted. The restart policy (Always/OnFailure/Never) and backoff delay govern restart behavior. Repeated failures trigger CrashLoopBackOff with exponential backoff.

**Q: What is the difference between a ClusterIP, NodePort, and LoadBalancer Service?**
> ClusterIP creates a virtual IP reachable only inside the cluster — for internal service-to-service communication. NodePort exposes the Service on a static port (30000–32767) on every node's external IP — useful for dev/test but not production. LoadBalancer provisions an external cloud load balancer with a public IP that routes to the Service — the production-grade way to expose apps externally.

**Q: What happens when you run `kubectl apply -f deployment.yaml`?**
> kubectl sends the manifest to the API server. The API server validates it, persists it to etcd, and notifies the Deployment controller. The controller calculates the difference between desired state (the YAML) and actual state (running pods), then instructs the scheduler to create new Pods. The scheduler assigns Pods to nodes based on resource availability and constraints. The kubelet on each node pulls the container image and starts the container.

**Q: What is etcd and what happens if it goes down?**
> etcd is Kubernetes' distributed key-value store — it holds the entire cluster state (all API objects). If etcd goes down, the control plane stops functioning: no new Pods can be scheduled, no changes can be made. However, existing workloads continue running because they're managed by kubelet on each node, which operates independently. Restoring etcd from backup is a critical operational procedure (covered in Project 13).

**Q: Explain the Kubernetes control plane components.**
> The control plane has four main components: the API server (the front door — all kubectl commands go here), etcd (state storage), the scheduler (assigns Pods to nodes based on resources and constraints), and the controller manager (runs controllers that reconcile desired vs actual state — Deployment controller, ReplicaSet controller, etc.). In managed clusters (GKE/EKS/AKS), the control plane is managed by the cloud provider.

---

## Category 2: Networking

**Q: How does DNS work inside a Kubernetes cluster?**
> Kubernetes runs CoreDNS as the cluster DNS server. Every Service gets a DNS name: `<service>.<namespace>.svc.cluster.local`. Pods are configured to use CoreDNS automatically via `/etc/resolv.conf`. When a Pod queries `my-service`, CoreDNS resolves it to the ClusterIP. This is why apps use service names instead of IPs — IPs change, names don't.

**Q: What is a Network Policy and why would you use one?**
> By default, all Pods can reach all other Pods in a Kubernetes cluster — a flat, open network. A NetworkPolicy restricts this by defining which Pods can send or receive traffic and on which ports. You'd use them to implement a zero-trust security model: databases should only accept connections from the app tier, not from logging or monitoring Pods.

**Q: What is the difference between Ingress and a LoadBalancer Service?**
> A LoadBalancer Service provisions one cloud load balancer per service — expensive at scale. An Ingress is a single entry point (one load balancer) that routes to multiple services based on hostname or URL path, with support for TLS termination. An Ingress resource defines the routing rules; an Ingress Controller (nginx, traefik, etc.) implements them.

**Q: A Pod can't reach another Service. Walk me through your debugging process.**
> 1. `kubectl get pods` — is the source Pod running?  
> 2. `kubectl exec -it <pod> -- nslookup <service>` — does DNS resolve?  
> 3. `kubectl get svc <service>` — does the Service exist? Check the CLUSTER-IP.  
> 4. `kubectl get endpoints <service>` — are there healthy endpoints? Empty = no Pods match the selector.  
> 5. `kubectl describe pod <target-pod>` — is it Running and Ready?  
> 6. `kubectl get networkpolicy` — is a NetworkPolicy blocking traffic?  
> 7. Try `kubectl exec -it <pod> -- curl http://<clusterip>:<port>` to bypass DNS.

---

## Category 3: Storage

**Q: What is the difference between a PersistentVolume and a PersistentVolumeClaim?**
> A PersistentVolume (PV) is a piece of storage in the cluster — provisioned by an admin or dynamically by a StorageClass. A PersistentVolumeClaim (PVC) is a request for storage by a Pod — specifying size, access mode, and optionally a StorageClass. The binding between PVC and PV is like a Pod requesting CPU/memory from a Node.

**Q: What access modes does Kubernetes support for persistent storage?**
> ReadWriteOnce (RWO) — mounted read-write by a single node. ReadOnlyMany (ROX) — mounted read-only by many nodes. ReadWriteMany (RWX) — mounted read-write by many nodes simultaneously (requires a network filesystem like NFS or cloud-native solutions like GCP Filestore). ReadWriteOncePod (RWOP, 1.22+) — mounted read-write by exactly one Pod.

---

## Category 4: Security & RBAC

**Q: Explain how RBAC works in Kubernetes.**
> RBAC (Role-Based Access Control) has four objects: Role and ClusterRole define what actions (verbs: get, list, create, delete) are allowed on which resources (pods, deployments, secrets). RoleBinding and ClusterRoleBinding attach a Role to a subject (User, Group, or ServiceAccount). A Role + RoleBinding is namespace-scoped. ClusterRole + ClusterRoleBinding is cluster-wide.

**Q: What is a ServiceAccount and why does it matter?**
> A ServiceAccount is an identity for processes running inside Pods. Every Pod runs as a ServiceAccount (default if not specified). The ServiceAccount can be bound to RBAC roles to grant the Pod permissions to call the Kubernetes API — for example, ArgoCD needs permissions to create Deployments. The principle of least privilege applies: Pods should only have the permissions they need.

**Q: What is the difference between Kyverno and OPA/Gatekeeper?**
> Both enforce policies as code in Kubernetes. Kyverno is Kubernetes-native — policies are written as YAML and use the same Kubernetes API patterns. OPA/Gatekeeper uses Rego, a purpose-built policy language that's more powerful but has a steeper learning curve. For most K8s use cases (required labels, registry restrictions, no privileged containers), Kyverno is faster to implement and easier to maintain.

---

## Category 5: GitOps & Operations

**Q: What is GitOps and how does ArgoCD implement it?**
> GitOps is a practice where the desired state of your infrastructure and applications is stored in Git, and a tool continuously reconciles the cluster to match that state. ArgoCD watches a Git repo and compares it to the live cluster. If they drift, ArgoCD syncs — either automatically (if autoSync is configured) or with manual approval. This gives you a complete audit trail (Git history), instant rollbacks (git revert), and environment consistency.

**Q: How do you do a zero-downtime deployment in Kubernetes?**
> The default rolling update strategy replaces Pods gradually — you can tune `maxUnavailable` (how many old Pods can be down at once) and `maxSurge` (how many extra new Pods can run). For zero downtime: set `maxUnavailable: 0` and `maxSurge: 1`. Combine with readiness probes so traffic only routes to Pods that have passed health checks. For more control: Blue/Green (switch traffic all at once between two full environments) or Canary (route a percentage of traffic to the new version, gradually increase).

**Q: A deployment is stuck in a rolling update. What do you check?**
> 1. `kubectl rollout status deployment/<name>` — see where it's stuck  
> 2. `kubectl describe deployment/<name>` — check events for scheduling failures  
> 3. `kubectl get pods` — look for Pending, ImagePullBackOff, CrashLoopBackOff  
> 4. `kubectl logs <new-pod>` — app errors?  
> 5. Check readiness probe — if new pods never become ready, the rollout stalls  
> 6. Roll back: `kubectl rollout undo deployment/<name>`

**Q: How would you handle a secret rotation in Kubernetes?**
> Update the Secret object with the new value (`kubectl create secret generic --dry-run=client -o yaml | kubectl apply -f -`). Pods that mount it as a volume pick up the change automatically within the kubelet sync period (~1 min). Pods that use it as an env var need to be restarted (rolling restart: `kubectl rollout restart deployment/<name>`). For production, use an external secrets manager (Vault, AWS Secrets Manager) with the External Secrets Operator so rotation happens at the source and syncs automatically.

---

## Behavioral Questions (Don't Skip These)

**Q: Tell me about a time you debugged a production incident.**
> Use the STAR format: Situation (what broke), Task (your role), Action (what you did step by step), Result (what you fixed and what you learned). Your Project 13 runbook scenarios are perfect material for this.

**Q: How do you approach learning a new tool or technology?**
> Have a real answer: "I read the official docs first to understand the design philosophy, then do a hands-on walkthrough, then try to break it deliberately to understand failure modes." That's exactly what this cohort taught you to do.

**Q: Describe a time you improved a process or system.**
> Projects 11 (security score from 35% to 90%), Project 12 (self-service platform replacing manual kubectl), or Project 8 (before: no visibility, after: full observability stack) are all perfect answers.

---

## Questions to Ask Your Interviewer

These signal curiosity and seniority:

- "What does your current GitOps workflow look like, and where are the pain points?"
- "How do teams get access to the cluster — is there a self-service model or is it all kubectl?"
- "What's your current observability stack and what gaps are you trying to close?"
- "How do you handle secret rotation today?"
- "What does a typical oncall incident look like, and what tooling do engineers use to debug it?"
