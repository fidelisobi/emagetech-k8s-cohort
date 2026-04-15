# 🗂️ Portfolio Guide — Presenting Your Cohort Projects

## Why Your Projects Are Your Greatest Asset

Most candidates applying for Kubernetes roles have certifications.
Far fewer have **real, documented, working projects** they can demo.

Your 15 projects from this cohort ARE your portfolio. This guide shows you how to present them.

---

## GitHub Portfolio Setup

### Step 1: Create a clean GitHub profile
- Professional photo or avatar
- One-liner bio: "Kubernetes Engineer | GitOps | Cloud Native | CKA Candidate"
- Location, company (if applicable), LinkedIn link
- Pin your 6 best repos

### Step 2: Fork and personalize the cohort repo
Your fork of `emage-tech/kubernetes-january-2026-cohort` is your starting point.
Add a `progress/your-github-username.md` tracking what you've completed.

### Step 3: Create standalone project repos
For your best 3–4 projects, create separate repos:

```
github.com/yourname/k8s-observability-stack
github.com/yourname/gitops-argocd-platform
github.com/yourname/kubernetes-security-hardening
github.com/yourname/k8s-capstone-platform
```

Each repo needs:
- A detailed README (architecture diagram, what it does, how to run it, what you learned)
- Clean commit history (no "fix", "stuff", "asdf" messages)
- Working YAML/Helm charts
- Screenshots or GIFs of it running

---

## How to Write a Project README for Employers

Structure:
```
# Project Name

## What This Is
One paragraph — what you built and why it matters.

## Architecture
Mermaid or ASCII diagram showing how components connect.

## Key Technical Decisions
3–5 bullet points: why you chose X over Y, what trade-offs you considered.

## How to Deploy It
Step-by-step instructions. If they can run it themselves, that's a strong signal.

## What I Learned
Honest reflection. Shows you weren't just following instructions.

## What I'd Do Differently
Shows professional maturity. Everyone who's done real work has regrets.
```

---

## Talking About Projects in Interviews

**The STAR structure works for technical projects too:**

**Situation:** "In Project 11, I started with a cluster that had a 35% NeuVector security posture score — meaning 65% of evaluated controls were failing."

**Task:** "The goal was to understand WHY each control was failing and remediate it systematically."

**Action:** "I worked through NeuVector's compliance dashboard category by category. For network controls, I wrote NetworkPolicies for all inter-service traffic. For runtime security, I configured process profiles blocking unexpected binaries. For vulnerability management, I found 3 critical CVEs in base images and pinned to patched versions."

**Result:** "Score went from 35% to 92%. I documented everything in a runbook so the next engineer can replicate the process. I also wrote a Kyverno policy that blocks images with critical CVEs from deploying in the first place."

That answer demonstrates: technical depth, systematic thinking, documentation habits, and proactive security mindset. **That gets offers.**

---

## The "Walk Me Through Your GitHub" Moment

Many interviews end with: "I'm looking at your GitHub right now — walk me through this repo."

Prepare a 3-minute version:
1. What problem does this project solve?
2. How is it structured? (show them the folder layout)
3. Pick one interesting technical decision and explain the trade-off
4. What would you add with more time?

Practice this out loud before interviews. It feels different saying it versus thinking it.

---

## Project Presentation Priority

Order of impact for most Kubernetes roles:

| Priority | Project | Why Employers Care |
|----------|---------|-------------------|
| ⭐⭐⭐ | Project 15 (Capstone) | Shows end-to-end thinking |
| ⭐⭐⭐ | Project 8 (Observability) | Every company needs this |
| ⭐⭐⭐ | Project 5 (GitOps) | GitOps is the current standard |
| ⭐⭐ | Project 11 (NeuVector) | Security roles specifically |
| ⭐⭐ | Project 9 (Zero-downtime) | Very common interview topic |
| ⭐⭐ | Project 13 (Runbooks) | SRE / platform engineering roles |
| ⭐ | Projects 1–4 | Good for showing fundamentals |
