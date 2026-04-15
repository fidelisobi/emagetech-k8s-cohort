# 🤝 Contributing to This Repository

Welcome! Contributions from TAs, students, and instructors make this repo better for everyone.
This guide explains how to contribute — please read it before opening a PR.

---

## Who Can Contribute?

| Role | Can contribute to |
|------|------------------|
| **Students** | Fixing typos/bugs in labs, adding notes, submitting projects |
| **TAs** | All student areas + `class-materials/`, `network-fundamentals/`, `git-fundamentals/` |
| **Instructors** | Everything |

> **Note:** `class-materials/curriculum.md` and `class-materials/slides/` require instructor approval (CODEOWNERS enforced).

---

## Before You Start

1. Make sure you have the tools installed → run [`setup.sh`](./setup.sh)
2. Fork the repo (if you're a student) or clone directly (if you're a TA/instructor)
3. Read the section you're contributing to — understand the existing style before adding

---

## Branch Naming Convention

```
<type>/<short-description>
```

| Type | Use for |
|------|---------|
| `feat/` | New content (lab, tutorial, project) |
| `fix/` | Correcting a bug, broken command, wrong output |
| `docs/` | README updates, typos, formatting |
| `chore/` | CI, tooling, structure changes |

**Examples:**
```
feat/add-lab-17-network-policy-solution
fix/broken-hpa-yaml-in-project-04
docs/update-project-readme-links
chore/add-gitignore
```

---

## Step-by-Step: How to Submit a Change

```bash
# 1. Fork (students) or clone (TAs/instructors)
git clone https://github.com/emage-tech/kubernetes-january-2026-cohort.git
cd kubernetes-january-2026-cohort

# 2. Create a branch
git checkout -b fix/broken-yaml-lab-14

# 3. Make your changes
# ... edit files ...

# 4. Validate any YAML you changed
kubectl apply --dry-run=client -f path/to/file.yaml

# 5. Commit with a clear message (see below)
git add .
git commit -m "fix(lab-14): correct liveness probe path in deployment.yaml"

# 6. Push
git push origin fix/broken-yaml-lab-14

# 7. Open a Pull Request on GitHub
# Fill out the PR template fully — especially the checklist
```

---

## Commit Message Format

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short description>

[optional body — what and WHY, not just what]
[optional footer — Fixes #issue]
```

**Types:** `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`

**Examples:**
```
feat(projects): add project 06 Helm chart authoring README
fix(lab-22): kubectl debug command uses wrong container flag in step 4
docs(network-fundamentals): add missing DNS record type table
chore(ci): add kubeconform YAML validation workflow
```

---

## YAML Standards

All Kubernetes YAML files must:

- [ ] Pass `kubectl apply --dry-run=client` without errors
- [ ] Include `metadata.labels` with at minimum `app: <name>`
- [ ] Include resource `requests` and `limits` on all containers
- [ ] Not use `latest` image tags — pin to a specific version
- [ ] Include comments explaining non-obvious fields

**Example of a well-written manifest:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  labels:
    app: my-app          # required label
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-app
          image: nginx:1.25.4     # pinned version — never use :latest
          resources:
            requests:
              cpu: 100m           # minimum guaranteed CPU
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
```

---

## Markdown Standards

- Use sentence case for headings (not Title Case For Everything)
- Code blocks must specify the language: ` ```bash `, ` ```yaml `, ` ```json `
- Every new file needs to fit the existing style of its section
- Links must use relative paths for files in this repo
- Test all links before submitting

---

## Review Process

1. Open PR → automated CI runs (YAML lint, link check, auto-label)
2. A TA or instructor reviews within **48 hours**
3. Address any requested changes
4. Once approved → merged by a TA/instructor

PRs that fail CI will not be reviewed until CI passes.

---

## Questions?

Drop a message in the `#kubernetes-january-2026-cohort` Slack channel and tag a TA.
