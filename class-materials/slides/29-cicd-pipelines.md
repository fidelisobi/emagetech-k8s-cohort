# Session 29 — CI/CD Pipelines for Kubernetes

---

## CI/CD Overview

CI/CD bridges the gap between code changes and production deployments.

**Continuous Integration (CI):**
- Build, test, scan, and package applications into container images
- Triggered by: code commits, pull requests

**Continuous Delivery/Deployment (CD):**
- Deploy applications to Kubernetes clusters
- CD tool: ArgoCD (GitOps — covered in Session 26)

---

## CI/CD Analogy

> The kitchen (CI) prepares the dish and hands it to the waiter (ArgoCD) who delivers it — the kitchen doesn't walk into the dining room itself.

CI's job ends at the pass-through window: build, test, scan, push the image, and update the manifest in Git. ArgoCD's job begins there: pick up what is on the shelf (Git) and deliver it to the right table (cluster). Mixing these concerns — for example, having a CI job run `kubectl apply` — breaks the clean separation of duties and loses the auditability that GitOps provides.

---

## The GitOps CI/CD Model

```
Code Repo                              Manifest Repo
   │                                       │
   ▼                                       ▼
CI Pipeline                          ArgoCD (CD)
   │                                       │
   ├── Build image                         ├── Watches manifest repo
   ├── Run tests                           ├── Detects changes
   ├── Scan image (Trivy)                  ├── Syncs to cluster
   ├── Push to registry                    └── Reconciles desired state
   └── Update manifest repo
       (image tag)
```

**Key Principle:** CI and CD are separate concerns.
- CI should **NEVER** `kubectl apply` directly to the cluster
- CI updates Git (manifests) → ArgoCD handles deployment

---

## Pipeline Stages

### Stage 1: Build
- Build container image using Dockerfile or Buildpacks
- Tag with: git SHA, semver, branch name
- **Avoid `:latest`** — not reproducible

### Stage 2: Test
- Unit tests, integration tests, contract tests
- Run inside containers for consistency

### Stage 3: Scan
- Image vulnerability scan (Trivy)
- IaC scan (Checkov) for Terraform/Helm/K8s manifests
- **Fail pipeline on CRITICAL findings**

### Stage 4: Push
- Push image to container registry (Artifact Registry, ECR, ACR)
- Sign image with cosign (optional but recommended)

### Stage 5: Update Manifests
- Update image tag in Helm `values.yaml` or Kustomize overlay
- Commit to GitOps manifest repo
- ArgoCD detects the change and deploys

---

## CI Tools for Kubernetes

### GitHub Actions
- Native CI/CD for GitHub repos
- Extensive marketplace of actions for Docker, Helm, Trivy, cosign
- OIDC integration for keyless auth to cloud providers

### Google Cloud Build
- Serverless CI/CD on GCP
- `cloudbuild.yaml` defines build steps as container executions
- Native integration with GKE, Artifact Registry, Secret Manager

### Azure Pipelines
- CI/CD for Azure DevOps
- Template-based pipelines, integrates with AKS

### GitLab CI
- Built-in CI/CD with GitLab repos
- Auto DevOps feature for K8s deployments

**Common pattern:** All of these build & push — ArgoCD deploys.

---

## Example: GitHub Actions Workflow

A complete workflow: build, scan with Trivy, push to Artifact Registry, then update the GitOps manifest repo with the new image tag.

```yaml
# .github/workflows/ci.yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

env:
  REGISTRY: us-docker.pkg.dev/my-project/my-repo
  IMAGE_NAME: my-app

jobs:
  build-scan-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write     # required for OIDC keyless auth to GCP

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      # Authenticate to GCP using OIDC — no static service account keys
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: projects/123456/locations/global/workloadIdentityPools/github/providers/github
          service_account: ci-runner@my-project.iam.gserviceaccount.com

      - name: Configure Docker for Artifact Registry
        run: gcloud auth configure-docker us-docker.pkg.dev

      - name: Build image
        run: |
          docker build -t $REGISTRY/$IMAGE_NAME:${{ github.sha }} .

      # Scan for CRITICAL and HIGH CVEs — fail fast before pushing
      - name: Scan image with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          format: table
          exit-code: 1
          severity: CRITICAL,HIGH
          ignore-unfixed: true

      - name: Push image
        run: |
          docker push $REGISTRY/$IMAGE_NAME:${{ github.sha }}

      # Update the GitOps manifest repo so ArgoCD picks up the new tag
      - name: Update manifest repo
        env:
          MANIFEST_REPO: my-org/my-gitops-manifests
          GIT_TOKEN: ${{ secrets.MANIFEST_REPO_TOKEN }}
        run: |
          git clone https://x-access-token:${GIT_TOKEN}@github.com/${MANIFEST_REPO}.git manifests
          cd manifests
          # Use yq for reliable YAML editing (see note below)
          yq e ".image.tag = \"${{ github.sha }}\"" -i apps/my-app/values.yaml
          git config user.email "ci@my-org.com"
          git config user.name "CI Bot"
          git add apps/my-app/values.yaml
          git commit -m "deploy: my-app:${{ github.sha }}"
          git push
```

---

## Environment Promotion

**Environments:** dev → staging → production

### Image Promotion (recommended)
- Same image artifact promoted through environments
- Different config per environment (Helm values, Kustomize overlays)
- Ensures what you tested is exactly what you deploy

### Git Branch Promotion
- Feature branch → dev
- Main → staging
- Release tag → production
- ArgoCD tracks different branches per environment by setting a different `targetRevision` on each Application resource

> **Note:** Git Branch Promotion requires a separate ArgoCD `Application` resource per environment. Each Application specifies its own `targetRevision` (e.g., `dev`, `main`, `v1.2.0`) pointing to the same repository but a different branch or tag. A single Application cannot track multiple branches simultaneously.

### Pull Request Promotion
- PR to promote manifests from staging to production
- Provides review and approval gate before production changes

---

## Updating Image Tags: Prefer yq or kustomize

In CI pipelines, updating a YAML value with `sed` is fragile — it matches raw text, not YAML structure, and silently succeeds even if the key name changes.

**Avoid:**
```bash
# Fragile: matches any line containing "image:", including comments
sed -i "s|image:.*|image: myregistry/myapp:$SHA|" k8s/values.yaml
```

**Prefer yq (in-place YAML editing, structure-aware):**
```bash
yq e '.image.tag = "'$SHA'"' -i apps/my-app/values.yaml
```

**Prefer kustomize (for Kustomize overlays):**
```bash
cd overlays/dev
kustomize edit set image myapp=myregistry/myapp:$SHA
# This writes a structured `images:` block in kustomization.yaml — no text matching
```

Both approaches are idempotent and safe to run in automated pipelines. `kustomize edit set image` is especially useful when you manage multiple overlays sharing the same image.

---

## Secrets in Pipelines

**Problem:** CI pipelines need credentials to push images, update repos, etc.
**Old approach:** Static service account keys stored as CI secrets — insecure.

**Solution: Workload Identity Federation / OIDC**
- Cloud provider authenticates CI runner via identity token
- No static credentials stored anywhere
- Supported by: GitHub Actions, GitLab CI, Cloud Build

```yaml
# GitHub Actions example - authenticate to GCP
- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: projects/.../providers/github
    service_account: ci-runner@project.iam.gserviceaccount.com
```

---

## Example: End-to-End Pipeline (Cloud Build)

```yaml
# cloudbuild.yaml (Google Cloud Build)
steps:
  # Build
  - name: gcr.io/cloud-builders/docker
    args: ['build', '-t', 'REGION-docker.pkg.dev/PROJECT/REPO/APP:$SHORT_SHA', '.']

  # Scan
  - name: aquasec/trivy
    args: ['image', '--exit-code', '1', '--severity', 'CRITICAL,HIGH',
           'REGION-docker.pkg.dev/PROJECT/REPO/APP:$SHORT_SHA']

  # Push
  - name: gcr.io/cloud-builders/docker
    args: ['push', 'REGION-docker.pkg.dev/PROJECT/REPO/APP:$SHORT_SHA']

  # Update GitOps manifest
  # NOTE: Use yq or kustomize instead of sed for production pipelines.
  # sed matches raw text and can silently corrupt YAML if the file structure changes.
  # Example with yq:
  #   yq e '.image.tag = "'$SHORT_SHA'"' -i k8s/values.yaml
  # Example with kustomize:
  #   kustomize edit set image APP=REGION-docker.pkg.dev/PROJECT/REPO/APP:$SHORT_SHA
  - name: mikefarah/yq
    entrypoint: sh
    args:
      - -c
      - |
        yq e '.image.tag = "'$SHORT_SHA'"' -i k8s/values.yaml
  - name: gcr.io/cloud-builders/git
    entrypoint: sh
    args:
      - -c
      - |
        git add k8s/values.yaml
        git commit -m "deploy: APP:$SHORT_SHA"
        git push
```

ArgoCD detects the commit → syncs to cluster → deployment complete.

---

## Key Takeaways

1. **CI builds and packages; ArgoCD deploys** — never let a CI job run `kubectl apply`; keep the separation clean so every deployment is traceable to a Git commit.
2. **Tag images with the git SHA** — `:latest` is not reproducible and makes rollback impossible; a git SHA ties the image back to an exact point in source history.
3. **Scan before you push** — running Trivy after the image is in the registry is too late; scan in CI before the push step and fail the build on CRITICAL/HIGH findings.
4. **Use yq or kustomize to update manifests** — `sed` is brittle for YAML manipulation; structure-aware tools prevent silent failures and merge conflicts.
5. **Workload Identity / OIDC eliminates static keys** — never store long-lived cloud credentials in CI secrets; use short-lived OIDC tokens federated to your cloud provider.
6. **Git Branch Promotion needs separate Application resources** — each environment requires its own ArgoCD Application with a distinct `targetRevision`; one Application cannot track multiple branches.

---

## Review Questions

### Beginner

1. What is the difference between Continuous Integration (CI) and Continuous Delivery/Deployment (CD)? Which tool covered in this session handles each role?
2. Why should a CI pipeline never run `kubectl apply` directly, even if it has the credentials to do so?
3. What problem does tagging images with the git SHA solve compared to using the `:latest` tag?
4. What is Workload Identity Federation, and why is it preferred over storing static service account keys in CI secrets?
5. At which stage in the pipeline should you run Trivy, and what should happen to the pipeline if a CRITICAL vulnerability is found?

### Intermediate

1. A teammate proposes updating the image tag in `values.yaml` using `sed -i "s|tag:.*|tag: $SHA|"` in the CI pipeline. What specific failure modes does this approach introduce, and what would you recommend instead?
2. Your team uses a single GitOps repository and wants to promote the same image artifact from dev to staging to production. Describe the pipeline steps and ArgoCD configuration changes needed to implement image promotion safely, including the approval gate before production.
3. You are setting up a new GitHub Actions pipeline to build and push images to Google Artifact Registry. A security review flags that the pipeline currently uses a downloaded JSON service account key. Explain how you would redesign the authentication step using OIDC, and what GCP-side configuration is required to make it work.
