# 🏭 Git in Practice — Real-World Workflows

## How Teams Actually Work

Understanding git commands is step one. Understanding *how teams use them together* is what makes you effective at work.

---

## The Most Common Workflow: Feature Branch Flow

This is what most teams do:

```
main (always stable, always deployable)
  ├── feature/user-auth         ← dev A
  ├── feature/dashboard-charts  ← dev B
  └── fix/login-crash           ← dev C
```

Rules:
1. **Never commit directly to `main`**
2. Every change goes through a PR
3. PRs must be reviewed before merging
4. `main` is always deployable (no broken code allowed)

---

## GitOps — Git as the Source of Truth

**GitOps** is the modern way to manage infrastructure and Kubernetes.

The idea:
- Your Kubernetes YAML files live in Git
- When you merge a change to `main`, it automatically deploys to your cluster
- Git IS your deployment history

```
Developer → Push code → GitHub PR → Merge → ArgoCD detects change → Deploys to K8s
```

You'll use ArgoCD in Session 26 — that's GitOps in action.

---

## Writing Good Commit Messages

Bad commit messages make debugging a nightmare later.

**Bad:**
```
fix stuff
update
changes
asdfgh
```

**Good:**
```
Fix login crash when username contains spaces

The login handler was splitting on spaces, which broke usernames
like "John Smith". Changed to split on first colon instead.

Fixes #42
```

### The 7 Rules of Good Commits

1. Separate subject from body with a blank line
2. Limit subject line to 72 characters
3. Capitalize the subject line
4. Don't end subject with a period
5. Use imperative mood: "Fix bug" not "Fixed bug"
6. Wrap body at 72 characters
7. Reference issues and PRs in the body

**One-liner format** (for simple changes):
```
Add README with project overview
Fix null pointer in user service
Update K8s version to 1.29
```

---

## Useful Git Commands You'll Use Daily

```bash
# See the status of everything
git status

# See what changed (unstaged)
git diff

# See what's staged
git diff --staged

# Stage everything
git add .

# Stage specific file
git add path/to/file.yaml

# Commit with message
git commit -m "Your message here"

# Push to remote
git push

# Pull latest changes
git pull

# Create and switch to new branch
git checkout -b feature/my-thing

# Switch between existing branches
git checkout main

# See all branches
git branch -a

# Merge a branch
git merge feature/my-thing

# Delete a merged branch
git branch -d feature/my-thing

# View commit history (compact)
git log --oneline

# View who last changed each line of a file
git blame filename.md

# Undo last commit (keeps the changes)
git reset --soft HEAD~1

# See changes in a specific commit
git show abc1234
```

---

## Handling Mistakes

### "I committed to main by accident"

```bash
# Undo the last commit, keep the changes staged
git reset --soft HEAD~1

# Create a branch for those changes
git checkout -b feature/my-feature

# Push the branch instead
git push origin feature/my-feature
```

### "I need to change my last commit message"

```bash
git commit --amend -m "Better message"
# Only do this BEFORE pushing!
```

### "I accidentally deleted a file"

```bash
# Restore a deleted file
git checkout HEAD -- path/to/file.md
```

### "I want to see the repo as it was 3 days ago"

```bash
# Find the commit hash from that time
git log --oneline

# Temporarily view that state
git checkout abc1234

# Come back to present
git checkout main
```

---

## A Real PR Checklist

Before opening a PR, ask yourself:
- [ ] Does the code do what I said it does?
- [ ] Did I test it?
- [ ] Is the PR small enough to review in 15 minutes?
- [ ] Does my PR description explain *why*, not just *what*?
- [ ] Did I remove debug logs and commented-out code?
- [ ] Are my commit messages clear?

**Small PRs get reviewed faster and merged more easily.** Always aim to break big changes into smaller ones.

---

## Git Aliases — Save Time

Add these to `~/.gitconfig` for shortcuts:

```ini
[alias]
  st = status
  co = checkout
  br = branch
  lg = log --oneline --graph --decorate
  last = log -1 HEAD
```

Now `git st` = `git status`, and `git lg` shows a pretty branch graph.

---

## 🎉 Congratulations — You've Completed Git Fundamentals!

You now know:
- ✅ What Git is and why it exists
- ✅ How to create a repo and make commits
- ✅ How to use branches for safe parallel work
- ✅ How to collaborate via GitHub and Pull Requests
- ✅ Real-world workflows and best practices

**You're ready for GitOps and the Kubernetes class.**

When you're working with class materials, you'll:
- `git pull` to get the latest content
- Create branches when working on exercises
- Open PRs to submit your work

Go back and check out the main class materials → [class-materials/](../class-materials/)
