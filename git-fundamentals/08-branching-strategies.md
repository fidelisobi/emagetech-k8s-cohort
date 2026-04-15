# 🌲 Branching Strategies — How Real Teams Organize Work

> **Pre-req:** Read [03-branching.md](03-branching.md) and [07-gitops.md](07-gitops.md) first.

---

## Not All Teams Branch the Same Way

Different teams have different workflows. Understanding the common patterns helps you fit in fast at a new job and make smart decisions for your own projects.

Here are the three most common branching strategies, and how they connect to Kubernetes deployments.

---

## Strategy 1: Feature Branch Flow (Most Common)

**The idea:** `main` is always production-ready. All work happens in short-lived branches.

```
main (always deployable)
  │
  ├── feature/add-auth        → merged via PR → deleted
  ├── fix/crash-on-login      → merged via PR → deleted
  └── docs/update-readme      → merged via PR → deleted
```

**Rules:**
- Never commit directly to `main`
- Every change goes through a PR with at least one review
- Branches are deleted after merging
- CI runs tests on every branch

**With GitOps:** Merging to `main` triggers ArgoCD to deploy to production.

**Best for:** Most teams. Simple, easy to understand, scales well.

---

## Strategy 2: Git Flow (More Structure)

**The idea:** Separate branches for development, releases, and hotfixes.

```
main          → always matches production
develop       → integration branch for features
  │
  ├── feature/X    → merge into develop when done
  ├── feature/Y    → merge into develop when done
  │
release/1.2  → cut from develop, stabilize, then merge to main + develop
hotfix/1.1.1 → cut from main, fix, merge to main + develop
```

**With GitOps:**
- `develop` branch → deploys to staging
- `main` branch → deploys to production
- `release/x.x` branch → deploys to a release candidate environment

**Best for:** Teams with scheduled releases, longer QA cycles, multiple versions in production.

---

## Strategy 3: Trunk-Based Development (Speed-Focused)

**The idea:** Everyone commits to `main` (the "trunk") directly or via very short-lived branches (< 1 day).

```
main ← everyone pushes here frequently
  │
  └── short-lived branches (a few hours max)
```

**Feature Flags:** Half-done features are hidden behind feature flags so they can merge to `main` without breaking things.

**With GitOps:** Every merge to `main` deploys to production. Deployments happen many times a day.

**Best for:** High-velocity teams doing continuous deployment (Netflix, Google, Amazon).

---

## Commit Messages That Help Your Team

When your commits trigger deployments, your commit messages become deployment logs.

Bad:
```
git commit -m "fix"
git commit -m "stuff"
git commit -m "asdfgh"
```

Good:
```
git commit -m "Fix OOMKilled in api-deployment — increase memory limit to 512Mi"
git commit -m "Scale frontend replicas to 3 for upcoming load test"
git commit -m "Add liveness probe to backend — was causing silent restarts"
```

Good commit messages answer: **what changed, and why?**

---

## Conventional Commits — A Standard Format

Many teams use the **Conventional Commits** spec for structured messages:

```
<type>(<scope>): <short description>

[optional body]
[optional footer]
```

Types:
| Type | When to Use |
|------|------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `chore` | Maintenance (deps, CI config) |
| `refactor` | Code restructure, no behavior change |
| `test` | Adding or fixing tests |
| `ci` | CI/CD pipeline changes |

Examples:
```
feat(auth): add JWT token refresh endpoint
fix(ingress): correct TLS secret name in ingress resource
docs(readme): add local dev setup instructions
chore(deps): upgrade nginx to 1.25.4
```

Tools like **semantic-release** can automatically version and changelog your project based on these commits.

---

## Protecting Your Main Branch

In real teams, `main` is protected — you can't push directly to it.
Enforce this on GitHub:

1. Go to your repo → Settings → Branches
2. Add a branch protection rule for `main`
3. Enable:
   - ✅ Require pull request reviews before merging
   - ✅ Require status checks to pass (CI tests)
   - ✅ Require branches to be up to date before merging
   - ✅ Restrict who can push to matching branches

Now nobody (not even you) can accidentally push to `main` without a reviewed PR.

---

## CI/CD — Git Events Trigger Automation

When you push or open a PR, **CI/CD pipelines** run automatically:

```
git push origin feature/my-change
         │
         ▼
  GitHub Actions triggered
         │
         ├── Run unit tests
         ├── Build Docker image
         ├── Run `kubectl apply --dry-run` (validate YAML)
         └── Run security scan (Trivy)
         │
         ▼
  All green ✅ → PR can be merged
  Any red ❌   → PR is blocked until fixed
```

You'll set this up in Session 29 (CI/CD Pipelines).

---

## 🧪 Try It Yourself

```bash
# See branches in the class repo
git clone https://github.com/emage-tech/kubernetes-january-2026-cohort.git
cd kubernetes-january-2026-cohort
git branch -a

# See the commit graph
git log --oneline --graph --all

# See a formatted commit history
git log --oneline --since="7 days ago"
```

---

## ✅ What You Learned

- Feature Branch Flow: simple, PRs for everything, main is always deployable
- Git Flow: structured, good for scheduled releases
- Trunk-Based: fast, everyone on main, uses feature flags
- Conventional Commits: standardized message format that tools can parse
- Branch protection + CI gates = no broken code reaches production

**You've completed Git Fundamentals + the Kubernetes mapping!** 🎉

You're now ready for the class. When you work on lab exercises:
- Create a branch for your work
- Commit as you go with clear messages
- Push to your fork and open a PR when done

See the class materials → [class-materials/](../class-materials/)
