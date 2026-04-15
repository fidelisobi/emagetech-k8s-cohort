# Session 12 — Connecting to a Cluster & kubectl Essentials

---

## Kubectl - Kubernetes CLI

> kubectl is to the Kubernetes API server what a TV remote is to a TV — you send commands, and the TV's internal systems act on them.

- Communicates with the Cluster Control Plane API Server
- Links:
  - https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands
  - https://kubernetes.io/docs/reference/kubectl/

**Syntax:**
```
kubectl [command] [TYPE] [NAME] [flags]
```
- Command = create, get, describe, delete, etc.
- Type = API Resource/Object e.g., Pods, Deployments, etc.
- Name = Name of API Resource
- Flags = Specifies optional flags

**Config Location (default):** `$HOME/.kube` or `~/.kube`

**Setup Default Editor:**
```bash
export KUBE_EDITOR='code --wait'
```

---

## Connecting to Managed Clusters

```bash
# GKE
gcloud container clusters get-credentials CLUSTER_NAME --zone ZONE --project PROJECT_ID

# EKS
aws eks update-kubeconfig --name CLUSTER_NAME --region REGION

# AKS
az aks get-credentials --resource-group RG_NAME --name CLUSTER_NAME
```

**kubeconfig Structure:**

> Think of kubeconfig as a contact book: 'Clusters' are addresses, 'Users' are ID cards, and a 'Context' is a named entry that says 'go to this address as this person.'

- **Clusters** — API server endpoints and CA certificates
- **Users** — authentication credentials (tokens, certs, exec plugins)
- **Contexts** — a cluster + user + namespace combination
- **Current-context** — the active context

```bash
kubectl config get-contexts          # list all contexts
kubectl config use-context <name>    # switch context
kubectl config current-context       # show active context
```

---

## Kubectl - How It Works

- Performs client-side validation
- Generates a JSON format API request and sends it to the API Server
- API Server provides a response
- API request includes authentication information, which gets validated by the API Server
- Performs CRUD operations on API Server resources/objects

**API Request Flow:**

```
kubectl apply -f deployment.yaml
       │
       ▼  (1) Client-side validation
       ▼  (2) Read ~/.kube/config → find current-context
       ▼  (3) HTTPS request with auth token
       │
  ┌────▼─────────────┐
  │   API Server     │
  │                  │
  │  (4) Authn       │
  │  (5) Authz       │
  │  (6) Admission   │
  │  (7) Persist     │
  └──────────────────┘
       │
       ▼  Response back to kubectl
```

---

## Kubectl - Essential Commands

**Read Operations:**
```bash
kubectl get pods                          # list pods
kubectl get pods -o wide                  # with IP and node info
kubectl get pods -o yaml                  # full YAML output
kubectl get pods -o json                  # full JSON output
kubectl get pods -o jsonpath='{.items[*].metadata.name}'  # extract fields
kubectl describe pod <name>              # detailed info + events
kubectl logs <pod> -c <container>        # container logs
kubectl logs <pod> --previous            # logs from crashed container
```

**Write Operations:**
```bash
kubectl apply -f manifest.yaml           # declarative create/update
kubectl create deployment nginx --image=nginx  # imperative create
kubectl delete pod <name>                # delete resource
kubectl edit deployment <name>           # edit live resource
```

**Debug Operations:**
```bash
kubectl exec -it <pod> -- /bin/sh        # shell into container
kubectl port-forward svc/<name> 8080:80  # local port forward
kubectl top pods                         # resource usage (requires metrics-server)
```

> **Note on `--` in `kubectl exec`:** The `--` separates kubectl flags from the command passed to the container. Without it, kubectl might try to interpret container command flags as its own.

> **Note on `kubectl top`:** This command requires the **metrics-server** add-on to be installed in the cluster. On managed clusters (GKE, EKS, AKS) it is often pre-installed; on self-managed clusters you must deploy it separately.

---

## Imperative vs Declarative

**Imperative** — tell Kubernetes what to do step by step:
```bash
kubectl create deployment nginx --image=nginx
kubectl scale deployment nginx --replicas=3
kubectl expose deployment nginx --port=80
```

**Declarative** — tell Kubernetes the desired end state:
```bash
kubectl apply -f deployment.yaml
```
- Preferred for production — version-controlled, repeatable, auditable
- `kubectl apply` tracks changes via `last-applied-configuration` annotation

---

## API Discovery

```bash
kubectl api-resources              # list all resource types
kubectl api-resources --namespaced # only namespaced resources
kubectl api-versions               # list all API versions
kubectl explain pod                # documentation for a resource
kubectl explain pod.spec.containers  # drill into nested fields
kubectl explain pod --recursive    # full field tree
```

**Dry Run (client-side validation):**
```bash
kubectl apply -f manifest.yaml --dry-run=client -o yaml
```
- Validates manifest without sending to API server
- Useful for generating YAML templates from imperative commands

**Generate YAML from imperative commands without creating resources:**
```bash
# Generate a Deployment YAML without creating it
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deployment.yaml
```

---

## Key Takeaways

- **kubectl** is the primary CLI for interacting with Kubernetes — it translates your commands into authenticated HTTPS requests to the API server.
- **kubeconfig** holds all the information kubectl needs to connect: cluster endpoints, credentials, and named contexts that combine them.
- Prefer **declarative** (`kubectl apply -f`) over imperative commands in production — it is version-controllable, repeatable, and auditable.
- Use `--dry-run=client -o yaml` to generate and inspect manifests before applying them, and remember that `kubectl top` requires metrics-server to be present in the cluster.
