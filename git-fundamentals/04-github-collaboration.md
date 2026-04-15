# 🤝 GitHub — Collaborating with Others

## What Is GitHub (Again)?

GitHub is a website that hosts Git repositories online.
It adds:
- A web interface to browse code and history
- **Pull Requests** — the standard way to review and merge code
- Issues — for tracking bugs and tasks
- Actions — for automating tests and deployments

---

## Connecting Your Local Repo to GitHub

### Create a repo on GitHub
1. Go to https://github.com
2. Click "New repository"
3. Name it, choose public or private, click Create

### Link it to your local repo

```bash
# Add GitHub as the "remote" (the online copy)
git remote add origin https://github.com/yourname/your-repo.git

# Push your local commits to GitHub
git push -u origin main
```

`-u` sets the upstream, so next time you can just type `git push`.

---

## Cloning — Getting an Existing Repo

To get a copy of any repo (including this cohort's class materials):

```bash
git clone https://github.com/emage-tech/kubernetes-january-2026-cohort.git
```

This downloads the full repo, with all history, to your machine.

---

## The Daily Push/Pull Cycle

```bash
# Get the latest changes from GitHub
git pull

# ... do your work, make commits ...

# Push your commits to GitHub
git push
```

Always `git pull` before starting work — keeps you in sync with teammates.

---

## Pull Requests (PRs) — The Heart of Collaboration

A **Pull Request** (PR) is a formal request to merge your branch into another.

It gives teammates a chance to:
- Read your changes
- Leave comments
- Request changes
- Approve and merge

### How to open a PR

1. Push your branch to GitHub:
   ```bash
   git push origin feature/my-feature
   ```

2. Go to GitHub — you'll see a banner: "Compare & pull request"

3. Fill in:
   - **Title:** What does this PR do? (e.g., "Add user login flow")
   - **Description:** Why? What was the approach? Any notes for reviewers?
   - Set the **base branch** (usually `main`) and **compare branch** (your feature)

4. Click "Create pull request"

Teammates are notified and can review.

---

## Reading a PR (For Reviewers)

On the PR page you'll see:
- **Files changed** tab — shows exactly what lines were added/removed (green = added, red = removed)
- **Commits** tab — shows the individual commits
- **Conversation** tab — for discussion

You can leave a comment on any line by clicking the `+` that appears on hover.

---

## Forking — Contributing to Someone Else's Repo

If you don't have write access to a repo, you **fork** it first:

1. Click "Fork" on GitHub — creates your own copy
2. Clone your fork locally
3. Make changes, push to your fork
4. Open a PR from your fork → the original repo

This is how open source works — anyone can contribute without needing permission first.

---

## Syncing a Fork with the Original

After forking, the original repo keeps updating. Stay in sync:

```bash
# Add the original as "upstream"
git remote add upstream https://github.com/original-owner/repo.git

# Fetch and merge their latest changes
git fetch upstream
git merge upstream/main
```

---

## 🧪 Practice Exercise

1. Create a new repo on GitHub (name it `git-practice`)
2. Clone it to your machine
3. Create a branch called `feature/hello-world`
4. Add a file called `hello.md` with "Hello, World!"
5. Push the branch to GitHub
6. Open a Pull Request on GitHub
7. Merge the PR

---

## ✅ What You Learned

- `git remote add origin` links your local repo to GitHub
- `git push` / `git pull` sync changes with GitHub
- Pull Requests are how teams review and merge code
- Forking lets you contribute to repos you don't own

**Next up:** [Real-world Git workflows →](05-git-in-practice.md)
