# Lab 29 — CI/CD Pipeline

## Overview

In this lab you will explore the Cloud Build CI/CD pipeline for the `cluster-dreams`
project and understand how a container moves from source code to a running pod.

You will:

1. Review the existing production pipeline in `/Users/alade/class/gke/cicd/`
2. Walk through the build → scan → push → deploy flow
3. Submit a test build using the lab pipeline
4. Monitor build logs in real time
5. Understand how CI/CD connects to GitOps (ArgoCD)

**Time estimate:** 45–60 minutes

---

## Prerequisites

- gcloud CLI authenticated: `gcloud auth list`
- Project set to `cluster-dreams`: `gcloud config get-value project`
- Cloud Build API enabled

### Verify your setup

```bash
# Check authentication
gcloud auth list
# Expected: your account listed as ACTIVE

# Check project
gcloud config get-value project
# Expected: cluster-dreams

# Check Cloud Build is accessible
gcloud builds list --limit=5
# Expected: list of recent builds (or empty if no builds yet)
```

---

## Part A — Review the Production Pipeline

### Step A1 — Examine the pipeline files

The CI/CD pipelines live in `/Users/alade/class/gke/cicd/`. Review each file and
understand its purpose:

```bash
ls -la /Users/alade/class/gke/cicd/
```

| File | Trigger | Purpose |
|---|---|---|
| `cloudbuild.yaml` | Merge to `main` | Plan + Apply all Terraform workspaces |
| `cloudbuild-plan.yaml` | Pull Request | Plan only — shows what will change |
| `cloudbuild-test.yaml` | Manual / development | Runs tests without applying |
| `cloudbuild-destroy.yaml` | Scheduled 2 AM EST | Destroys the cluster (cost saving) |
| `cloudbuild-create.yaml` | Scheduled 10 AM EST | Recreates the cluster |

### Step A2 — Read the main pipeline

```bash
cat /Users/alade/class/gke/cicd/cloudbuild.yaml
```

Identify the following in the YAML:

1. **Steps** — what each step does and which image it uses
2. **waitFor** — the dependency graph between steps (which steps run in parallel vs. sequence)
3. **substitutions** — variables that can be overridden at submit time
4. **timeout** — per-step and total pipeline timeouts
5. **secrets** — how secrets are injected from Secret Manager (not hardcoded)

### Step A3 — Understand the step dependency graph

Draw the execution order for `cloudbuild.yaml`:

```
environment-info
       │
trivy-fs-scan ──┐
trivy-config-scan ── (all 3 run in parallel from environment-info)
checkov-scan ──┘
       │
security-report
       │
plan-all
       │
summarize-all
       │
apply-all
       │
build-summary
```

> **Discussion:** Why do security scans run BEFORE the Terraform plan?
> What would happen if a critical vulnerability was found after the plan was generated?

---

## Part B — Review the Lab Pipeline

### Step B1 — Read the lab pipeline file

```bash
cat 01-cloudbuild-sample.yaml
```

This pipeline has 6 steps for a container build workflow:

```
environment-info
       │
     build          ← Docker image build (Kaniko)
       │
  trivy-scan        ← Container security scan
       │
 push-verified      ← Confirmation + instructions
       │
    summary         ← Final status report
```

### Step B2 — Key differences from the infrastructure pipeline

| Concern | Infrastructure pipeline | Container pipeline |
|---|---|---|
| What it deploys | Terraform (infrastructure) | Docker image → Kubernetes |
| Security scanning | Filesystem + IaC scanning | Container image CVE scanning |
| State management | Terraform state in GCS | Image tags in Artifact Registry |
| GitOps trigger | Runs `terraform apply` directly | Updates Git manifest → ArgoCD syncs |

---

## Part C — Submit a Test Build

### Step C1 — Load the lab aliases

```bash
source /Users/alade/class/gke/scripts/gcloud-aliases.sh
gcloud-health-check
```

### Step C2 — Create a simple Dockerfile for the test build

In the lab directory, create a minimal Dockerfile:

```bash
cat > /tmp/lab-dockerfile/Dockerfile << 'EOF'
FROM nginx:1.25-alpine

# Copy a simple HTML page
COPY index.html /usr/share/nginx/html/index.html

# Add a /metrics endpoint stub for Prometheus (returns empty metrics)
RUN echo '# student-app metrics' > /usr/share/nginx/html/metrics

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:80/health || exit 1
EOF

echo '<h1>Hello from student-app!</h1><p>Build: '"${SHORT_SHA:-local}"'</p>' \
  > /tmp/lab-dockerfile/index.html
```

### Step C3 — Submit the build

```bash
# Submit the lab pipeline against the test Dockerfile directory
gcloud builds submit \
  --config=01-cloudbuild-sample.yaml \
  /tmp/lab-dockerfile \
  --substitutions=SHORT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
```

Or using the alias:

```bash
gcb-submit
```

### Step C4 — Submit with streaming logs

To see logs in real time as the build runs:

```bash
gcloud builds submit \
  --config=01-cloudbuild-sample.yaml \
  /tmp/lab-dockerfile \
  --substitutions=SHORT_SHA=lab-test-001
```

> The `--stream` flag is not needed with `gcb-stream` alias — it streams by default.

---

## Part D — Monitor Build Logs

### Step D1 — List recent builds

```bash
gcloud builds list --limit=10
# OR using alias:
gcb-list
```

Output shows:
- Build ID (UUID)
- Status (WORKING, SUCCESS, FAILURE, CANCELLED)
- Source (where the code came from)
- Create time
- Duration

### Step D2 — Get detailed build status

```bash
# Replace BUILD_ID with the actual ID from Step D1
gcloud builds describe BUILD_ID
# OR using alias:
gcb-status BUILD_ID
```

This shows:
- Complete step-by-step timing
- Resource usage (CPU, memory)
- Substitution values used
- Artifact locations (if configured)

### Step D3 — View build logs

```bash
# Stream logs for a running build
gcloud builds log --stream BUILD_ID
# OR using alias:
gcb-logs BUILD_ID
```

### Step D4 — Find logs in Cloud Console

1. Go to: https://console.cloud.google.com/cloud-build/builds?project=cluster-dreams
2. Click a build to see the step-by-step log with timing
3. Click individual steps to expand their logs

> **Tip:** The Cloud Console UI is much easier to navigate for large builds with many steps.

---

## Part E — Understanding the GitOps Connection

This section explains conceptually how CI/CD connects to ArgoCD. No commands to run.

### The full flow

```
Developer pushes code to Git
          │
          ▼
Cloud Build trigger fires (PR or merge)
          │
          ▼
Cloud Build: build → scan → push image to Artifact Registry
          │
          ▼
Cloud Build: update image tag in MANIFESTS repo
  (modify the "image:" field in deployment.yaml)
  (commit: "chore: update student-app image to abc1234")
          │
          ▼
ArgoCD detects Git change in manifests repo
          │
          ▼
ArgoCD syncs: applies new Deployment with new image tag
          │
          ▼
Kubernetes rolling-updates pods to the new image
```

### Why separate code repo from manifests repo?

- **Separation of concerns:** Code changes trigger CI; manifest changes trigger CD
- **Audit trail:** Every deployment is a Git commit — who changed what, when, and why
- **Rollback:** Roll back a deployment by reverting a Git commit (not `kubectl rollout undo`)
- **Multi-environment:** The same image can be promoted across dev → staging → production
  by updating the manifest in each environment's branch or directory

### How ArgoCD gets notified

ArgoCD polls Git repositories every 3 minutes by default. For faster syncs, configure
a webhook from GitHub/GitLab to ArgoCD so it syncs within seconds of a commit:

```bash
# Get the ArgoCD webhook URL
kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
# Configure webhook in GitHub: https://<argocd-ip>/api/webhook
```

---

## Part F — Pipeline Best Practices Discussion

Review these patterns in the production pipeline and discuss why they matter:

### Immutable image tags

```yaml
# BAD: mutable tag — you can never know exactly what's running
image: student-app:latest

# GOOD: immutable SHA tag — exact version is always traceable
image: us-central1-docker.pkg.dev/cluster-dreams/student-app:abc1234f
```

### Secrets from Secret Manager (never in YAML)

```yaml
# BAD: secret hardcoded in pipeline
- name: gcr.io/cloud-builders/docker
  args: ['login', '--password', 'my-secret-password']

# GOOD: injected from Secret Manager at runtime
secretEnv:
  - MY_SECRET
availableSecrets:
  secretManager:
    - versionName: projects/$PROJECT_ID/secrets/my-secret/versions/latest
      env: MY_SECRET
```

### Fail fast on security issues

```yaml
# Scan BEFORE push — a failing scan prevents the image from reaching the registry
# and therefore from ever being deployed to production
```

### Per-step timeouts

```yaml
# Each step has its own timeout so a hung step doesn't consume the full build budget
timeout: 300s   # 5 minutes for this step
```

---

## Discussion Questions

1. What is the difference between Continuous Integration (CI) and Continuous Delivery (CD)?
   Which parts of this pipeline are CI and which are CD?
2. Why is it important to scan the container image BEFORE pushing to the registry,
   rather than scanning images already in production?
3. In the GitOps model, how do you handle a hotfix that needs to bypass the normal
   PR → review → merge cycle?
4. What would you add to this pipeline for a production-grade deployment? Consider:
   - Integration tests
   - Smoke tests after deployment
   - Notifications (Slack, PagerDuty)
   - Deployment tracking (DORA metrics)
5. How would you manage different configurations for dev, staging, and production
   in a GitOps pipeline?

---

## Key Concepts

| Concept | Description |
|---|---|
| Cloud Build trigger | Automatically starts a build on Git events (push, PR) |
| Kaniko | Rootless Docker image builder — safer than Docker-in-Docker in CI |
| Trivy | Open-source vulnerability scanner for containers and IaC |
| Artifact Registry | Google's managed container registry (successor to Container Registry) |
| Immutable tag | Image tag that never changes (SHA-based) — ensures reproducibility |
| GitOps | Git as the single source of truth for both code AND infrastructure state |
| App of Apps | Pattern for managing multiple ArgoCD Applications via a parent Application |
| DORA metrics | Deployment Frequency, Lead Time, MTTR, Change Failure Rate — CI/CD health KPIs |
