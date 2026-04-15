# Lab 26 — ArgoCD GitOps

## Overview

In this lab you will use ArgoCD to implement GitOps — a practice where Git is the single
source of truth for cluster state and any deviation (drift) from Git is automatically
detected and corrected.

You will:

1. Access the ArgoCD UI
2. Deploy the guestbook app from a public Git repository
3. Observe GitOps drift detection and self-healing in action
4. Deploy a Helm chart via ArgoCD with custom values
5. Explore diff, history, and rollback in the UI

**Time estimate:** 60–75 minutes

---

## Prerequisites

- kubectl configured for `cluster-dreams` in `us-central1`
- ArgoCD deployed in the `argocd` namespace

### Verify ArgoCD is running

```bash
kubectl get pods -n argocd
# Expected: all pods in Running state
# argocd-server-xxx             1/1   Running
# argocd-application-controller-0  1/1   Running
# argocd-repo-server-xxx        1/1   Running
# argocd-redis-xxx              1/1   Running
# argocd-dex-server-xxx         1/1   Running
```

### Install the argocd CLI (optional but recommended)

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o /usr/local/bin/argocd \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd
```

---

## Part A — Access the ArgoCD UI

### Step A1 — Port-forward the ArgoCD server

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Keep this terminal open. The UI is available at: https://localhost:8080

> Accept the self-signed certificate warning in your browser.

### Step A2 — Get the initial admin password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

Log in with:
- **Username:** `admin`
- **Password:** output of the command above

> In production, change this password immediately after first login:
> `argocd account update-password`

### Step A3 — Log in via the CLI

```bash
argocd login localhost:8080 \
  --username admin \
  --password <password-from-step-A2> \
  --insecure
```

> `--insecure` bypasses TLS verification for the self-signed cert in the lab.

---

## Part B — Deploy the Guestbook Application (Git source)

The guestbook app is the canonical ArgoCD example — a simple Redis-backed PHP guestbook
with plain YAML manifests in a public GitHub repo.

### Step B1 — Apply the Application manifest

```bash
kubectl apply -f 01-application.yaml
```

### Step B2 — Observe the sync in the UI

1. Go to the ArgoCD UI: https://localhost:8080
2. The `guestbook` application should appear on the home screen
3. It starts in **OutOfSync** state (Git has resources the cluster doesn't yet)
4. Because `automated.selfHeal: true` is set, ArgoCD begins syncing automatically
5. Within ~30 seconds it transitions to **Synced** and **Healthy**

### Step B3 — Explore the application graph

Click the `guestbook` app tile:
- The **app graph** shows all resources ArgoCD is managing (Deployments, Services, Pods)
- Green = healthy, Yellow = progressing, Red = degraded
- Click any resource to see its live YAML and events

### Step B4 — Verify the resources are deployed

```bash
kubectl get all -n guestbook
```

### Step B5 — View the sync history

In the app view, click **History and Rollback** (clock icon) in the top toolbar.
You will see the sync history with commit SHAs and timestamps.

---

## Part C — GitOps Drift Detection and Self-Healing

This is the core GitOps demonstration. You will make a change directly in the cluster
(bypassing Git), then watch ArgoCD revert it.

### Step C1 — Manually scale the guestbook deployment

```bash
# The guestbook-ui deployment currently has 1 replica (as defined in Git)
# Scale it up to 3 — this is a manual change not in Git
kubectl scale deployment guestbook-ui -n guestbook --replicas=3
```

### Step C2 — Watch ArgoCD detect the drift

```bash
# Watch the deployment — you should see ArgoCD quickly revert it
kubectl get deployment guestbook-ui -n guestbook -w
```

In the ArgoCD UI:
1. The app briefly shows as **OutOfSync** (orange status)
2. Because `selfHeal: true`, ArgoCD triggers an automatic sync
3. Within ~10–20 seconds, replicas return to 1 (the Git-defined value)
4. The app returns to **Synced** status

> This is self-healing in action. ANY manual change to managed resources
> is reverted. In production, this enforces that Git is the ONLY way to
> change cluster state.

### Step C3 — Try editing a ConfigMap (if guestbook has one)

```bash
# Add a label to the guestbook-ui deployment
kubectl label deployment guestbook-ui -n guestbook testing=yes
```

Watch the label disappear as ArgoCD restores the resource to the Git-defined state.

### Step C4 — Temporarily disable self-healing

Sometimes you need to make emergency changes without waiting for a Git commit.

```bash
# Disable self-healing for 5 minutes (emergency change window)
argocd app set guestbook --self-heal=false

# Make your change
kubectl scale deployment guestbook-ui -n guestbook --replicas=3
# Change persists now

# Re-enable self-healing (will immediately revert your change)
argocd app set guestbook --self-heal=true
```

---

## Part D — ArgoCD Application Diff

Before syncing, ArgoCD can show you exactly what will change.

### Step D1 — Check current diff from the CLI

```bash
argocd app diff guestbook
```

If everything is synced, there is no output. To create a diff:

```bash
# Pause auto-sync first
argocd app set guestbook --sync-policy none

# Make a manual change
kubectl scale deployment guestbook-ui -n guestbook --replicas=5

# Now check the diff
argocd app diff guestbook
# Expected: shows "-replicas: 1" and "+replicas: 5" (Git vs live)
```

### Step D2 — View the diff in the UI

1. In the app view, click **App Diff** button (top toolbar)
2. The diff viewer shows Git state (left) vs live cluster state (right)
3. Red lines are in the cluster but not in Git; green lines are in Git but not in cluster

### Step D3 — Manually trigger a sync to restore

```bash
argocd app sync guestbook
```

Or in the UI: click **Sync** → **Synchronize**.

### Step D4 — Re-enable automated sync

```bash
argocd app set guestbook --sync-policy automated
```

---

## Part E — Deploy nginx via Helm (ArgoCD Helm Application)

### Step E1 — Apply the Helm Application

```bash
kubectl apply -f 02-application-helm.yaml
```

This Application uses a Helm chart source (not Git YAML). ArgoCD will run `helm template`
internally and apply the rendered manifests.

### Step E2 — Observe the Application in the UI

1. Go to https://localhost:8080
2. The `nginx-helm` app appears in **OutOfSync** state
3. Because there is NO `automated` sync policy, it will NOT sync automatically
4. You must trigger the sync manually

### Step E3 — Trigger a manual sync

From the UI:
1. Click the `nginx-helm` app
2. Click **Sync** (top toolbar)
3. Review what will be applied in the sync dialog
4. Click **Synchronize**

From the CLI:
```bash
argocd app sync nginx-helm
```

### Step E4 — Verify the deployment

```bash
kubectl get all -n nginx-helm
kubectl get pods -n nginx-helm -o wide
```

### Step E5 — Customize values and trigger a new sync

The Application manifest (`02-application-helm.yaml`) contains inline `values:`.
To change the configuration:

1. Edit `02-application-helm.yaml` — change `replicaCount: 2` to `replicaCount: 3`
2. Apply the updated manifest:

```bash
kubectl apply -f 02-application-helm.yaml
```

3. In the UI, the app immediately shows as **OutOfSync** (values changed)
4. Trigger a sync to apply the new replica count

### Step E6 — View Helm parameters in the UI

1. In the `nginx-helm` app view, click **App Details**
2. Click the **Parameters** tab
3. You will see all Helm values: defaults from the chart PLUS your overrides
4. You can override values directly from the UI (not recommended in production — use Git)

---

## Part F — History and Rollback

### Step F1 — View sync history

```bash
argocd app history nginx-helm
```

Output shows each sync event with its timestamp and revision.

### Step F2 — Rollback to a previous revision

1. In the UI, click **History and Rollback** for the `nginx-helm` app
2. You see a list of previous sync revisions
3. Click **Rollback** on a previous revision

> Note: Rollback in ArgoCD is a "sync to previous state". For Helm apps, this means
> re-rendering the chart at the previous Helm chart version and values.

### Step F3 — Rollback via CLI

```bash
# List revisions
argocd app history nginx-helm

# Roll back to revision 1
argocd app rollback nginx-helm 1
```

---

## Cleanup

```bash
# Delete the Applications (this also deletes the deployed resources due to finalizer)
kubectl delete application guestbook -n argocd
kubectl delete application nginx-helm -n argocd

# Verify namespaces are cleaned up
kubectl get namespace guestbook
kubectl get namespace nginx-helm
```

---

## Discussion Questions

1. What is the difference between ArgoCD `prune: true` and `prune: false`?
   In which scenario would you want prune disabled?
2. How does ArgoCD handle a sync when a Kubernetes resource has been modified
   by a controller (e.g., a Deployment's `status` field)?
3. What is the difference between an ArgoCD Application and an ApplicationSet?
4. Where does ArgoCD store its state? What happens if the ArgoCD namespace is deleted?
5. How would you structure ArgoCD to manage 50 microservices across dev, staging, and
   production? (Hint: think about App of Apps pattern)

---

## Key Concepts

| Concept | Description |
|---|---|
| Application | ArgoCD CRD that links a Git source to a cluster destination |
| Source of Truth | The Git repository — all desired state lives here |
| Sync | The act of making the cluster match the Git state |
| OutOfSync | Cluster state differs from Git state (drift detected) |
| selfHeal | Automatically revert manual cluster changes back to Git state |
| prune | Delete cluster resources that no longer exist in Git |
| App of Apps | An ArgoCD Application that deploys other ArgoCD Applications |
| AppProject | Access control boundary for Applications (restricts repos, clusters, namespaces) |
