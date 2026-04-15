# 🔄 GitOps — Git Is Your Cluster's Source of Truth

> **Pre-req:** Read [06-git-and-kubernetes.md](06-git-and-kubernetes.md) first.

---

## What Is GitOps?

GitOps is a way of operating Kubernetes where:

**The desired state of your cluster is always described in Git.**

A tool watches the Git repo and automatically makes the cluster match what's in Git.
You never run `kubectl apply` manually in production. Git does it for you.

```
Developer pushes change to Git
          │
          ▼
    Pull Request opened
          │
          ▼
    PR reviewed & merged to main
          │
          ▼
    GitOps tool detects change (ArgoCD / Flux)
          │
          ▼
    Tool applies change to the cluster
          │
          ▼
    Cluster matches Git ✅
```

---

## Why GitOps is Better Than Manual `kubectl apply`

| Problem | Without GitOps | With GitOps |
|---------|---------------|-------------|
| Who deployed that? | Check Slack... | `git log` |
| What's actually running? | `kubectl get all` might differ from your YAML | Git IS the truth |
| Rollback? | Apply old YAML manually | `git revert` → auto-deployed |
| Deploy to new environment | Copy-paste YAMLs, hope for the best | Point the tool at the same repo |
| Drift (someone edited live config) | Undetected until something breaks | Auto-corrected |

---

## The Four GitOps Principles

1. **Declarative** — Describe *what* you want, not *how* to get there
2. **Versioned** — Everything in Git, with full history
3. **Pulled automatically** — The cluster agent pulls changes (not pushed from CI)
4. **Continuously reconciled** — If the cluster drifts from Git, it's auto-corrected

---

## ArgoCD — GitOps for Kubernetes

**ArgoCD** is the most popular GitOps tool (and what we use in Session 26 of this class).

ArgoCD:
- Runs inside your Kubernetes cluster
- Watches a Git repo (or specific branch/path)
- Compares the cluster state to Git
- Automatically syncs when they drift apart
- Shows you a visual diff of what's changed

```
Git Repo (desired state)     Cluster (actual state)
  replicas: 4          vs.     replicas: 2  ← DRIFT DETECTED
         │
         └── ArgoCD syncs → kubectl apply → replicas: 4 ✅
```

---

## A Real ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/emage-tech/kubernetes-january-2026-cohort.git
    targetRevision: main          # watch the main branch
    path: class-materials/labs/lab-26-argocd/guestbook   # which folder
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook
  syncPolicy:
    automated:
      selfHeal: true              # auto-correct drift
      prune: true                 # delete resources removed from Git
```

**What this does:**
- Watches the `main` branch of the class repo
- Specifically watches the `lab-26-argocd/guestbook` folder
- If something in the cluster drifts from what's in that folder → auto-fix it
- If you delete a file from Git → ArgoCD deletes the resource from the cluster

---

## Environment Promotion with Git Branches

A common pattern for managing multiple environments:

```
Repo:
  branches/
    dev     → deploys to dev cluster
    staging → deploys to staging cluster
    main    → deploys to production cluster
```

Workflow:
1. Develop on a feature branch
2. Merge to `dev` → ArgoCD deploys to dev cluster
3. Test, then PR from `dev` → `staging`
4. Test staging → PR from `staging` → `main`
5. Production deploys automatically

Promoting a release = opening a Pull Request. The history is in Git.

---

## Secrets in GitOps — What NOT to Commit

One important rule: **never commit secrets (passwords, API keys, tokens) to Git**.

Git is version-controlled and often shared. Secrets in Git = secrets exposed.

Solutions:
| Tool | How It Works |
|------|-------------|
| **Sealed Secrets** | Encrypt secrets — only the cluster can decrypt |
| **External Secrets Operator** | Pull secrets from AWS Secrets Manager, Vault, etc. |
| **SOPS** | Encrypt secret files before committing |

In the class, you'll use Kubernetes Secrets (from ConfigMaps/Secrets lab — Session 15).
For production, always use one of the above approaches.

---

## 🧪 Try It Yourself

```bash
# See what ArgoCD looks like (if installed)
kubectl get applications -n argocd
kubectl get pods -n argocd

# Check the ArgoCD UI (port-forward to your local machine)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser at https://localhost:8080

# From the class repo — look at the ArgoCD lab
ls class-materials/labs/lab-26-argocd/
cat class-materials/labs/lab-26-argocd/README.md
```

---

## ✅ What You Learned

- GitOps = Git is the single source of truth for your cluster's desired state
- Changes are merged to Git, then automatically applied to the cluster
- ArgoCD watches your Git repo and reconciles drift automatically
- Environment promotion = Git branch strategy
- Never commit secrets — use Sealed Secrets, External Secrets, or SOPS

**Next:** [Branching Strategies for Teams →](08-branching-strategies.md)
