# 🧑‍🏫 TA Office Hours — Operating Guide

This guide is for TAs. It covers how to run office hours effectively and what to do between sessions.

---

## Schedule

| Session | Day | Time | Format |
|---------|-----|------|--------|
| Primary | Tuesday | 7:00 PM CST | Zoom drop-in |
| Secondary | Saturday | 10:00 AM CST | Zoom drop-in |

Post the Zoom link in `#kubernetes-january-2026-cohort` at the start of each session.

---

## Before the Session

1. **Review this week's check-ins** — note who flagged blockers or red morale
2. **Check the Slack backlog** — what questions came in since last session?
3. **Prepare one "concept of the week"** — a 5-minute explanation of something students often misunderstand
4. **Have your cluster ready** — you'll be live debugging with students

---

## Running the Session (60 minutes)

```
0:00 – 0:05   Welcome + brief agenda
               "What's everyone working on this week?"

0:05 – 0:10   Concept of the week (5-min explanation)
               Examples: "Let me show you exactly what happens when a pod OOMKills"
                         "Let me demo how ArgoCD detects drift in real time"

0:10 – 0:50   Open Q&A / live debugging
               Go student by student through their blockers
               Share your screen when debugging — narrate what you're doing and why

0:50 – 0:58   Wrap-up
               "Who's completing what by Friday?"
               Quick wins / shoutouts from the week

0:58 – 1:00   Close + post recording link
```

---

## How to Debug Live (The Teaching Model)

When a student brings a problem:

1. **Ask first:** *"What have you already tried? What does the error say?"*
2. **Think out loud:** *"OK, the pod is in CrashLoopBackOff — first thing I always do is..."*
3. **Don't just fix it:** Walk through your reasoning. The goal is to teach the debugging process, not just solve this one problem.
4. **Recap at the end:** *"So the root cause was X, and the way to always find this is Y."*

The student who watches you debug 5 problems learns to debug 50.

---

## Between Sessions — TA Responsibilities

### Daily (5–10 minutes)
- Check `#kubernetes-january-2026-cohort` for new questions
- Answer or acknowledge any questions within 24 hours
- React to check-ins (👍 minimum — students notice when they're ignored)

### Weekly
- Review all Monday check-ins by Tuesday morning
- DM any student with 🔴 morale within 24 hours
- DM any student who missed their check-in
- Update the cohort progress tracker (which projects are students on?)

### Flags to Escalate to Kenna
- Student missing 2+ check-ins with no response to DMs
- Student stating they're considering dropping out
- Student falling more than 3 weeks behind
- Any interpersonal issues between students
- Any question you can't answer (don't guess — escalate or say "I'll find out")

---

## The "Stuck 30 Minutes" Rule — Enforcement

Train students to follow this rule from week 1. Reinforce it every office hours:

*"If you've been stuck for 30 minutes — post in Slack. Don't wait until Tuesday."*

When a student posts in Slack mid-week:
- Acknowledge within 2 hours (even if just "on it, give me a few minutes")
- Solve or pair them with someone who can help
- If it's a common error, add it to `troubleshooting-cheatsheet.md`

---

## What Makes a Great TA Session

**Do:**
- Share your screen and show the actual commands
- Narrate your debugging thought process
- Call out students by name when they make progress
- End every session by asking "who needs help before Friday?"

**Don't:**
- Just read the error message and give the answer
- Let one student dominate the whole session
- Leave questions unanswered ("I'll look into it" without a follow-up)
- Skip a session without a replacement

---

## TA Communication Standards

- Respond to Slack messages within **24 hours** (weekday), **48 hours** (weekend)
- Give resume feedback within **48 hours** of submission
- Send mock interview written feedback within **24 hours** of the session
- Post office hours Zoom link **5 minutes before** the session starts

---

## Escalation Path

```
Student issue → TA attempts to resolve → Can't resolve in 24h → Escalate to Kenna
                                                                admin@emagegroup.net
```
