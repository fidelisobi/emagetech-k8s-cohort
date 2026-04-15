# 🌿 Branching — Working Without Breaking Things

## Why branches exist

Imagine you're building a feature and it takes 2 weeks.
Meanwhile, a bug is found and needs to be fixed TODAY.

Without branches, you're stuck — your half-done feature is tangled with the codebase.

**Branches** let you have parallel, isolated lines of work.

---

## The Default Branch

When you create a repo, Git creates one branch automatically: usually called `main` (or `master` in older repos).

Think of `main` as the "official" version of your code — the one that's stable and deployed.

---

## Creating and Switching Branches

```bash
# See all branches (* marks the current one)
git branch

# Create a new branch
git branch feature/add-login

# Switch to it
git checkout feature/add-login

# OR do both in one step (the modern way)
git checkout -b feature/add-login

# Even newer syntax (Git 2.23+)
git switch -c feature/add-login
```

Now you're on `feature/add-login`. Any commits you make here don't affect `main`.

---

## A Visual Example

```
main:    A → B → C
                  \
feature:            D → E
```

- Commits A, B, C are on `main`
- Commits D, E are on your feature branch
- `main` still points at C — untouched

---

## Making Changes on a Branch

```bash
# You're on feature/add-login
echo "login functionality" > login.md
git add login.md
git commit -m "Add login module"
```

Switch back to main — `login.md` is gone (it only exists on your branch):

```bash
git checkout main
ls  # login.md is not here
```

Switch back to feature — it's back:

```bash
git checkout feature/add-login
ls  # login.md is here
```

Branches are like separate workspaces.

---

## Merging — Bringing Changes Together

When your feature is done, merge it into `main`:

```bash
# First, go to main
git checkout main

# Merge the feature branch into main
git merge feature/add-login
```

Now `main` has all the changes from `feature/add-login`.

```
main:    A → B → C → D → E → M
                            ↗
feature: ................D → E
```

---

## Merge Conflicts — When Two Changes Clash

If you and a teammate both edited the same line of the same file, Git can't decide which version to keep. That's a **merge conflict**.

Git marks the file like this:

```
<<<<<<< HEAD (main)
Hello from main
=======
Hello from feature branch
>>>>>>> feature/add-login
```

You have to manually edit the file to pick one version (or combine them), then:

```bash
# Stage the resolved file
git add conflicted-file.md

# Complete the merge
git commit
```

---

## Deleting a Branch

After merging, you don't need the branch anymore:

```bash
# Delete locally
git branch -d feature/add-login

# Force delete (if not merged)
git branch -D feature/add-login
```

---

## Branch Naming Conventions

Teams use naming conventions so everyone knows what a branch is for:

| Prefix | Purpose | Example |
|--------|---------|---------|
| `feature/` | New functionality | `feature/user-auth` |
| `fix/` | Bug fix | `fix/login-crash` |
| `docs/` | Documentation changes | `docs/update-readme` |
| `chore/` | Maintenance tasks | `chore/upgrade-deps` |

---

## 🧪 Practice Exercise

1. Create a new branch called `feature/my-notes`
2. Add a file called `my-notes.md` with some content
3. Commit it
4. Switch back to `main`
5. Verify `my-notes.md` is NOT there
6. Merge `feature/my-notes` into `main`
7. Verify `my-notes.md` IS now there

---

## ✅ What You Learned

- Branches are isolated workspaces — changes don't affect each other
- `git checkout -b` creates and switches to a new branch
- `git merge` brings a branch's changes into another
- Merge conflicts happen when the same lines were changed differently
- Delete branches after merging to keep things tidy

**Next up:** [Collaborating on GitHub →](04-github-collaboration.md)
