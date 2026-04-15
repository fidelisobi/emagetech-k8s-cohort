# 📦 Git + Kubernetes — Your Cluster Lives in a Repo

> **Pre-req:** Read [02-your-first-repo.md](02-your-first-repo.md) and [03-branching.md](03-branching.md) first.

---

## Why Your Kubernetes Config Belongs in Git

Kubernetes manages everything through YAML files — Deployments, Services, ConfigMaps, Ingress rules, etc.

You *could* apply them with `kubectl apply -f` and then throw them away. But then:
- How do you know what changed?
- How do you roll back a bad change?
- How does your teammate know what's deployed?
- How do you deploy to a new environment?

**Answer: put it all in Git.** Every YAML file tracked, every change recorded.

---

## What a K8s Git Repo Looks Like

A common structure for a Kubernetes project:

```
my-app/
├── README.md
├── app/                          # Application source code
│   ├── Dockerfile
│   └── src/
└── k8s/                          # All Kubernetes configs
    ├── namespace.yaml
    ├── deployments/
    │   ├── api-deployment.yaml
    │   └── frontend-deployment.yaml
    ├── services/
    │   ├── api-service.yaml
    │   └── frontend-service.yaml
    ├── configmaps/
    │   └── app-config.yaml
    ├── ingress/
    │   └── ingress.yaml
    └── namespaces/
        └── production.yaml
```

Everything is text. Everything is reviewable. Everything is in Git.

---

## The Git Workflow for Kubernetes Changes

Making a change to production is no longer "log into server and edit a file."
It's a Git workflow:

```bash
# 1. Create a branch for your change
git checkout -b fix/increase-api-replicas

# 2. Edit the YAML
vim k8s/deployments/api-deployment.yaml
# Change replicas: 2 → replicas: 4

# 3. Commit
git add k8s/deployments/api-deployment.yaml
git commit -m "Scale API deployment to 4 replicas for load handling"

# 4. Push and open a PR
git push origin fix/increase-api-replicas
# Open PR on GitHub → teammate reviews → approve → merge

# 5. Change is deployed (manually or automatically via GitOps)
kubectl apply -f k8s/deployments/api-deployment.yaml
```

Every change has:
- A commit message explaining WHY
- A PR where it was reviewed
- A complete audit trail

---

## `kubectl apply` vs. `kubectl create`

Two ways to apply Kubernetes config from files:

```bash
# apply: create if missing, update if exists (idempotent ✅)
kubectl apply -f k8s/

# create: only creates, fails if resource already exists ❌
kubectl create -f k8s/
```

**Always use `apply` for Git-managed configs.** It's idempotent — you can run it over and over safely.

```bash
# Apply everything in the k8s/ folder
kubectl apply -f k8s/

# Apply recursively (subfolders too)
kubectl apply -R -f k8s/
```

---

## Tracking What's Deployed

With Git, your history IS your deployment log:

```bash
# See all changes to a specific file over time
git log --oneline k8s/deployments/api-deployment.yaml

# See exactly what changed in a commit
git show abc1234

# See who last changed what line in a file
git blame k8s/deployments/api-deployment.yaml

# Compare current config to 1 week ago
git diff HEAD~7 k8s/deployments/api-deployment.yaml
```

---

## Rolling Back with Git

Deployed a bad config? Roll back by reverting the commit:

```bash
# Find the last good commit
git log --oneline k8s/deployments/api-deployment.yaml

# Revert to that state
git revert abc1234

# Or check out just the old version of a file
git checkout abc1234 -- k8s/deployments/api-deployment.yaml

# Apply the rollback
kubectl apply -f k8s/deployments/api-deployment.yaml
```

Git becomes your Kubernetes time machine.

---

## 🧪 Try It Yourself

```bash
# Clone the class repo
git clone https://github.com/emage-tech/kubernetes-january-2026-cohort.git
cd kubernetes-january-2026-cohort

# See all the lab files
ls class-materials/labs/

# Look at a lab's YAML
cat class-materials/labs/lab-11-architecture/namespace.yaml

# See the full commit history
git log --oneline

# See what changed in the most recent commit
git show HEAD
```

---

## ✅ What You Learned

- Kubernetes config (YAML) belongs in Git — just like application code
- Every change has a commit message, a PR, and an audit trail
- `kubectl apply` is idempotent — safe to run repeatedly from Git
- `git log`, `git show`, and `git blame` help you understand what changed and why
- Rolling back a bad deploy = reverting or checking out an old Git commit

**Next:** [GitOps — Git as the Source of Truth for Your Cluster →](07-gitops.md)
