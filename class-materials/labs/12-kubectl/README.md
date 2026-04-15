# Lab 12: kubectl Essentials

## Overview

kubectl is the primary command-line interface to a Kubernetes cluster. In this lab you will
apply a sample pod and then systematically work through the most important kubectl
sub-commands: inspecting resources, reading logs, running commands inside containers,
forwarding ports, and generating YAML declaratively.

**Estimated time:** 45 minutes

**Prerequisites:**
- Completed Lab 11 (cluster connection is working)
- `kubectl` pointing at the shared GKE cluster

---

## Part 1: Apply the Sample Pod

### 1.1 Create the pod

```bash
# Move into the lab directory
cd labs/12-kubectl

# Apply the manifest. kubectl reads the file, calls the API server, and creates the pod.
kubectl apply -f 01-sample-pod.yaml
```

Expected output:
```
pod/sample-nginx created
```

### 1.2 Watch it start

```bash
# -w (watch) streams updates. The STATUS column will move through:
#   Pending → ContainerCreating → Running
# Press Ctrl-C to stop watching once STATUS shows Running.
kubectl get pod sample-nginx -w
```

---

## Part 2: Inspecting Resources

### 2.1 get — the everyday listing command

```bash
# Basic get — shows NAME, READY, STATUS, RESTARTS, AGE
kubectl get pod sample-nginx

# All pods in the default namespace
kubectl get pods

# All pods across every namespace
kubectl get pods --all-namespaces
# Shorthand version
kubectl get pods -A

# Filter by label — the lab manifest sets lab=12-kubectl
kubectl get pods -l lab=12-kubectl
```

### 2.2 describe — human-readable full detail

```bash
# Shows all fields, events, and conditions. Essential for debugging.
kubectl describe pod sample-nginx
```

Key sections in the output:

| Section | What it tells you |
|---|---|
| **Labels / Annotations** | Metadata attached to the pod |
| **Node** | Which node the pod was scheduled to |
| **Status / Phase** | Current lifecycle phase |
| **Containers** | Image, ports, resource requests/limits, environment variables |
| **Conditions** | PodScheduled, Initialized, ContainersReady, Ready |
| **Events** | Chronological record — start here when debugging |

---

## Part 3: Output Formatting

### 3.1 YAML and JSON output

```bash
# Full object as YAML — this is exactly what the API server stores
kubectl get pod sample-nginx -o yaml

# Full object as JSON
kubectl get pod sample-nginx -o json

# Wide format — adds NODE and NOMINATED NODE columns
kubectl get pods -o wide
```

### 3.2 jsonpath — surgical extraction

`jsonpath` lets you pull a single field from the API response without a full YAML dump.

```bash
# Get the pod's current phase (Running, Pending, Failed, etc.)
kubectl get pod sample-nginx -o jsonpath='{.status.phase}'

# Get the node the pod is running on
kubectl get pod sample-nginx -o jsonpath='{.spec.nodeName}'

# Get the first container's image
kubectl get pod sample-nginx -o jsonpath='{.spec.containers[0].image}'

# List all container names in a pod (useful for multi-container pods)
kubectl get pod sample-nginx -o jsonpath='{.spec.containers[*].name}'

# Add a newline after the output so your prompt is not on the same line
kubectl get pod sample-nginx -o jsonpath='{.status.podIP}{"\n"}'
```

### 3.3 custom-columns — tabular output you design

```bash
# Define your own column headers and jsonpath expressions
kubectl get pods -o custom-columns=\
'NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,IMAGE:.spec.containers[0].image'
```

### 3.4 Sort and filter with --sort-by

```bash
# Sort pods by creation timestamp (oldest first)
kubectl get pods --sort-by=.metadata.creationTimestamp

# Sort nodes by name
kubectl get nodes --sort-by=.metadata.name
```

---

## Part 4: Logs

```bash
# Print all logs from the nginx container since it started
kubectl logs sample-nginx

# Stream logs in real time (equivalent to tail -f)
kubectl logs sample-nginx -f

# Show only the last 20 lines
kubectl logs sample-nginx --tail=20

# Show logs from the last 5 minutes
kubectl logs sample-nginx --since=5m

# In a multi-container pod you must specify the container name with -c
# kubectl logs <POD_NAME> -c <CONTAINER_NAME>
# Our pod only has one container, but the flag is worth knowing:
kubectl logs sample-nginx -c nginx

# Show logs including timestamps
kubectl logs sample-nginx --timestamps=true
```

> **Note:** Nginx only writes to its access log when it receives a request.
> You will see startup messages but the access log will be empty until you
> send HTTP traffic (see Part 5).

---

## Part 5: Port Forwarding

Port-forward creates a tunnel from a local port on your laptop to a port inside the pod.
It uses the API server as a proxy — no Ingress or Service needed.

```bash
# Forward local port 8080 → container port 80
# Run this command in a separate terminal tab and leave it running
kubectl port-forward pod/sample-nginx 8080:80
```

With the forward running, open a second terminal and send a request:

```bash
# Send an HTTP request through the tunnel
curl http://localhost:8080

# Or open in a browser: http://localhost:8080
```

You should see the nginx welcome page HTML. Switch back to the port-forward terminal and
you will see the access log entry appear. Press **Ctrl-C** to stop the tunnel when done.

---

## Part 6: exec — Run Commands Inside a Container

```bash
# Run a single command and exit
# -it allocates a pseudo-TTY and keeps stdin open (needed for interactive shells)
kubectl exec sample-nginx -- nginx -v

# Run an interactive shell inside the container
kubectl exec -it sample-nginx -- /bin/bash

# Once inside the shell, explore the nginx configuration:
#   cat /etc/nginx/nginx.conf
#   ls /usr/share/nginx/html/
#   exit

# Run a one-liner without an interactive shell (useful in scripts)
kubectl exec sample-nginx -- cat /etc/nginx/nginx.conf

# In a multi-container pod, specify the container
kubectl exec -it sample-nginx -c nginx -- /bin/bash
```

---

## Part 7: Generating YAML Imperatively

`--dry-run=client -o yaml` lets kubectl generate a manifest for you without creating
anything in the cluster. This is the fastest way to get a correct YAML skeleton.

```bash
# Generate a pod manifest without creating it
kubectl run generated-pod \
  --image=busybox:1.36 \
  --dry-run=client \
  -o yaml

# Save it to a file so you can edit it
kubectl run generated-pod \
  --image=busybox:1.36 \
  --dry-run=client \
  -o yaml > my-pod.yaml

# Generate a Deployment manifest
kubectl create deployment my-deploy \
  --image=nginx:1.25 \
  --replicas=3 \
  --dry-run=client \
  -o yaml

# Generate a Service manifest
kubectl expose pod sample-nginx \
  --port=80 \
  --name=sample-nginx-svc \
  --dry-run=client \
  -o yaml
```

> **Tip:** Always use `--dry-run=client` (not `--dry-run=server`) during lab exercises to
> avoid accidentally creating resources you did not intend to.

---

## Part 8: Exploring the API with kubectl explain

`kubectl explain` reads the cluster's OpenAPI schema and prints field documentation
inline. You never need to leave the terminal to understand what a field does.

```bash
# Top-level documentation for Pod
kubectl explain pod

# The pod spec
kubectl explain pod.spec

# Container fields inside pod spec
kubectl explain pod.spec.containers

# A specific field (--recursive shows all nested fields at once)
kubectl explain pod.spec.containers.resources
kubectl explain pod.spec.containers.resources --recursive

# Useful fields to explore in this lab
kubectl explain pod.metadata.labels
kubectl explain pod.spec.restartPolicy
kubectl explain pod.status
```

---

## Part 9: Namespace and Context Management

### 9.1 Working with namespaces

```bash
# Create a personal namespace for this lab
kubectl create namespace lab12-practice

# Deploy the pod into your new namespace
kubectl apply -f 01-sample-pod.yaml -n lab12-practice

# List pods in your namespace
kubectl get pods -n lab12-practice

# The -n flag works with every kubectl command
kubectl describe pod sample-nginx -n lab12-practice
kubectl logs sample-nginx -n lab12-practice
```

### 9.2 Switching the default namespace in your context

Every kubeconfig context has a default namespace. You can change it so you do not need
to type `-n` on every command.

```bash
# Check your current context name
kubectl config current-context

# Set the default namespace for the current context to lab12-practice
kubectl config set-context --current --namespace=lab12-practice

# Verify — the CURRENT column shows which context is active
kubectl config get-contexts

# Now kubectl get pods works against lab12-practice without -n
kubectl get pods

# Switch back to default when done
kubectl config set-context --current --namespace=default
```

### 9.3 Multiple contexts (informational)

```bash
# List all contexts in your kubeconfig
kubectl config get-contexts

# Switch to a different context (if you have multiple clusters configured)
kubectl config use-context <CONTEXT_NAME>

# View the full kubeconfig file
kubectl config view
```

---

## Part 10: Labels and Annotations (Hands-On)

```bash
# Add a new label to a running pod imperatively
kubectl label pod sample-nginx version=v1

# Overwrite an existing label
kubectl label pod sample-nginx env=lab --overwrite

# Remove a label (append a minus sign to the key name)
kubectl label pod sample-nginx version-

# Add an annotation
kubectl annotate pod sample-nginx notes="practising kubectl in lab 12"

# View the updated labels and annotations
kubectl get pod sample-nginx --show-labels
kubectl describe pod sample-nginx | grep -A5 Annotations
```

---

## Clean Up

```bash
# Delete the pod in the default namespace
kubectl delete pod sample-nginx

# Delete the pod in your practice namespace
kubectl delete pod sample-nginx -n lab12-practice

# Delete the practice namespace (this also deletes everything inside it)
kubectl delete namespace lab12-practice

# Verify everything is gone
kubectl get pods
kubectl get namespaces
```

---

## Summary

After completing this lab you should be able to:

- Apply, inspect, and delete pods with `kubectl apply`, `get`, `describe`, and `delete`
- Read container logs with `kubectl logs` and filter by time or line count
- Open an interactive shell inside a running container with `kubectl exec -it`
- Forward a local port to a pod port with `kubectl port-forward`
- Extract specific fields from API responses using `-o jsonpath`
- Generate YAML stubs imperatively with `--dry-run=client -o yaml`
- Use `kubectl explain` to read API field documentation without leaving the terminal
- Switch the default namespace in your kubeconfig context
