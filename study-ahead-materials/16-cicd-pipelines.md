# CI/CD Pipelines for Kubernetes

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Why This Matters

Kubernetes is a powerful platform, but it's only valuable if you can reliably deliver software to it. CI/CD pipelines are the engine that takes code from a developer's commit to a running workload in production — automatically, consistently, and safely. In modern cloud-native environments, the pipeline is as important as the application itself.

Session 29 builds on everything you've learned — containers, Helm, Kubernetes, and ArgoCD — to show how these pieces connect into a complete delivery system. Understanding GitOps-driven deployments, image promotion strategies, and how to securely inject secrets into pipelines is essential for anyone operating Kubernetes in production.

---

## 🎥 YouTube Videos

### GitHub Actions CI/CD for Kubernetes
[![Thumbnail](https://img.youtube.com/vi/R8_veQiYBjI/0.jpg)](https://www.youtube.com/watch?v=R8_veQiYBjI)
**Channel:** TechWorld with Nana
> End-to-end walkthrough of a GitHub Actions pipeline that builds a Docker image, pushes to a registry, and triggers a Kubernetes deployment.

### GitOps with ArgoCD and GitHub Actions
[![Thumbnail](https://img.youtube.com/vi/MeU5_k9ssrs/0.jpg)](https://www.youtube.com/watch?v=MeU5_k9ssrs)
**Channel:** TechWorld with Nana
> How CI and CD separate responsibilities: CI builds and pushes images, ArgoCD (CD) detects manifest changes and syncs to Kubernetes.

### Workload Identity Federation (keyless auth to GCP)
[![Thumbnail](https://img.youtube.com/vi/ZgVhU5qvK1M/0.jpg)](https://www.youtube.com/watch?v=ZgVhU5qvK1M)
**Channel:** Google Cloud
> How to authenticate from GitHub Actions to Google Cloud without storing long-lived service account keys, using OIDC tokens.

### DORA Metrics and DevOps Performance
[![Thumbnail](https://img.youtube.com/vi/RX5rtas3gvg/0.jpg)](https://www.youtube.com/watch?v=RX5rtas3gvg)
**Channel:** Google Cloud Tech
> The four key metrics (deployment frequency, lead time, change failure rate, MTTR) that measure CI/CD pipeline health.

---

## 📚 Articles & Documentation

### GitHub Actions Documentation
🔗 [GitHub Actions](https://docs.github.com/en/actions)
**Source:** GitHub | **Level:** Beginner-Intermediate
> Complete reference for GitHub Actions — workflows, jobs, steps, actions, secrets, environments, and deployment approvals.

### Google Cloud Build Documentation
🔗 [Cloud Build](https://cloud.google.com/build/docs)
**Source:** Google Cloud | **Level:** Intermediate
> Google's managed CI/CD platform — tight integration with GKE, Artifact Registry, and Cloud Deploy.

### OpenID Connect in GitHub Actions
🔗 [OIDC with GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
**Source:** GitHub | **Level:** Intermediate
> How to use short-lived OIDC tokens to authenticate to cloud providers without storing credentials as secrets.

### ArgoCD Image Updater
🔗 [ArgoCD Image Updater](https://argocd-image-updater.readthedocs.io/)
**Source:** ArgoCD Project | **Level:** Intermediate
> Automates updating Kubernetes manifests when new container images are pushed to a registry — the final link in a GitOps pipeline.

### Google Cloud Deploy
🔗 [Cloud Deploy](https://cloud.google.com/deploy/docs)
**Source:** Google Cloud | **Level:** Intermediate
> Managed continuous delivery to GKE with built-in promotion pipelines, canary support, and approval gates.

---

## Key Concepts

### The CI/CD Pipeline Anatomy

A modern Kubernetes delivery pipeline has two distinct phases:

**Continuous Integration (CI)**: Triggered by a code push. Responsibilities:
1. Run tests (unit, integration, linting)
2. Build the container image
3. Scan the image for vulnerabilities
4. Push the image to a registry with a tagged version
5. Update the Kubernetes manifest (or Helm values) with the new image tag
6. Commit the manifest change to a Git repository

**Continuous Delivery/Deployment (CD)**: Triggered by a manifest change in Git. Responsibilities:
1. Detect the change in the Git repo (ArgoCD watches this)
2. Sync the desired state from Git to the cluster
3. Run health checks and smoke tests
4. Promote to next environment if passing

The key insight: **CI owns the image, CD owns the deployment**. They communicate via Git — a manifest change is the handshake.

### Building Container Images in CI

**GitHub Actions** example:
```yaml
name: Build and Push

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write    # needed for OIDC

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: "projects/123/locations/global/workloadIdentityPools/github-pool/providers/github"
          service_account: "cicd@my-project.iam.gserviceaccount.com"

      - name: Configure Docker for Artifact Registry
        run: gcloud auth configure-docker us-central1-docker.pkg.dev

      - name: Build and Push
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: |
            us-central1-docker.pkg.dev/my-project/my-repo/myapp:${{ github.sha }}
            us-central1-docker.pkg.dev/my-project/my-repo/myapp:latest
          cache-from: type=registry,ref=us-central1-docker.pkg.dev/my-project/my-repo/myapp:cache
          cache-to: type=registry,ref=us-central1-docker.pkg.dev/my-project/my-repo/myapp:cache,mode=max
```

**Image tagging strategies**:
- `git-sha` (`abc123f`) — unique, immutable, traceable to commit ✅
- `semver` (`v1.2.3`) — human-readable versions for releases
- `branch-sha` (`main-abc123`) — branch context + uniqueness
- `latest` — avoid in production manifests (mutable, no traceability)

### GitOps Pipeline Pattern

```
Developer pushes code
        │
        ▼
┌───────────────────┐
│  CI Pipeline      │
│  (GitHub Actions) │
│  1. Test          │
│  2. Build image   │
│  3. Scan image    │
│  4. Push to reg.  │
│  5. Update values │
│     in git repo   │
└────────┬──────────┘
         │ git commit (image tag update)
         ▼
┌───────────────────┐
│  GitOps Repo      │
│  (Helm values /   │
│   K8s manifests)  │
└────────┬──────────┘
         │ ArgoCD watches for changes
         ▼
┌───────────────────┐
│  ArgoCD (CD)      │
│  Detects diff     │
│  Syncs to cluster │
│  Health checks    │
└───────────────────┘
```

**Updating the manifest in CI** (the handshake):
```bash
# In the CI pipeline, after pushing the image:
yq e ".image.tag = "$IMAGE_TAG"" -i helm/myapp/values.yaml
git commit -am "ci: bump image to $IMAGE_TAG [skip ci]"
git push
```

### Environment Promotion Strategies

**Three-environment model**: dev → staging → production

| Environment | Trigger | Approval |
|-------------|---------|----------|
| dev | Every commit to `main` | Automatic |
| staging | Every commit to `main` (after dev) | Automatic (with tests) |
| production | Release tag (`v*`) | Manual approval gate |

**In ArgoCD**: Use separate Application resources per environment, each pointing to a different values file or branch:
- `myapp-dev` → `main` branch, `values-dev.yaml`
- `myapp-staging` → `main` branch, `values-staging.yaml`
- `myapp-prod` → `release` branch, `values-prod.yaml`

**Promotion mechanism**: A "promote to production" step in CI:
```yaml
- name: Promote to Production
  if: startsWith(github.ref, 'refs/tags/v')
  run: |
    git checkout release
    yq e ".image.tag = \"$IMAGE_TAG\"" -i helm/myapp/values-prod.yaml
    git commit -am "release: promote $IMAGE_TAG to production"
    git push
```

### Secrets in Pipelines

**The problem**: Pipelines need credentials (registry passwords, cluster certs, API keys). Storing these as long-lived secrets is a security risk.

**Workload Identity Federation (GCP)**: Instead of a service account key JSON, GitHub Actions exchanges its OIDC token for a short-lived GCP access token. No long-lived credentials stored anywhere.

```
GitHub Actions OIDC token
         │
         ▼ (exchange)
GCP Workload Identity Pool
         │
         ▼ (impersonate)
Service Account (IAM permissions)
         │
         ▼
Access to GCP resources (Artifact Registry, GKE, etc.)
```

**OIDC with AWS (IRSA / GitHub OIDC Provider)**: Same concept for AWS — exchange GitHub's OIDC token for temporary AWS credentials via AssumeRoleWithWebIdentity.

**GitHub Environments**: Add deployment protection rules — require manual approval before production deployments, restrict which branches can deploy.

```yaml
deploy-production:
  environment:
    name: production    # defined in GitHub repo settings
    url: https://myapp.example.com
  needs: deploy-staging
```

### Scanning in the Pipeline

Insert image scanning between build and push:
```yaml
- name: Scan image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: "myapp:${{ github.sha }}"
    format: "table"
    exit-code: "1"           # fail the pipeline on HIGH/CRITICAL CVEs
    severity: "HIGH,CRITICAL"
```

Or use `grype` for SBOM-based scanning:
```yaml
- name: Generate SBOM
  uses: anchore/sbom-action@v0
  with:
    image: "myapp:${{ github.sha }}"

- name: Scan SBOM
  uses: anchore/scan-action@v3
  with:
    image: "myapp:${{ github.sha }}"
    fail-build: true
    severity-cutoff: high
```

---

## Key Concepts to Know Before Class

- What is the difference between CI and CD? What does each phase own?
- Describe the GitOps pipeline pattern — how do CI and ArgoCD communicate?
- What is the "manifest update" step in a CI pipeline and why is it critical for GitOps?
- What image tagging strategies exist? Which are suitable for production manifests?
- How does environment promotion work in a GitOps model?
- What is Workload Identity Federation and why is it preferred over service account keys?
- What is OIDC and how does GitHub Actions use it for cloud authentication?
- How do you integrate image scanning (Trivy/Grype) into a CI pipeline?
- What are GitHub Environments and how do they support production deployment gates?
- What is `image.tag: latest` and why should you never use it in production?
- What is the role of ArgoCD in a GitOps pipeline (vs. a traditional push-based CD tool)?
- Name the four DORA metrics and explain why they're useful for measuring pipeline health.

---

## Hands-On Before Class (Optional)

1. **Create a GitHub Actions workflow**: Set up a workflow that builds a Docker image and pushes it to GitHub Container Registry (GHCR) on every push to `main`.
2. **Add Trivy scanning**: Add an image scan step to your pipeline. Configure it to fail on HIGH CVEs.
3. **GitOps simulation**: Create two repos — one for app code, one for manifests. Have the CI pipeline in the app repo update the manifest repo after a successful build.
4. **Explore ArgoCD Image Updater**: Install ArgoCD Image Updater locally and configure it to watch your registry for new image tags.
5. **Review a Cloud Build config**: Read through a sample `cloudbuild.yaml` and understand each step.
