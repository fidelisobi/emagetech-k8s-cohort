# 📜 What Is Git?

## The problem Git solves

Imagine you're writing an essay. You save it as:
```
essay_v1.docx
essay_v2.docx
essay_final.docx
essay_FINAL_real.docx
essay_FINAL_real_SUBMIT_THIS.docx
```

Sound familiar? That's version control done badly.

**Git** is a tool that tracks every change you make to files, who made them, and why — without creating a hundred copies.

---

## What Is Version Control?

Version control is a system that:
1. **Records every change** to your files over time
2. **Lets you go back** to any previous version
3. **Lets multiple people** work on the same files without stepping on each other

Think of it like the "Track Changes" feature in Google Docs, but much more powerful and for any type of file (not just documents).

---

## A Brief History

Before Git, teams used tools like CVS and SVN, which had one central server.
If the server went down, nobody could work.

**Git** (created by Linus Torvalds in 2005 for the Linux kernel) changed everything:
- **Distributed:** Every person has a complete copy of the full history
- **Fast:** Operations happen locally, no server needed
- **Reliable:** Losing one copy doesn't lose your history

---

## Key Concepts (Plain English)

| Term | What It Means | Analogy |
|------|--------------|---------|
| **Repository (repo)** | A folder tracked by Git | A project box with all its history |
| **Commit** | A saved snapshot of your files | A checkpoint in a video game |
| **Branch** | A separate line of work | A parallel universe of your code |
| **Merge** | Combining branches together | Merging two timelines |
| **Remote** | A copy of the repo on another server (like GitHub) | A backup in the cloud |

---

## Git vs. GitHub — They Are NOT the Same

This trips up nearly everyone at first:

- **Git** is the tool — it runs on your computer
- **GitHub** is a website — it hosts Git repositories online

Git existed before GitHub. You can use Git without GitHub (and vice versa, sort of).

Other similar hosting services: GitLab, Bitbucket, Azure DevOps.

---

## Why Every Developer Uses Git

- **It's the industry standard** — every tech company uses it
- **You can experiment safely** — branches let you try things without breaking the main code
- **You can undo mistakes** — no change is ever truly lost
- **It's how teams collaborate** — without it, coordinating code between people is a nightmare

---

## ✅ What You Learned

- Version control tracks file changes over time, with history
- Git is distributed — everyone has the full history
- Key words: repository, commit, branch, merge, remote
- Git ≠ GitHub. Git is the tool; GitHub is a hosting service.

**Next up:** [Creating your first repo →](02-your-first-repo.md)
