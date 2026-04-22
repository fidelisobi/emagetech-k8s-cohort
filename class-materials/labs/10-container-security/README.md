# Lab 10: Container Security — Scan, Sign, Harden

## Overview

You'll scan an image with Trivy, generate an SBOM with Syft, sign the image with Cosign,
harden a Dockerfile (distroless, non-root, read-only), and run a container with the
full recommended defensive flags.

**Estimated time:** 60 minutes

**Prerequisites:**

- Docker installed and working
- Internet access (to pull images and public keys)
- Homebrew / apt for installing Trivy, Syft, Cosign

---

## Part 1: Install the Toolchain

### 1.1 Trivy

```bash
# macOS
brew install aquasecurity/trivy/trivy

# Debian/Ubuntu
sudo apt-get install wget gnupg lsb-release -y
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo gpg --dearmor -o /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update && sudo apt-get install trivy -y
```

### 1.2 Syft & Grype

```bash
# macOS
brew install syft grype

# Linux
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin
```

### 1.3 Cosign

```bash
# macOS
brew install cosign

# Linux
curl -sLO https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
sudo install -m 0755 cosign-linux-amd64 /usr/local/bin/cosign && rm cosign-linux-amd64
```

Verify:

```bash
trivy --version
syft version
grype version
cosign version
```

---

## Part 2: Scan an Image

### 2.1 Scan an outdated base

```bash
docker image pull python:3.9
trivy image --severity HIGH,CRITICAL python:3.9 | head -40
```

You'll see dozens of known CVEs — this is why you don't use EOL base images.

### 2.2 Scan a modern base

```bash
docker image pull python:3.11-slim
trivy image --severity HIGH,CRITICAL python:3.11-slim | head -40
```

Usually a much shorter list.

### 2.3 Fail CI on serious CVEs

```bash
trivy image \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  --ignore-unfixed \
  python:3.11-slim
echo "Trivy exit: $?"
```

`--ignore-unfixed` is common — if no fix is published yet, nothing you can do, so don't
block CI.

### 2.4 Allowlist known-and-assessed CVEs

```bash
cat > .trivyignore <<EOF
# Reviewed — not exploitable because we don't use XYZ
CVE-2024-0000
EOF

trivy image --severity HIGH,CRITICAL --exit-code 1 python:3.11-slim
rm .trivyignore
```

### 2.5 Bonus — scan a filesystem or a Dockerfile

```bash
mkdir -p /tmp/lab10 && cd /tmp/lab10
cat > Dockerfile <<'EOF'
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y curl
EOF

trivy config .                      # misconfig checks
trivy fs .                          # all files: deps, secrets, etc.
```

---

## Part 3: Generate an SBOM

```bash
cd /tmp/lab10

syft python:3.11-slim -o spdx-json > sbom.spdx.json
syft python:3.11-slim -o cyclonedx-json > sbom.cdx.json

# Inspect
jq '.packages | length' sbom.spdx.json    # package count
jq '.components | length' sbom.cdx.json

# Grype consumes an SBOM directly — no need to rescan the image
grype sbom:./sbom.spdx.json | head -20
```

> **Why separate SBOM + scan?** You archive the SBOM at build time (small, stable). When a
> new CVE drops, you re-scan the SBOM, not every image in the fleet.

---

## Part 4: Harden a Dockerfile

Start with a sloppy Dockerfile:

```bash
cat > Dockerfile.bad <<'EOF'
FROM python:3.11
WORKDIR /app
COPY . .
RUN pip install flask
EXPOSE 8080
CMD ["python", "app.py"]
EOF

cat > app.py <<'EOF'
from flask import Flask
app = Flask(__name__)
@app.get("/") 
def hello(): return "hello\n"
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
EOF

docker image build -f Dockerfile.bad -t hello:bad .
docker image ls hello:bad
trivy image --severity HIGH,CRITICAL hello:bad | head
```

Now a hardened version:

```bash
cat > requirements.txt <<'EOF'
flask==3.0.3
gunicorn==22.0.0
EOF

cat > Dockerfile <<'EOF'
# syntax=docker/dockerfile:1.7

FROM python:3.11-slim AS build
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user --no-cache-dir -r requirements.txt

FROM python:3.11-slim AS runtime
WORKDIR /app
RUN useradd --create-home --uid 1000 app \
 && mkdir /app/tmp && chown -R app /app
COPY --from=build /root/.local /home/app/.local
ENV PATH=/home/app/.local/bin:$PATH
COPY app.py .
USER app
EXPOSE 8080
CMD ["gunicorn", "-b", "0.0.0.0:8080", "app:app"]
EOF

docker image build -t hello:good .
docker image ls hello
trivy image --severity HIGH,CRITICAL hello:good | head
```

Compare:

- Size — `hello:good` much smaller than `hello:bad`
- CVEs — fewer (slim base) and no `python:3.11` full image
- Root user — `hello:good` runs as UID 1000

---

## Part 5: Run With Defensive Flags

```bash
docker container rm -f hello 2>/dev/null

docker container run -d --name hello \
  --read-only \
  --tmpfs /tmp:size=32m,noexec,nosuid \
  --cap-drop=ALL \
  --security-opt no-new-privileges \
  --memory=256m --cpus=1 \
  --pids-limit=200 \
  -p 8080:8080 \
  hello:good

curl http://localhost:8080

# Verify the defences
docker container exec hello id
# uid=1000(app)
docker container exec hello sh -c 'touch /forbidden' 2>&1 || echo "read-only: blocked"
docker container exec hello sh -c 'apk add curl 2>/dev/null; touch /tmp/ok; echo ok'

docker container rm -f hello
```

Zero persistent write surface, non-root, no new privileges, cap-dropped, resource-limited.

---

## Part 6: Sign & Verify With Cosign

### 6.1 Push the image

Pick a registry you can push to (Docker Hub, GHCR). For a quick local test, use a local
registry:

```bash
docker container run -d --name registry -p 5000:5000 registry:2
docker image tag hello:good localhost:5000/hello:good
docker image push localhost:5000/hello:good
```

### 6.2 Key-based signing

```bash
cosign generate-key-pair            # creates cosign.key + cosign.pub (password prompt)

cosign sign --key cosign.key localhost:5000/hello:good
# For the local registry, Cosign will ask you to press 'y' for "allow insecure"
```

### 6.3 Verify

```bash
cosign verify --key cosign.pub localhost:5000/hello:good | head
```

### 6.4 Tamper → verify fails

```bash
# Push a different image under the same tag
docker image pull alpine:3.19
docker image tag alpine:3.19 localhost:5000/hello:good
docker image push localhost:5000/hello:good

cosign verify --key cosign.pub localhost:5000/hello:good \
  && echo "UNEXPECTED: verify passed" \
  || echo "verify failed as expected"
```

### 6.5 Clean up

```bash
docker container rm -f registry
rm cosign.key cosign.pub
```

> **Keyless signing:** in CI (GitHub Actions, GCB) you can skip keys entirely — Cosign
> gets a short-lived certificate from Fulcio tied to your OIDC identity, and the signature
> records "this image was built by workflow X at commit Y at time T." That's the modern
> pattern.

---

## Part 7: Docker Bench (Optional, Linux)

A CIS Docker Benchmark runner.

```bash
docker container run --rm --net host --pid host --userns host --cap-add audit_control \
  -v /etc:/etc:ro \
  -v /var/lib:/var/lib:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  docker/docker-bench-security | tee bench.txt | head -40
```

Review [WARN] and [INFO] entries. Not everything is achievable on a cloud-managed host
(e.g., audit configs on the Docker Desktop VM) — use as guidance, not a pass/fail.

---

## Part 8: Detect Misuse at Runtime (Preview)

A quick taste of Falco, without a full install. (Production installs come in Session 28.)

```bash
# Run Falco briefly in its own container — may take a minute to load rules
docker container run --rm --name falco \
  --privileged \
  -v /var/run/docker.sock:/host/var/run/docker.sock \
  -v /proc:/host/proc:ro \
  -v /dev:/host/dev \
  -v /etc:/host/etc:ro \
  falcosecurity/falco-no-driver:latest 2>&1 | head -30 &
FALCO_PID=$!

sleep 5
# Do something suspicious
docker container run --rm alpine sh -c 'apk add --quiet net-tools 2>/dev/null; netstat -an' >/dev/null || true

sleep 2
kill $FALCO_PID 2>/dev/null
```

Falco watches syscalls and fires alerts on rule matches. In Kubernetes (Session 28) it
becomes a DaemonSet feeding alerts into a SIEM.

---

## Clean Up

```bash
docker container rm -f $(docker container ls -aq) 2>/dev/null
docker image rm hello:bad hello:good localhost:5000/hello:good 2>/dev/null
cd ~ && rm -rf /tmp/lab10
```

---

## Summary

After completing this lab you should be able to:

- Scan an image for CVEs with **Trivy** and fail CI on HIGH/CRITICAL findings
- Generate an **SBOM** with Syft and re-scan it with Grype
- Harden a Dockerfile: pinned slim base, multi-stage, non-root, minimal copy
- Run a container with **read-only rootfs, tmpfs, cap-drop ALL, no-new-privileges,
  resource limits**
- Sign an image with **Cosign** and verify it; observe that verification fails when the
  bytes change
- Name the pieces of a modern supply-chain pipeline: scan → SBOM → sign → verify → runtime
  detection

---

## Stretch Goals

1. Wire Trivy and Cosign into a GitHub Actions workflow that builds, scans, and signs every
   image on merge. Use keyless signing with the `sigstore/cosign-installer` action.
2. Rewrite `hello:good` on a **distroless** base (`gcr.io/distroless/python3-debian12`) and
   rerun Trivy. How does the CVE count change?
3. Use [Kyverno's `verifyImages` rule](https://kyverno.io/docs/writing-policies/verify-images/)
   (Session 28 preview) to write a Kubernetes policy that rejects unsigned images in a
   namespace. You don't need to deploy it yet — draft the YAML.
