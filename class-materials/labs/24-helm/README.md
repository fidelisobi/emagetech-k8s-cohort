# Lab 24 — Helm Hands-On

## Overview

In this lab you will work with Helm — the Kubernetes package manager — from first principles.
You will add repositories, install and inspect releases, customize deployments, upgrade and
roll back, and finally create, debug, and package a chart from scratch.

This is a fully CLI-driven lab. No YAML files are provided — the goal is to build muscle
memory with the Helm command surface.

**Time estimate:** 60–75 minutes

---

## Prerequisites

- kubectl configured against the `cluster-dreams` cluster in `us-central1`
- Helm 3 installed (`helm version` should return v3.x)
- A personal namespace to avoid collisions with other students

### Verify your tooling

```bash
helm version
# Expected: version.BuildInfo{Version:"v3.x.x", ...}

kubectl get nodes
# Expected: cluster nodes listed
```

### Create a personal namespace

```bash
# Replace <yourname> with your first name (lowercase, no spaces)
kubectl create namespace helm-lab-<yourname>

# Set it as your default namespace for this lab to avoid typing -n on every command
kubectl config set-context --current --namespace=helm-lab-<yourname>
```

---

## Part A — Repositories

Helm charts are distributed through repositories. Before you can install anything, you must
add a repo and update the local cache.

### Step A1 — Add the Bitnami repository

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```

### Step A2 — Update the local repo cache

```bash
helm repo update
# Expected: "...Successfully got an update from the "bitnami" chart repository"
```

### Step A3 — List configured repositories

```bash
helm repo list
# Expected: NAME     URL
#           bitnami  https://charts.bitnami.com/bitnami
```

### Step A4 — Search for charts

```bash
# Search the bitnami repo for nginx charts
helm search repo nginx

# Search Artifact Hub (the public registry) for any nginx chart
helm search hub nginx | head -20
```

> `helm search repo` searches only repos you have added locally.
> `helm search hub` searches the public Artifact Hub (https://artifacthub.io).

### Step A5 — Inspect a chart before installing

Before installing, always read what a chart deploys and what values it exposes.

```bash
# Show chart metadata (version, description, dependencies)
helm show chart bitnami/nginx

# Show ALL default values the chart accepts
helm show values bitnami/nginx | head -60

# Show README (usage, parameters, examples)
helm show readme bitnami/nginx | head -80
```

---

## Part B — Install, Inspect, and Uninstall

### Step B1 — Install nginx with defaults

```bash
helm install my-nginx bitnami/nginx
```

Helm prints a NOTES section after install. Read it — it shows how to access the app.

### Step B2 — List installed releases

```bash
helm list
# Expected: NAME      NAMESPACE  REVISION  STATUS    CHART
#           my-nginx  helm-lab-… 1         deployed  nginx-x.y.z
```

### Step B3 — Inspect the live release

```bash
# See what values were used (only overrides, not defaults)
helm get values my-nginx

# See ALL computed values (overrides merged with defaults)
helm get values my-nginx --all

# See every Kubernetes manifest Helm rendered and applied
helm get manifest my-nginx

# See the chart notes that were displayed at install time
helm get notes my-nginx
```

> `helm get values` and `helm get manifest` are your primary debugging tools when a
> release behaves unexpectedly in production.

### Step B4 — Check the deployed resources

```bash
kubectl get all -l app.kubernetes.io/instance=my-nginx
```

---

## Part C — Customisation

Charts expose hundreds of parameters through their `values.yaml`. You can override them
two ways: with `--set` flags (quick one-offs) or with a values file (reproducible, git-tracked).

### Step C1 — Override with --set (quick)

```bash
# Change replica count to 2 at install time using --set
helm install my-nginx-set bitnami/nginx \
  --set replicaCount=2 \
  --set service.type=ClusterIP
```

Verify:

```bash
kubectl get deployment my-nginx-set-nginx -o jsonpath='{.spec.replicas}'
# Expected: 2
```

### Step C2 — Override with a values file (recommended for teams)

Create a file called `my-values.yaml` with the following content:

```yaml
replicaCount: 3

service:
  type: ClusterIP   # use ClusterIP; on GKE LoadBalancer creates a cloud LB (costs money)

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi

podLabels:
  environment: lab
  owner: student
```

Install using the values file:

```bash
helm install my-nginx-values bitnami/nginx -f my-values.yaml
```

Verify the label landed:

```bash
kubectl get pods -l environment=lab
```

> A values file should always be committed to Git alongside your Helm release config.
> It makes the installation reproducible and auditable.

---

## Part D — Upgrade and Rollback

### Step D1 — Upgrade a release

Upgrading changes the running release in-place. Helm stores every revision so you can
roll back.

```bash
# Change the replica count on my-nginx-values from 3 to 1
helm upgrade my-nginx-values bitnami/nginx -f my-values.yaml --set replicaCount=1
```

Check the revision history:

```bash
helm history my-nginx-values
# Expected: REVISION  STATUS      CHART        DESCRIPTION
#           1         superseded  nginx-x.y.z  Install complete
#           2         deployed    nginx-x.y.z  Upgrade complete
```

### Step D2 — Roll back to a previous revision

```bash
helm rollback my-nginx-values 1
```

Verify the replica count reverted:

```bash
helm history my-nginx-values
# Revision 3 should now show "Rollback to 1"

kubectl get deployment my-nginx-values-nginx -o jsonpath='{.spec.replicas}'
# Expected: 3 (back to original revision 1 value)
```

> Helm rollback creates a NEW revision — it never overwrites history. This means every
> change is auditable and reversible.

---

## Part E — Create a Chart from Scratch

### Step E1 — Scaffold a new chart

```bash
helm create my-chart
```

Explore the generated structure:

```bash
find my-chart -type f
```

Key files and what they do:

| File | Purpose |
|---|---|
| `Chart.yaml` | Chart metadata: name, version, description, appVersion |
| `values.yaml` | Default values — users override these at install time |
| `templates/deployment.yaml` | The main Deployment manifest (uses Go templating) |
| `templates/service.yaml` | Service manifest |
| `templates/hpa.yaml` | HPA (disabled by default via `autoscaling.enabled`) |
| `templates/ingress.yaml` | Ingress (disabled by default) |
| `templates/_helpers.tpl` | Named templates (helpers) — shared macro definitions |
| `templates/NOTES.txt` | Text shown to the user after `helm install` |

### Step E2 — Customise the chart

Open `my-chart/values.yaml` and change:

```yaml
replicaCount: 2

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "1.25"

service:
  type: ClusterIP
  port: 80
```

### Step E3 — Template and debug without installing

`helm template` renders the chart to stdout without talking to the cluster. Use it to
review what will be applied before committing.

```bash
# Render the chart with default values
helm template my-release ./my-chart

# Render and pipe through less for easier reading
helm template my-release ./my-chart | less

# Override a value during template rendering
helm template my-release ./my-chart --set replicaCount=5
```

### Step E4 — Dry run with full cluster validation

`--dry-run` renders the templates AND sends them to the API server for validation, but
does not persist anything. Useful for catching schema errors.

```bash
helm install my-release ./my-chart --dry-run --debug
```

The `--debug` flag adds:
- Computed values (merged defaults + overrides)
- The rendered YAML for every template
- Kubernetes API server validation errors

Introduce a deliberate error to see how Helm reports it:

```bash
# Mis-spell a field name in values.yaml, then run dry-run again
helm install my-release ./my-chart --dry-run --debug --set replicaCount=not-a-number
```

### Step E5 — Install the chart

```bash
helm install my-release ./my-chart
helm list
kubectl get all -l app.kubernetes.io/instance=my-release
```

---

## Part F — Package and Distribute

### Step F1 — Lint the chart

Before packaging, validate that the chart follows Helm conventions:

```bash
helm lint ./my-chart
# Expected: [INFO] Chart.yaml: icon is recommended
#           1 chart(s) linted, 0 chart(s) failed
```

### Step F2 — Package the chart into a .tgz archive

```bash
helm package ./my-chart
# Creates: my-chart-0.1.0.tgz  (version from Chart.yaml)
ls -lh my-chart-*.tgz
```

This archive is what you would push to a chart repository (OCI registry, Chartmuseum, etc.).

### Step F3 — Install directly from the archive

```bash
helm install from-archive ./my-chart-0.1.0.tgz
helm list
```

---

## Part G — Cleanup

Uninstall all releases created in this lab:

```bash
helm uninstall my-nginx
helm uninstall my-nginx-set
helm uninstall my-nginx-values
helm uninstall my-release
helm uninstall from-archive

# Verify nothing remains
helm list
```

Reset your default namespace:

```bash
kubectl config set-context --current --namespace=default
kubectl delete namespace helm-lab-<yourname>
```

---

## Discussion Questions

1. What is the difference between `helm upgrade` and `helm upgrade --install`?
2. Why should you never use `--set` for secrets (like passwords) in production?
3. What is the difference between `chart version` and `appVersion` in `Chart.yaml`?
4. How does Helm store release state? Where does it persist between sessions?
   (Hint: `kubectl get secrets | grep helm`)
5. What is a subchart / dependency chart? How do you add one?

---

## Key Concepts

| Concept | Description |
|---|---|
| Release | A named instance of a chart installed into a cluster |
| Revision | A versioned snapshot of a release — created on every install, upgrade, or rollback |
| `values.yaml` | Default configuration; users override with `-f` or `--set` |
| `helm template` | Renders charts to YAML without touching the cluster |
| `--dry-run --debug` | Validates against the API server without persisting anything |
| `helm lint` | Static analysis — catches common chart authoring mistakes |
| `helm package` | Bundles chart directory into a `.tgz` for distribution |
