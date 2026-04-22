# Lab 03: Running Containers — Lifecycle, Logs, Limits

## Overview

You'll exercise the full container lifecycle — create, start, pause, stop, kill, remove —
and use `logs`, `exec`, `inspect`, and `stats` to debug containers. You'll also publish
ports, set resource limits, and experiment with restart policies.

**Estimated time:** 45 minutes

**Prerequisites:**

- Docker installed and working (Lab 01, 02)
- A web browser

---

## Part 1: Foreground, Detached, Interactive

### 1.1 Foreground

```bash
docker container run nginx:1.25
```

The terminal is blocked; logs stream to stdout. **Ctrl-C** sends SIGINT — nginx logs a
"signal 2 (SIGINT) received" line and exits.

### 1.2 Detached with a name

```bash
docker container run -d --name web -p 8080:80 nginx:1.25
docker container ls
curl -I http://localhost:8080
```

### 1.3 Interactive shell

```bash
docker container run -it --rm alpine sh
# inside the container:
uname -a
echo "hello from alpine"
exit
```

`--rm` means the container is deleted on exit.

---

## Part 2: The Lifecycle

### 2.1 Create without starting

```bash
docker container create --name counter alpine sh -c 'i=0; while :; do echo $i; i=$((i+1)); sleep 1; done'
docker container ls -a
# STATUS will be 'Created'
```

### 2.2 Start it

```bash
docker container start counter
docker container logs -f counter          # Ctrl-C to stop following
```

### 2.3 Pause / unpause

```bash
docker container pause counter
docker container logs --tail 3 counter
sleep 3
docker container logs --tail 3 counter    # same three lines — frozen

docker container unpause counter
```

### 2.4 Stop (SIGTERM) and restart

```bash
time docker container stop counter        # default 10 s grace period
docker container start counter
```

### 2.5 Kill (SIGKILL)

```bash
docker container kill counter
docker container ls -a                    # 'Exited (137)' → 128+9 (SIGKILL)
```

### 2.6 Remove

```bash
docker container rm counter
```

---

## Part 3: Signals & Graceful Shutdown

### 3.1 A polite app

```bash
# This container sleeps, then exits 0 on SIGTERM
docker container run -d --name polite alpine sh -c 'trap "exit 0" TERM; while :; do sleep 1; done'

time docker container stop polite    # ~1 s
docker container inspect -f '{{.State.ExitCode}}' polite
docker container rm polite
```

### 3.2 An impolite app

```bash
docker container run -d --name rude alpine sh -c 'trap "" TERM; while :; do sleep 1; done'

time docker container stop rude      # ~10 s — grace period, then SIGKILL
docker container inspect -f '{{.State.ExitCode}}' rude
docker container rm rude
```

> **Question:** What exit code does a process have after being killed by SIGKILL, and where
> does the 128+signal convention come from?

### 3.3 Tune the grace period

```bash
docker container run -d --name rude alpine sh -c 'trap "" TERM; while :; do sleep 1; done'
time docker container stop -t 3 rude
docker container rm rude
```

---

## Part 4: Logs, Exec, Inspect, Stats

### 4.1 Logs

```bash
docker container run -d --name noisy alpine sh -c 'for i in $(seq 1 1000); do echo "line $i"; sleep 0.1; done'

docker container logs noisy                # all logs
docker container logs --tail 20 noisy      # last 20
docker container logs -f noisy             # follow
docker container logs --since 5s noisy     # last 5 seconds
```

### 4.2 Exec into a running container

```bash
docker container exec noisy ps aux
docker container exec -it noisy sh
# inside:
echo "I am $(hostname) with PID $$"
cat /etc/alpine-release
exit
```

### 4.3 Inspect

```bash
docker container inspect noisy | less                # full JSON
docker container inspect -f '{{.State.Status}}' noisy
docker container inspect -f '{{.NetworkSettings.IPAddress}}' noisy
docker container inspect -f '{{range $p,$_ := .Config.ExposedPorts}}{{$p}} {{end}}' noisy
```

### 4.4 Stats

```bash
docker container stats --no-stream noisy
```

The `--no-stream` flag prints one snapshot. Without it, you get a live view.

### 4.5 Clean up

```bash
docker container rm -f noisy
```

---

## Part 5: Port Publishing

### 5.1 Publish one port

```bash
docker container run -d --name web -p 8080:80 nginx:1.25
curl -I http://localhost:8080
docker container port web
```

### 5.2 Bind to localhost only

```bash
docker container rm -f web
docker container run -d --name web -p 127.0.0.1:8080:80 nginx:1.25
curl -I http://localhost:8080                       # works
curl -I http://$(hostname -I | awk '{print $1}'):8080 || true   # fails on Linux
```

### 5.3 Random host port

```bash
docker container rm -f web
docker container run -d --name web -P nginx:1.25
docker container port web                          # host port chosen for you
docker container rm -f web
```

### 5.4 Port conflict

```bash
docker container run -d --name web1 -p 8080:80 nginx:1.25
docker container run -d --name web2 -p 8080:80 nginx:1.25 || true
# Error: bind: address already in use
docker container rm -f web1
```

---

## Part 6: Environment Variables

### 6.1 Inline

```bash
docker container run --rm -e GREETING=hello -e TARGET=world alpine \
  sh -c 'echo "$GREETING $TARGET"'
```

### 6.2 From a file

```bash
cat > /tmp/demo.env <<EOF
GREETING=hello
TARGET=everyone
EOF

docker container run --rm --env-file /tmp/demo.env alpine \
  sh -c 'echo "$GREETING $TARGET"'
```

### 6.3 See them inside a running container

```bash
docker container run -d --name envdemo -e LOG_LEVEL=debug alpine sleep 1d
docker container exec envdemo env
docker container inspect -f '{{.Config.Env}}' envdemo
docker container rm -f envdemo
```

---

## Part 7: Resource Limits

### 7.1 Memory limit → OOMKill

```bash
# This container tries to allocate 500 MB but is limited to 100 MB
docker container run --rm --memory=100m alpine \
  sh -c 'dd if=/dev/zero of=/dev/shm/x bs=1M count=500'

echo "Exit code: $?"
```

Expect exit code 137 (SIGKILL — killed by the OOM killer).

### 7.2 CPU quota

```bash
# No limit — will use as many cores as it can
docker container run -d --name hot1 alpine sh -c 'while :; do :; done'

# Capped at half a core
docker container run -d --name hot2 --cpus=0.5 alpine sh -c 'while :; do :; done'

docker container stats --no-stream hot1 hot2
docker container rm -f hot1 hot2
```

### 7.3 PIDs limit

```bash
# Prevents fork bombs and runaway thread creation
docker container run -d --name bounded --pids-limit=20 alpine sleep 1d
for i in $(seq 1 25); do
  docker container exec bounded sh -c 'sleep 30 &' || echo "blocked at $i"
done
docker container rm -f bounded
```

---

## Part 8: Restart Policies

### 8.1 A crashing app with `on-failure`

```bash
docker container run -d --name crasher --restart on-failure:3 alpine \
  sh -c 'sleep 2; exit 1'

sleep 15
docker container inspect -f '{{.RestartCount}}' crasher
docker container logs crasher 2>&1 | head
docker container rm -f crasher
```

### 8.2 `unless-stopped`

```bash
docker container run -d --name pinned --restart unless-stopped nginx:1.25

# Simulate a reboot by restarting the Docker daemon (Linux)
# sudo systemctl restart docker        # ← uncomment on Linux servers you control
docker container ls                     # still running after daemon restart

docker container stop pinned
docker container ls -a                  # stays stopped — manually stopped
docker container rm pinned
```

---

## Part 9: Cleanup Patterns

```bash
docker container ls -a                  # what's lying around
docker container prune                  # remove all stopped containers
docker image ls
docker image prune                      # remove dangling images
docker system df                        # disk usage summary
docker system prune                     # prune everything unused
# docker system prune -a --volumes      # also unused images + volumes — aggressive
```

---

## Summary

After completing this lab you should be able to:

- Run containers in foreground, detached, and interactive modes
- Walk a container through create → start → pause → stop → kill → remove
- Use `logs`, `exec`, `inspect`, and `stats` to introspect running containers
- Publish ports with `-p` and understand host vs container port semantics
- Set `--memory`, `--cpus`, `--pids-limit` and watch them enforced
- Pick a restart policy (`on-failure`, `unless-stopped`, `always`) for a given scenario
- Clean up with `prune` commands instead of writing bespoke shell loops

---

## Stretch Goals

1. Run `stress-ng` inside a `--memory=200m` container and use `docker stats` to confirm
   the limit is enforced. Bonus: cause it to get OOMKilled and find the kernel log entry
   (`dmesg` on Linux).
2. Write a 10-line Python web server, run it in Docker, and make it respond to SIGTERM
   gracefully (flush a log file, close a DB connection).
3. Use `docker container logs --since` and `--until` with ISO 8601 timestamps to isolate
   logs from a specific incident window.
