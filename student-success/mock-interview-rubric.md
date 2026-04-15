# 🎙️ Mock Interview Guide & Rubric

Every student completes at least one mock interview before applying for jobs.
No exceptions. The mock interview is how you find out what you don't know before it costs you an offer.

---

## For Students — How to Request a Mock

1. Post in `#kubernetes-january-2026-cohort`: *"I'm ready for a mock interview — @TA please schedule me"*
2. A TA will DM you to set a time (45–60 minutes on Zoom)
3. Treat it like a real interview — camera on, professional environment
4. After the session you receive written feedback within 24 hours

---

## The Mock Interview Format (60 minutes)

```
0:00 – 0:05   Introductions (simulate real interview opening)
0:05 – 0:25   Technical Questions (see question bank below)
0:25 – 0:40   Live Debugging (TA shares a broken cluster scenario)
0:40 – 0:50   System Design (one architecture question)
0:50 – 0:58   Behavioral Questions (STAR format)
0:58 – 1:00   Student asks questions (simulate real interview close)
```

---

## TA Scoring Rubric

Score each section 1–5:

| Score | Meaning |
|-------|---------|
| 5 | Excellent — could answer this in a senior interview right now |
| 4 | Good — solid answer, minor gaps |
| 3 | Adequate — got the concept, needs more depth |
| 2 | Weak — significant gaps, needs more study |
| 1 | Not ready — topic needs to be revisited from scratch |

---

## Section 1 — Technical Questions (Score 1–5 each)

### Core Concepts
- [ ] Explain the difference between a Deployment and a StatefulSet
- [ ] What happens when you run `kubectl apply -f deployment.yaml`?
- [ ] Walk me through what happens when a pod fails its liveness probe
- [ ] What is etcd and what happens if it goes down?
- [ ] Explain the Kubernetes control plane components

**Section Score: ___ / 25**

### Networking
- [ ] How does DNS work inside a Kubernetes cluster?
- [ ] What is the difference between ClusterIP, NodePort, and LoadBalancer?
- [ ] A pod can't reach a Service — walk me through your debugging process
- [ ] What is a NetworkPolicy and when would you use one?
- [ ] What is the difference between Ingress and a LoadBalancer Service?

**Section Score: ___ / 25**

### Security & RBAC
- [ ] How does RBAC work in Kubernetes?
- [ ] What is the difference between a Role and a ClusterRole?
- [ ] What is a ServiceAccount and why does it matter?
- [ ] How would you prevent a pod from running as root?
- [ ] Explain Sealed Secrets vs plain Kubernetes Secrets

**Section Score: ___ / 25**

### GitOps & Operations
- [ ] What is GitOps and how does ArgoCD implement it?
- [ ] How do you do a zero-downtime deployment?
- [ ] A deployment is stuck in a rolling update — what do you check?
- [ ] How would you handle a secret rotation in Kubernetes?
- [ ] Explain the difference between Rolling, Blue/Green, and Canary deployments

**Section Score: ___ / 25**

**Total Technical Score: ___ / 100**

---

## Section 2 — Live Debugging (Score 1–5)

TA presents a broken scenario. Student must diagnose and fix it live.

**Scenario options (TA picks one):**
- Pod in CrashLoopBackOff with a specific error
- Service not routing to pods (selector mismatch)
- HPA not scaling (missing resource requests)
- Ingress returning 404 (wrong backend service name)
- NetworkPolicy blocking traffic

**Evaluation criteria:**
- [ ] Ran `kubectl describe` before guessing
- [ ] Read the error message carefully
- [ ] Asked clarifying questions when needed
- [ ] Explained their reasoning as they went
- [ ] Found the root cause (not just a workaround)

**Debugging Score: ___ / 5**

**TA Notes:**
```
What the student did well:


What needs improvement:


```

---

## Section 3 — System Design (Score 1–5)

**Question (TA picks one):**

**Option A:** "Design a production Kubernetes platform for a team of 20 engineers. They need dev, staging, and prod environments. How do you structure namespaces, RBAC, GitOps, and observability?"

**Option B:** "Your company's Kubernetes cluster is growing from 5 services to 50. What changes do you make to the platform?"

**Option C:** "Walk me through your Project 15 capstone architecture. Why did you make the decisions you made?"

**Evaluation criteria:**
- [ ] Started with requirements / clarifying questions
- [ ] Covered security (RBAC, secrets, network policies)
- [ ] Covered observability (metrics, logs, alerts)
- [ ] Covered deployment strategy (GitOps, environments)
- [ ] Trade-offs discussed (not just "best practices")

**Design Score: ___ / 5**

---

## Section 4 — Behavioral Questions (Score 1–5 each)

- [ ] Tell me about something complex you built. Walk me through it.
- [ ] Tell me about a time you debugged a difficult problem.
- [ ] How do you handle a situation where you don't know the answer?
- [ ] Tell me about a time you improved a process or system.

**STAR format check:** Did they describe the Situation, Task, Action, and Result?

**Behavioral Score: ___ / 20**

---

## Overall Score Summary

| Section | Score | Max |
|---------|-------|-----|
| Technical Questions | | 100 |
| Live Debugging | | 5 |
| System Design | | 5 |
| Behavioral | | 20 |
| **Total** | | **130** |

| Score Range | Verdict |
|-------------|---------|
| 110–130 | 🟢 Ready to interview — apply now |
| 90–109 | 🟡 Almost ready — address specific gaps, re-mock in 2 weeks |
| 70–89 | 🟠 More prep needed — focus on weak sections, re-mock in 4 weeks |
| Below 70 | 🔴 Not ready — back to projects, schedule another mock after completing 2 more |

---

## Written Feedback Template (TA sends after session)

```
Hi [Name],

Great job completing your mock interview. Here's your feedback:

STRENGTHS
- [Specific thing they did well]
- [Another strength]

GAPS TO CLOSE
- [Topic 1]: [Specific recommendation]
- [Topic 2]: [Specific recommendation]

VERDICT: [Ready / Almost ready / More prep needed]

NEXT STEPS:
1. [Specific action]
2. [Specific action]
3. Re-mock date: [date if applicable]

You got this. Keep building.
— [TA name]
```
