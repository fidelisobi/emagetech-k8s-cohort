# Assignment 03 — Fidelis Obi

**GitHub username:** fidelisobi
**Date completed:** 2026-05-24
**Git SHA of submitted app:** sha256:25f09bf6d7886cc6674a86dae3aaede431d19c0e09eb045dcead234b0b33490c

## 1. Size comparison table

| Variant            | Size  | Layers | Stop time | Exit code |
|--------------------|-------|--------|-----------|-----------|
| `cohort-greet:naive` | 1620 MB | 6     | 0m5.347s     | 137        |
| `cohort-greet:multi` | 280 MB |      | 0m2.934s    | 1         |

(Layers = output of `docker image history <tag> | wc -l` minus 1 for the header.)

## 2. Final image digest

`sha256:25f09bf6d7886cc6674a86dae3aaede431d19c0e09eb045dcead234b0b33490c


## 3. Answers to the 7 questions

**Q1 — naive size + stop behaviour + why:** ...

naive size was 416MB. The stop behavior had to signal SIGKILL. it guarantees termination but sacrifices data integrity and graceful shutdown.

**Q2 — build output, CACHED vs rebuilt:**

``` 
 docker image build -t cohort-greet:multi . 2>&1 | grep -E "CACHED|RUN pip"
#4 CACHED
#10 CACHED
#11 CACHED
#12 CACHED
#13 CACHED
#14 [build 5/5] RUN pip install --no-cache-dir -r requirements.txt
#14 CACHED
#15 CACHED
#16 CACHED

```

Every layer was cached.The COPY app.py . layer in the runtime stage was rebuilt. It didn't appear in my grep output because it doesn't contain the words CACHED or RUN pip.


**Q3 — new stop time/exit + which change:** 

The stop time is real    0m2.934s
The exit code is - ExitCode=0

Switching from the shell form of CMD to the exec form. The exec form CMD ["gunicorn", ...] runs gunicorn directly as PID 1.

**Q4 — size reduction breakdown:**

```
IMAGE                ID             DISK USAGE   CONTENT SIZE   EXTRA
cohort-greet:naive   b274fde470f6       1.62GB          416MB    U

IMAGE                ID             DISK USAGE   CONTENT SIZE   EXTRA
cohort-greet:multi   80815f6aaa7b        280MB         65.1MB

```

It shrinked by ~83%.
Switching from the full python:3.11 base to python:3.11-slim and isolating compilation in a build stage permanently discards heavy compiler toolchains and Python development headers after the RUN pip install layer completes. 

Replacing the naive COPY . . with selective COPY requirements.txt . and COPY app.py . ensures only essential files enter the final image layers.  Finally, adding --no-cache-dir to the pip install step and using COPY --from=build /opt/venv /opt/venv guarantees that only compiled dependencies—not downloaded wheel archives or temporary build artifacts are carried into the runtime stage.
**Q5 — cache-mount timings + CI relevance:** ...
**Q6 — secret marker + what `ARG` would leak:** ...
**Q7 — tag vs digest for k8s manifest:** ...

## 4. Files

### Final `Dockerfile`
\`\`\`dockerfile
# syntax=docker/dockerfile:1.7

# ── build stage ──
FROM python:3.11-slim AS build
RUN python -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

# ── runtime stage ──
FROM python:3.11-slim AS runtime
COPY --from=build /opt/venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH
WORKDIR /app

# Create non-root user & fix ownership
RUN useradd --create-home --uid 1000 app && \
    chown -R app:app /app /opt/venv

COPY app.py .
EXPOSE 8080

# Python-native healthcheck
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz')"

# Switch to non-root user
USER app

# Exec-form CMD for proper signal handling
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
\`\`\`

### `Dockerfile.naive`
\`\`\`dockerfile
FROM python:3.11
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
EXPOSE 8080
CMD gunicorn -b 0.0.0.0:8080 app:app
\`\`\`

### `Dockerfile.secret`
\`\`\`dockerfile
# syntax=docker/dockerfile:1.7
FROM python:3.11-slim

RUN --mount=type=secret,id=pypi_token \
    TOKEN=$(head -c 4 /run/secrets/pypi_token) && \
    echo -n "$TOKEN" > /where-token-was-used
\`\`\`

### `.dockerignore`
\`\`\`
.git
.gitignore
node_modules
__pycache__
*.pyc
Dockerfile*
.env
*.log
README.md
\`\`\`

## 5. Evidence

For each, paste the command and output. Trim long output to the relevant lines.

- `docker image ls cohort-greet` (all your tags from Part 4.2)

```
VERSION=0.1.0
SHA=$(git rev-parse --short HEAD)

docker image tag cohort-greet:multi cohort-greet:${VERSION}

cohort-greet   0.1.0           25f09bf6d788

docker image tag cohort-greet:multi cohort-greet:${VERSION}-${SHA}

cohort-greet   0.1.0-19e7439   25f09bf6d788

docker image tag cohort-greet:multi cohort-greet:git-${SHA}

cohort-greet   git-19e7439     25f09bf6d788

```
- `docker image history cohort-greet:multi` (truncate long base-image rows)
- `docker container run --rm cohort-greet:secret cat /where-token-was-used`

```
fidelis@workstation:~/assignment/assignment-03$ docker container run --rm cohort-greet:secret cat /where-token-was-used
```

- The "no leak" / "LEAKED" check from Part 3.2

```
dfidelis@workstation:~/assignment/assignment-docker image history --no-trunc cohort-greet:secret | grep -i "$PYPI_TOKEN" \N" \
  && echo "LEAKED" || echo "no leak"
no leak
```
- `docker container run --rm hadolint/hadolint < Dockerfile` (should be empty)

- The two timing lines from Part 3.1 (cold vs warm cache mount)
```
fidelis@workstation:~/assignment/assignment-03$ { time docker image build --no-cache -t cohort-greet:multi . ; } 2>&1 | tail -2
user    0m0.176s
sys     0m0.596s
fidelis@workstation:~/assignment/assignment-03$ { time docker image build --no-cache -t cohort-greet:multi . ; } 2>&1 | tail -2
user    0m0.164s
sys     0m0.391s

```
- (Optional) URL of your pushed image

## 6. One trade-off I had to make

(2–4 sentences. Pick **one** decision where the slides offered multiple options and you had to choose: alpine vs slim vs distroless, USER 1000 vs `useradd app`, healthcheck via python vs installing curl, etc. Explain why you chose what you chose and what you'd give up by picking the other.)

I chose python:3.11-slim over alpine because Alpine uses musl libc, which is incompatible with most pre-compiled Python wheels built against standard glibc. Using alpine would force the build stage to compile C-extensions from source, requiring heavy compiler toolchains, drastically increasing build time, and risking subtle runtime crashes. The trade-off is a slightly larger final image (~150MB vs ~50MB), but the guaranteed binary compatibility, faster builds, and easier debugging make slim the safer production choice for Python workloads.



## 7. One thing I'm still unsure about

A deeper understanding of multi build. 
