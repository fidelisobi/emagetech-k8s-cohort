# 📄 Resume Guide — Kubernetes Engineer

## The Reality of Technical Resumes

Recruiters spend 6–10 seconds on a resume before deciding to read it or not.
Your job in those 6 seconds: make it obvious you can do the work.

---

## Resume Structure (in order)

```
1. Contact info + LinkedIn + GitHub
2. Technical Skills (the most scanned section)
3. Experience (reverse chronological)
4. Projects (your biggest differentiator as a bootcamp grad)
5. Education / Certifications
```

**Do NOT include:** Objectives, summaries (unless senior), references, photos, hobbies (unless directly relevant)

---

## Technical Skills Section

Group by category. Be specific — "Kubernetes" alone means nothing. Show depth.

```
Container Orchestration: Kubernetes (GKE, EKS, AKS), Docker, containerd, K3s
GitOps & CI/CD:          ArgoCD, GitHub Actions, Flux, Jenkins
Infrastructure as Code:  Terraform, Helm, Kustomize
Observability:           Prometheus, Grafana, Loki, AlertManager, OpenTelemetry
Security:                Kyverno, NeuVector, Sealed Secrets, Cosign, Falco, RBAC
Networking:              Ingress-NGINX, Istio, Cilium, Network Policies, Gateway API
Cloud:                   GCP (GKE, Cloud Build, Artifact Registry), AWS (EKS, ECR, IAM), Azure (AKS)
Languages:               Python, Bash, Go (basic), YAML, HCL
```

---

## Writing Bullet Points That Get Interviews

**Bad (task-focused):**
> Managed Kubernetes clusters

**Good (impact-focused):**
> Migrated 12 microservices from EC2 to GKE, reducing infrastructure costs by 34% and deployment time from 45 minutes to under 8 minutes using ArgoCD GitOps pipelines

**Formula:**
```
[Action verb] + [what you did] + [scale/context] + [measurable outcome]
```

**Action verbs for K8s roles:**
Architected, Deployed, Automated, Migrated, Reduced, Implemented, Enforced, Hardened, Integrated, Optimized, Designed, Built, Scaled, Monitored, Resolved

---

## How to Write About This Cohort's Projects

Even as a student project, frame it professionally:

**Project 1 (Containerize Multi-Tier App):**
> Containerized a multi-tier Node.js/PostgreSQL application using Docker; deployed to Kubernetes with Deployments, Services, ConfigMaps, and Secrets; achieved zero-downtime updates via rolling deployment strategy

**Project 8 (Observability Stack):**
> Built end-to-end observability platform (Prometheus, Grafana, Loki, AlertManager) on Kubernetes; created custom dashboards for CPU, memory, and error-rate tracking; configured PagerDuty-style alerting rules

**Project 11 (NeuVector):**
> Improved cluster security posture from 35% to 92% using NeuVector runtime security; wrote NetworkPolicies covering all Pod-to-Pod traffic; documented findings in a security hardening runbook

**Project 15 (Capstone):**
> Architected a production-grade Kubernetes platform from scratch: multi-namespace RBAC model, GitOps pipeline via ArgoCD, Helm-packaged microservices, Sealed Secrets for credential management, and Prometheus/Grafana observability stack

---

## Certifications Worth Getting

These signal credibility to hiring managers:

| Cert | Difficulty | Value | Recommended? |
|------|-----------|-------|-------------|
| **CKA** (Certified Kubernetes Administrator) | Medium | Very High | ✅ Yes — do this first |
| **CKAD** (Certified Kubernetes App Developer) | Medium | High | ✅ Yes |
| **CKS** (Certified Kubernetes Security Specialist) | Hard | Very High | ✅ After CKA |
| **KCNA** (Kubernetes Cloud Native Associate) | Easy | Medium | Optional warmup |
| **AWS/GCP/Azure** certifications | Varies | High | ✅ Pair with K8s |

**CKA tip:** The exam is hands-on in a live cluster. Everything you do in these labs IS your CKA practice. Do the labs with the docs closed first, then check.

---

## Resume Red Flags to Avoid

- ❌ Listing technologies you can't talk about in an interview
- ❌ "Familiar with Kubernetes" — either you know it or you don't
- ❌ Resume longer than 2 pages (1 page if < 5 years experience)
- ❌ Generic bullet points ("responsible for..."), "worked on team...")
- ❌ No GitHub link — every K8s role will check your repos
- ❌ Spelling/grammar errors — signals carelessness in production work

---

## GitHub Profile Tips

Hiring managers WILL check your GitHub. Make it count:

1. **Pin your best repos** — pin the cohort fork and your capstone project
2. **Write a README for every project** — if there's no README, they can't evaluate it
3. **Commit consistently** — your contribution graph matters; green squares = active practitioner
4. **Use descriptive commit messages** — interviewers DO read commit history
5. **Add a profile README** — `github.com/username` → create repo `username/username` with a README.md

---

## Quick Action Checklist

- [ ] Technical skills section is specific and grouped by category
- [ ] Every bullet point has an action verb + context + outcome
- [ ] Projects section describes all 15 cohort projects (pick best 4–6)
- [ ] GitHub profile is public with pinned repos
- [ ] Each pinned repo has a README
- [ ] LinkedIn matches resume (recruiters cross-check)
- [ ] CKA study plan started
