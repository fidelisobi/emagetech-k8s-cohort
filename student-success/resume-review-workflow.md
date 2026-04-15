# 📄 Resume Review Workflow

**Rule: No student submits a job application with an unreviewed resume.**

This single rule has the highest ROI of anything in this program. A bad resume gets filtered before a human ever reads it. A great resume gets you in the room — where your skills close the deal.

---

## For Students — How to Submit Your Resume

### Step 1 — Write Your First Draft
Use `career/resume-guide.md` as your guide. Key requirements before submitting:
- [ ] Technical skills section is specific and grouped by category
- [ ] Every bullet point has: Action verb + what you did + outcome
- [ ] Projects section covers your best 4–6 cohort projects
- [ ] GitHub link is included and profile is public
- [ ] No `:latest` image tags (this is a joke — but check for typos)
- [ ] 1–2 pages max

### Step 2 — Post in Slack
Post in `#kubernetes-january-2026-cohort`:
```
📄 Resume Review Request — [Your Name]
[Link to Google Doc — comment access]
Target roles: [e.g., "Kubernetes Engineer, Platform Engineer, DevOps"]
Target companies: [e.g., "mid-size tech companies, cloud-native startups"]
Timeline: [e.g., "want to start applying in 2 weeks"]
```

### Step 3 — TA Reviews Within 48 Hours
A TA will leave detailed comments on your Google Doc. Expect feedback on:
- Bullet point strength (action + outcome)
- Technical skills section completeness
- Project descriptions
- Overall presentation

### Step 4 — Revise and Resubmit
Address all comments. Repost the updated version with: *"Rev 2 — addressed feedback"*

### Step 5 — Final Approval
TA leaves a ✅ comment. You're cleared to apply.

---

## For TAs — The Review Checklist

When reviewing a student's resume, check every item:

### Contact & Header
- [ ] Name is prominent
- [ ] Professional email (not hotmail/yahoo ideally)
- [ ] GitHub link present and leads to a real profile with pinned repos
- [ ] LinkedIn link present
- [ ] Location (city/state or "Remote") — no full address needed

### Technical Skills
- [ ] Grouped by category (not a comma-separated wall of text)
- [ ] Specific: "GKE, EKS, AKS" not just "Kubernetes"
- [ ] No skills they can't talk about in an interview
- [ ] CKA listed if they have it (or "CKA in progress")

### Experience / Projects Bullets
- [ ] Every bullet starts with an action verb
- [ ] Quantified where possible (scaled to X replicas, reduced deploy time by Y%)
- [ ] Cohort projects described in professional language
- [ ] No "worked on" or "responsible for" — replace with specific actions

### Projects Section
- [ ] At least 4 projects from the cohort listed
- [ ] Project 15 (Capstone) is highlighted
- [ ] Each project has a 1-line description and GitHub link
- [ ] Technical stack named explicitly

### Formatting
- [ ] 1–2 pages (1 for < 5 years experience)
- [ ] Consistent formatting (same font, same bullet style)
- [ ] No spelling or grammar errors
- [ ] Dates are consistent (month/year format)

### Red Flags to Call Out
- [ ] "Familiar with" — means they don't know it. Remove or replace with specific experience.
- [ ] Generic bullets ("managed servers") — needs specifics
- [ ] Too many tools without depth — prioritize tools they actually know
- [ ] No GitHub / empty GitHub — must fix before applying

---

## Common Feedback Phrases

Copy-paste these into Google Doc comments:

**Weak bullet:**
> ❌ *"Worked on Kubernetes deployments"*
> ✅ Try: *"Deployed 3-tier Node.js application to GKE using raw YAML manifests — Deployments, Services, ConfigMaps, and Secrets — achieving zero downtime via rolling update strategy"*

**Too vague:**
> This bullet needs: (1) what you specifically did, (2) the scale or context, (3) the outcome or impact. Right now it reads like a job description, not an accomplishment.

**Missing outcome:**
> Great action and context — add what the result was. Even "which reduced deployment time from 45 min to 8 min" or "which improved cluster security posture from 35% to 92%" makes this significantly stronger.

**Listing too many tools:**
> Only list tools you can discuss in an interview. If an interviewer asks about [tool], can you explain how you used it, a problem you solved with it, and a trade-off? If not, remove it.
