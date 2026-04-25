# Assignment 01 — CLI Essentials & Docker Commands

> 📚 **Covers:** Sessions 1 (Why Docker) + 2 (Docker Architecture)
> ⏱ **Estimated time:** 60–90 minutes
> 👤 **Individual** | 🟢 **Beginner**

## Why this assignment exists

Everything you do for the next 30 sessions runs through a terminal. If `cd`, `ls`, environment variables, pipes, and redirection feel awkward, the Docker and Kubernetes work that comes next will feel ten times harder than it actually is.

This assignment is the bridge between Sessions 1–2 and Lab 03 (Running Containers). Part 1 makes sure your shell skills are solid. Part 2 makes sure you can drive Docker from the command line — `run`, `ps`, `logs`, `exec`, `inspect`, `rm`. Part 3 forces you to combine them.

By the end, you should be able to start a container, look inside it, watch its logs, change something on the host, and clean up — all from one terminal, without copy-pasting from notes.

---

## Learning objectives

By the end of this assignment you should be able to:

- Move around a filesystem and inspect files with shell commands alone
- Use pipes (`|`), redirection (`>`, `>>`), and command substitution (`$(...)`) to chain tools
- Read and set environment variables in your shell
- Explain the difference between an **image** and a **container**
- Use the most common `docker` commands without looking them up: `run`, `ps`, `images`, `logs`, `exec`, `inspect`, `stop`, `rm`, `rmi`, `pull`, `system df`, `system prune`
- Read `docker --help` and `docker <command> --help` to discover flags on your own

---

## Prerequisites

- [ ] Lab 01 (`class-materials/labs/01-why-docker/`) completed — Docker installed and `docker run hello-world` works
- [ ] A terminal you're comfortable opening (Terminal.app, iTerm2, Windows Terminal, GNOME Terminal — any will do)
- [ ] ~30 minutes of uninterrupted time per part

> **macOS / Windows:** the Docker daemon runs inside the Docker Desktop VM. The `docker` CLI on your host still works the same way. Linux users have the daemon running natively.

---

## Part 1 — CLI Essentials (20–25 min)

You'll be using the same handful of shell commands every day for the rest of this course. Build muscle memory now.

### 1.1 Where am I, what's here, where can I go

```bash
pwd                       # print working directory
ls                        # list files in current directory
ls -la                    # long listing, including hidden files
cd ~                      # go to your home directory
cd -                      # go back to the previous directory
mkdir cli-practice        # create a directory
cd cli-practice           # enter it
```

> **Try it:** create a directory called `cli-practice/docker-notes`, `cd` into it, then `cd` back to your home directory in one command using `~`.

### 1.2 Read, write, and inspect files

```bash
echo "hello" > greeting.txt          # write (overwrites)
echo "world" >> greeting.txt         # append
cat greeting.txt                     # print whole file
head -1 greeting.txt                 # first line
tail -1 greeting.txt                 # last line
wc -l greeting.txt                   # line count
```

> **Try it:** create a file `commands.txt` containing the names of five Docker subcommands, one per line. Use `wc -l` to confirm there are exactly five lines.

### 1.3 Pipes, redirection, and command substitution

These three patterns underlie almost every shell one-liner you'll see in this course.

```bash
# Pipe: feed the output of one command into the next
ls -la | grep ".txt"

# Redirect: send output to a file instead of the screen
ls -la > listing.txt

# Command substitution: use one command's output as another command's argument
echo "Today is $(date +%Y-%m-%d)"
```

> **Try it:** write a one-liner that lists every file in the current directory whose name contains "txt" and saves the result to `txt-files.log`.

### 1.4 Environment variables

```bash
echo $HOME                # built-in: your home directory
echo $PATH                # where the shell looks for commands
export MY_NAME="Ada"      # set a variable for this shell session
echo "Hi, $MY_NAME"
env | grep MY_NAME        # confirm it's in the environment
```

> **Why this matters for Docker:** `docker run -e MY_VAR=value ...` injects environment variables into containers. The `$VAR` syntax you just used is exactly how containers receive runtime configuration.

### 1.5 Discover commands with `--help` and `man`

```bash
ls --help | head -20      # quick flag reference
man ls                    # full manual (q to quit)
```

You will use `docker <command> --help` constantly for the rest of this course. Get used to reading help output before reaching for Google.

### 1.6 Clean up Part 1

```bash
cd ~
rm -rf cli-practice       # ⚠️  rm -rf deletes everything, no trash bin
```

> **Question:** What is the difference between `rm file.txt` and `rm -rf directory/`? Why is the second form considered dangerous?

---

## Part 2 — Docker Commands (25–30 min)

Every Docker command follows the same shape:

```
docker <object> <verb> [flags] [arguments]
```

For example: `docker container run -d --name web nginx`. You can also use the older shorthand (`docker run -d --name web nginx`) — both work, but the explicit form (`docker container run`) reads better and matches the docs.

### 2.1 Images vs containers

An **image** is a read-only template. A **container** is a running (or stopped) instance of an image. You can have one image and twenty containers from it.

```bash
docker image pull alpine:3.19         # download an image
docker image ls                       # list local images
docker container run alpine echo hi   # create + start a container
docker container ls -a                # list containers (including exited)
```

> **Question:** After running the four commands above, how many images do you have? How many containers? Why?

### 2.2 The Big Eight commands

These are the eight you will type every single day. Practice each one.

#### `docker run` — create and start a container

```bash
docker container run -d --name web -p 8080:80 nginx:1.25
```

Flags worth memorising:

| Flag | Meaning |
|---|---|
| `-d` | detached (run in background) |
| `--name <name>` | give the container a friendly name |
| `-p HOST:CONTAINER` | publish a port from container to host |
| `-e KEY=VALUE` | set an environment variable inside the container |
| `--rm` | remove the container automatically when it exits |
| `-it` | interactive terminal (use with shells) |
| `--restart <policy>` | restart policy: `no`, `always`, `unless-stopped`, `on-failure` |

> **Try it:** open `http://localhost:8080` in your browser. You should see the nginx welcome page being served from the container.

#### `docker ps` — list running containers

```bash
docker container ls           # running containers only
docker container ls -a        # include exited / stopped
docker container ls -q        # just the IDs (useful in scripts)
```

#### `docker logs` — read a container's stdout/stderr

```bash
docker container logs web
docker container logs -f web  # follow (like tail -f)
```

> **Try it:** with `docker logs -f web` running in one terminal, refresh `http://localhost:8080` in your browser and watch the access log appear in real time.

#### `docker exec` — run a command inside a running container

```bash
docker container exec web ls /usr/share/nginx/html
docker container exec -it web sh         # open a shell inside the container
# inside the container:
cat /etc/nginx/nginx.conf | head
exit
```

> **Question:** What's the difference between `docker run -it alpine sh` and `docker exec -it <name> sh`? When would you use each?

#### `docker inspect` — full JSON metadata

```bash
docker container inspect web | head -40
docker container inspect -f '{{.State.Status}}' web    # just the status
docker container inspect -f '{{.NetworkSettings.IPAddress}}' web
```

The `-f` (format) flag uses Go templates. You'll use this constantly in scripts.

#### `docker stop` and `docker rm` — stop and remove

```bash
docker container stop web
docker container ls -a            # web is now Exited, still on disk
docker container rm web           # gone
```

> **Shortcut:** `docker container rm -f web` stops and removes in one step.

#### `docker images` and `docker rmi` — manage images

```bash
docker image ls
docker image rm nginx:1.25        # fails if a container is using it
docker image rm -f nginx:1.25     # force
```

#### `docker system df` and `docker system prune` — see and reclaim disk

```bash
docker system df                  # how much disk is Docker using
docker system prune               # remove stopped containers + dangling images
docker system prune -a            # ⚠️  also removes unused images
```

### 2.3 Reading help is a skill

```bash
docker --help                     # all top-level subcommands
docker container --help           # all container subcommands
docker container run --help       # every flag for `run` (long — pipe to less)
docker container run --help | less
```

> **Try it:** find the flag that mounts a single file from the host into a container as read-only. (Hint: search for "mount" in the `run --help` output.)

---

## Part 3 — Put It Together (15–20 min)

This is the real test. Do it in one terminal session, in order, without looking at the earlier sections. If you get stuck, check `--help` first.

1. Pull the `nginx:1.25` image.
2. Start it as a detached container named `practice-web`, with host port `8081` mapped to container port `80`, and an environment variable `STUDENT_NAME` set to your name.
3. Confirm it's running with `docker container ls`.
4. Open `http://localhost:8081` in your browser — confirm the nginx page loads.
5. Stream the logs with `docker container logs -f` and refresh the browser twice. Stop following with `Ctrl+C`.
6. Open a shell inside the container with `docker container exec -it`. Inside, run `env | grep STUDENT_NAME` and confirm your variable is there.
7. From inside the container, write a file `/usr/share/nginx/html/index.html` containing the text `Hello from <your name>`. Exit the shell.
8. Refresh `http://localhost:8081` — your custom page should now load.
9. Use `docker container inspect -f` to print just the container's IP address.
10. Stop and remove the container in a single command.
11. Run `docker system df` and note how much space images are still using.
12. Remove the `nginx:1.25` image.

---

## Submission

Create a file `assignment-01-<your-github-username>.md` containing:

1. **Part 1 reflection (3–5 sentences):** which CLI command was new to you, and what did you use it for?
2. **Part 2 answers:** the three numbered "Question" prompts in Part 2 (images vs containers, `run` vs `exec`, the read-only mount flag).
3. **Part 3 evidence:** a screenshot (or copy-pasted terminal output) showing:
   - `docker container ls` after step 3
   - The browser page after step 8 showing your custom message
   - The output of `docker container inspect -f '{{.NetworkSettings.IPAddress}}' practice-web` from step 9
4. **One thing that surprised you** about how Docker behaves.

Push the file to your fork of the cohort repo under `submissions/assignment-01/` and open a pull request, or post the link in the cohort Slack channel `#assignments` — whichever your TA prefers.

---

## Validation checklist

Before you submit, you should be able to do each of these from memory:

- [ ] Open a terminal, navigate to a directory, and create/read/append to a file
- [ ] Use a pipe to filter the output of one command with another
- [ ] Set and read an environment variable in your shell
- [ ] Pull an image and start a detached container with a name and a published port
- [ ] List running and stopped containers
- [ ] Stream a container's logs in real time
- [ ] Open an interactive shell inside a running container
- [ ] Print one specific field from `docker inspect` using `-f`
- [ ] Stop and remove a container in one command
- [ ] Reclaim disk space with `docker system prune`

---

## Common pitfalls

**"Cannot connect to the Docker daemon"** — Docker Desktop isn't running (macOS/Windows) or `dockerd` isn't started (Linux: `sudo systemctl start docker`).

**"Port is already allocated"** — something else is on `8080`. Pick another port (`8082`, `8083`).

**`docker exec` says "container is not running"** — the container exited. Check `docker container ls -a` and read the logs to see why.

**Changes inside the container disappeared** — you removed and recreated the container. The writable layer goes with it. Volumes (Session 7) are how you persist data.

**`rm` deleted something I wanted** — there is no trash bin. Always `pwd` and `ls` before any `rm -rf`. Better: use `mv` to a `~/trash/` directory you empty manually.

---

## Going further (optional)

1. Use `docker container run --help | grep -i mount` and figure out three different ways to get host data into a container.
2. Read [Docker CLI reference](https://docs.docker.com/reference/cli/docker/) — bookmark it.
3. Read `man bash` (or `man zsh`) and skim the section on **Parameter Expansion**. You'll see `${VAR:-default}` patterns everywhere in shell scripts and Dockerfiles.
4. Install [`tldr`](https://tldr.sh) (`brew install tldr` / `npm install -g tldr`) and run `tldr docker run` — concise examples for any command.

---

## What's next

- **Lab 03** (`class-materials/labs/03-running-containers/`) — deep dive on container lifecycle, restart policies, resource limits
- **Session 3** — Running Containers (covers what Lab 03 practises)
- **Assignment 02** — Sessions 3 + 4 (Running Containers + Images Deep Dive)
