# Lab 04: Images — Layers, Tags, Registries

## Overview

You'll build a first image, inspect its layers and digest, tag and retag it, push it to a
registry, and experiment with multi-arch images.

**Estimated time:** 45 minutes

**Prerequisites:**

- Docker installed and working
- A free [Docker Hub](https://hub.docker.com) **or** [GitHub](https://github.com) account
  (for pushing to GHCR)
- `jq` installed

---

## Part 1: Build Your First Image

### 1.1 Create a tiny app

```bash
mkdir -p ~/docker-lab-04 && cd ~/docker-lab-04

cat > app.py <<'EOF'
import http.server, socketserver, os
PORT = int(os.environ.get("PORT", 8000))
MSG = os.environ.get("MSG", "hello from docker")

class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers()
        self.wfile.write(f"{MSG}\n".encode())
    def log_message(self, *a, **kw): pass

with socketserver.TCPServer(("", PORT), H) as s:
    print(f"listening on {PORT}", flush=True); s.serve_forever()
EOF

cat > Dockerfile <<'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY app.py .
EXPOSE 8000
CMD ["python", "app.py"]
EOF
```

### 1.2 Build

```bash
docker image build -t myapp:0.1 .
docker image ls myapp
```

### 1.3 Run

```bash
docker container run -d --name myapp -p 8000:8000 myapp:0.1
curl http://localhost:8000
docker container rm -f myapp
```

---

## Part 2: Layers, Digests, Tags

### 2.1 Layer history

```bash
docker image history myapp:0.1
```

Each row = a layer. Note the size column.

### 2.2 Full manifest

```bash
docker image inspect myapp:0.1 | jq '.[0] | {Id, RepoTags, Size, RootFS, Config: .Config | {Cmd, Entrypoint, Env, ExposedPorts}}'
```

### 2.3 Tag, retag, examine digest

```bash
docker image tag myapp:0.1 myapp:latest
docker image tag myapp:0.1 myapp:v1.0.0

docker image ls myapp                                   # three tags, same IMAGE ID
docker image ls --digests myapp
```

`IMAGE ID` is the local content digest — all three tags point to the same bytes.

---

## Part 3: Layer Caching & Rebuild Speed

### 3.1 A change that hits the cache

Rebuild without touching anything:

```bash
time docker image build -t myapp:0.1 .
```

Every layer should be a cache hit — sub-second build.

### 3.2 A change that invalidates the cache

```bash
# Edit app.py
sed -i.bak 's/hello from docker/hello again/' app.py

time docker image build -t myapp:0.2 .
```

Layers above `COPY app.py .` rebuild; the `FROM` and `WORKDIR` layers remain cached.

### 3.3 Reorder for better caching

Write a new Dockerfile that installs a Python package, with bad vs good layer order:

```bash
cat > Dockerfile.bad <<'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install --no-cache-dir requests
CMD ["python", "app.py"]
EOF

cat > Dockerfile.good <<'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir requests
COPY . .
CMD ["python", "app.py"]
EOF

docker image build -f Dockerfile.bad  -t myapp:bad .
docker image build -f Dockerfile.good -t myapp:good .

# Now tweak app.py and rebuild both — watch which cache still holds
echo "# touch" >> app.py
time docker image build -f Dockerfile.bad  -t myapp:bad .
time docker image build -f Dockerfile.good -t myapp:good .
```

> **Question:** Why does the "good" Dockerfile skip the pip install on the second build
> but the "bad" one does not?

---

## Part 4: `.dockerignore`

### 4.1 Blow up the build context

```bash
mkdir big && dd if=/dev/urandom of=big/noise.bin bs=1M count=50 status=none
docker image build -t myapp:0.3 . 2>&1 | grep -i "transferring context"
```

### 4.2 Ignore it

```bash
cat > .dockerignore <<'EOF'
big/
*.bak
.git
EOF

docker image build -t myapp:0.3 . 2>&1 | grep -i "transferring context"
```

Confirm the second build sends a much smaller context.

### 4.3 Clean up

```bash
rm -rf big Dockerfile.bad Dockerfile.good app.py.bak
```

---

## Part 5: Tagging Strategies

### 5.1 Semver + Git SHA

```bash
# Pretend we're in a git repo; fake a short SHA
SHA=$(date +%s | sha1sum | cut -c1-7)
docker image tag myapp:0.2 myapp:1.0.0
docker image tag myapp:0.2 myapp:1.0.0-$SHA
docker image tag myapp:0.2 myapp:stable
docker image ls myapp
```

### 5.2 Pin to a digest

```bash
DIGEST=$(docker image inspect myapp:1.0.0 --format '{{.Id}}')
echo "The immutable identifier is $DIGEST"
```

In a production manifest or Kubernetes Pod spec, you'd reference `myapp@sha256:…` to
guarantee byte-for-byte identical deploys.

---

## Part 6: Push to a Registry

Choose either Docker Hub **or** GitHub Container Registry. Both are free for public images.

### 6.1 Option A — Docker Hub

```bash
docker login                                    # username + access token

USER=<your-dockerhub-username>
docker image tag myapp:1.0.0 $USER/myapp:1.0.0
docker image push $USER/myapp:1.0.0

# Pull it back from a clean cache
docker image rm $USER/myapp:1.0.0
docker image pull $USER/myapp:1.0.0
```

### 6.2 Option B — GHCR

```bash
# Create a classic PAT with 'write:packages' scope at github.com/settings/tokens
echo $GHCR_TOKEN | docker login ghcr.io -u <your-github-username> --password-stdin

USER=<your-github-username>
docker image tag myapp:1.0.0 ghcr.io/$USER/myapp:1.0.0
docker image push ghcr.io/$USER/myapp:1.0.0
```

### 6.3 Inspect what's in the registry

```bash
docker manifest inspect $USER/myapp:1.0.0 | jq
```

You'll see the manifest, layer digests, and any platform info.

---

## Part 7: Pulling by Digest

### 7.1 Lock a specific digest

```bash
DIGEST=$(docker image inspect $USER/myapp:1.0.0 --format '{{index .RepoDigests 0}}')
echo "pinned reference: $DIGEST"

docker image rm $USER/myapp:1.0.0
docker image pull $DIGEST
```

### 7.2 Prove tags are mutable, digests are not

Push a new build under the same tag:

```bash
sed -i.bak 's/hello again/hello three/' app.py
docker image build -t $USER/myapp:1.0.0 .
docker image push $USER/myapp:1.0.0

# The digest you captured earlier still works and still returns the OLD image
docker image pull $DIGEST
docker container run --rm $DIGEST cat /app/app.py | grep MSG
```

> **Question:** Why is this important for production deploys?

---

## Part 8: Multi-Architecture Builds (Optional)

Requires `docker buildx`, which ships with Docker Desktop 19.03+ and modern Docker Engine.

### 8.1 One-time setup

```bash
docker buildx create --name multi --use
docker buildx inspect --bootstrap
```

### 8.2 Build for amd64 + arm64 and push

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t $USER/myapp:multi \
  --push .
```

### 8.3 Verify the manifest list

```bash
docker manifest inspect $USER/myapp:multi | jq '.manifests[] | {platform, digest}'
```

You should see two entries — one per architecture. A user pulling on Apple Silicon gets
arm64 bytes; a user on x86 gets amd64 bytes; the tag is the same.

---

## Clean Up

```bash
docker container rm -f $(docker container ls -aq) 2>/dev/null
docker image rm $(docker image ls myapp -q) 2>/dev/null
rm -rf ~/docker-lab-04
```

---

## Summary

After completing this lab you should be able to:

- Write a minimal Dockerfile and `docker build` an image
- Read `docker image history` to understand what each layer costs
- Explain why bad layer ordering destroys build cache, and demonstrate a fix
- Use `.dockerignore` to keep the build context tight
- Tag images with semver, SHAs, and registry prefixes; pin to digests
- `docker push` and `docker pull` against Docker Hub or GHCR
- Build and push **multi-arch** images with `docker buildx`

---

## Stretch Goals

1. Build the same app twice — once from `python:3.11-slim`, once from `python:3.11-alpine`.
   Compare final sizes, CVE counts (`trivy image`), and any subtle runtime differences.
2. Use `docker manifest inspect` on `nginx:1.25` to see how many architectures the upstream
   ship. Pick one and pull by its per-arch digest explicitly.
3. Turn on **BuildKit cache export** (`--cache-to`, `--cache-from` with `type=registry`)
   and run a CI-style cold build — see how long it takes vs a warm build.
