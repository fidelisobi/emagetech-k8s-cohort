# 🚀 Your First Git Repository

## Installing Git

First, make sure Git is installed:

```bash
git --version
```

If you see something like `git version 2.43.0`, you're good.

If not:
- **Mac:** `brew install git` or install Xcode Command Line Tools
- **Ubuntu/Debian:** `sudo apt install git`
- **Windows:** Download from https://git-scm.com/

---

## Setting Up Your Identity

Tell Git who you are (this info appears in every commit you make):

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

You only need to do this once.

---

## Creating Your First Repo

```bash
# Create a new folder and enter it
mkdir my-first-project
cd my-first-project

# Initialize Git (creates a hidden .git folder)
git init
```

You'll see: `Initialized empty Git repository in .../my-first-project/.git/`

Git is now watching this folder for changes.

---

## The Git Workflow

Every day with Git looks like this:

```
1. Make changes to files
2. Stage the changes (tell Git "I want to save these")
3. Commit (create a snapshot with a message)
4. Repeat
```

Let's do it:

```bash
# Create a file
echo "# My Project" > README.md

# Check the status (what's new/changed?)
git status
```

You'll see `README.md` listed as "untracked" — Git sees it but isn't tracking it yet.

```bash
# Stage the file (add it to the "ready to commit" area)
git add README.md

# Check status again
git status
```

Now it's "Changes to be committed" — it's staged.

```bash
# Commit — save a permanent snapshot with a message
git commit -m "Add README"
```

Done! You've made your first commit. 🎉

---

## Seeing Your History

```bash
# View all commits
git log

# Shorter, cleaner view
git log --oneline
```

Each commit has:
- A unique ID (like `a1b2c3d`)
- Your name and email
- The date and time
- Your commit message

---

## The Staging Area — Why It Exists

The staging area (also called the "index") is a bit confusing at first.
Why not just go directly from changes → commit?

Because it lets you **be selective**. Imagine you changed 5 files but only want to commit 3 of them right now:

```bash
# Stage only specific files
git add file1.md file2.md

# Stage everything changed
git add .

# See exactly what's staged vs. not staged
git status
git diff          # shows unstaged changes
git diff --staged # shows staged changes
```

---

## Undoing Things

```bash
# Unstage a file (keep the changes, just remove from staging)
git restore --staged README.md

# Discard changes to a file (CAREFUL: this permanently removes your edits)
git restore README.md

# See what changed in a specific commit
git show a1b2c3d
```

---

## .gitignore — Files Git Should Ignore

Some files should never be committed: passwords, local config, build output, etc.

Create a `.gitignore` file:
```bash
cat > .gitignore << 'EOF'
# Don't commit these
node_modules/
*.log
.env
.DS_Store
EOF
```

Git will now ignore anything matching those patterns.

---

## 🧪 Practice Exercise

1. Create a new folder and initialize a repo
2. Create 3 files: `notes.md`, `todo.md`, and `config.txt`
3. Stage only `notes.md` and `todo.md`
4. Commit with the message "Add initial notes and todo"
5. Make changes to `notes.md`
6. Commit the changes with a descriptive message
7. Run `git log --oneline` and see both commits

---

## ✅ What You Learned

- `git init` creates a repository
- `git add` stages changes
- `git commit` saves a permanent snapshot
- `git log` shows your history
- `.gitignore` tells Git what to skip

**Next up:** [Working with branches →](03-branching.md)
