# Student Demo App

A simple multi-tier web application used throughout the Kubernetes training course.
The app is intentionally straightforward — its purpose is to be a vehicle for
learning Kubernetes concepts, not to demonstrate advanced application development.

## Architecture

```
Browser
  |
  v
[Frontend Service]  (ClusterIP / LoadBalancer)
  |
  v
[Nginx Pod]         serves static HTML, proxies /api/* to the API service
  |
  v  (Kubernetes DNS: student-app-api -> ClusterIP)
[API Service]       (ClusterIP)
  |
  v
[Flask/Gunicorn Pod(s)]    reads/writes items, exposes /metrics
  |
  v
[PostgreSQL Service]       (ClusterIP, managed by bitnami sub-chart)
  |
  v
[PostgreSQL Pod]    stores items, backed by a PersistentVolumeClaim
```

## Kubernetes Concepts Covered

| Concept | Where demonstrated |
|---|---|
| Deployment | `templates/deployment-api.yaml`, `templates/deployment-frontend.yaml` |
| Service (ClusterIP) | `templates/service-api.yaml`, `templates/service-frontend.yaml` |
| ConfigMap | `templates/configmap.yaml`, env vars in Deployment |
| Secret | `templates/secret.yaml`, env vars in Deployment |
| Downward API | `POD_NAME`, `POD_NAMESPACE`, `NODE_NAME` env vars in Deployment |
| Liveness probe | `api/app.py` `/health`, Deployment `livenessProbe` |
| Readiness probe | `api/app.py` `/ready`, Deployment `readinessProbe` |
| Resource requests/limits | `values.yaml` `resources` blocks |
| HPA | `templates/hpa.yaml` |
| ServiceMonitor | `templates/servicemonitor.yaml` |
| PersistentVolumeClaim | bitnami/postgresql sub-chart |
| Helm sub-chart | `Chart.yaml` dependencies |
| Rolling update | Deployment `strategy` |
| Non-root container | Dockerfile, `securityContext` in Deployment |

## Directory Structure

```
student-app/
├── api/
│   ├── app.py              # Flask REST API
│   ├── requirements.txt
│   └── Dockerfile          # Multi-stage, non-root
├── frontend/
│   ├── index.html          # Single-page UI
│   ├── nginx.conf          # Proxy config (service discovery demo)
│   └── Dockerfile
├── chart/
│   └── student-app/
│       ├── Chart.yaml      # Chart metadata + PostgreSQL dependency
│       ├── values.yaml     # Default values (well-commented)
│       ├── values-dev.yaml # Dev overrides
│       └── templates/
│           ├── _helpers.tpl
│           ├── configmap.yaml
│           ├── secret.yaml
│           ├── deployment-api.yaml
│           ├── deployment-frontend.yaml
│           ├── service-api.yaml
│           ├── service-frontend.yaml
│           ├── hpa.yaml
│           └── servicemonitor.yaml
└── README.md               # This file
```

## Prerequisites

- Docker and Docker Compose (to build and run locally)
- A Kubernetes cluster (GKE, Minikube, or kind) — for Helm deployment
- `kubectl` configured to talk to the cluster
- Helm 3.x

---

## Running Locally with Docker

### Option 1: Docker Compose (Recommended)

The fastest way to get the full stack running locally — one command starts the API, frontend, and PostgreSQL:

```bash
# Start everything (builds images on first run)
docker compose up -d

# Verify all services are healthy
docker compose ps

# Open in browser
open http://localhost:8080
```

**What's running:**

| Service | Port | URL |
|---------|------|-----|
| Frontend (Nginx) | 8080 | http://localhost:8080 |
| API (Flask) | 5000 | http://localhost:5000 |
| PostgreSQL | 5432 | `psql -h localhost -U student -d studentdb` |

**Useful commands:**
```bash
# Follow API logs (watch requests come in)
docker compose logs -f api

# Follow all logs
docker compose logs -f

# Restart just the API after code changes
docker compose restart api

# Rebuild after Dockerfile or requirements.txt changes
docker compose up -d --build

# Stop everything
docker compose down

# Stop and delete the database volume (fresh start)
docker compose down -v
```

**Test the API directly:**
```bash
# Health check
curl http://localhost:5000/health

# Readiness check (verifies DB connection)
curl http://localhost:5000/ready

# App info (Downward API demo — shows pod/node name)
curl http://localhost:5000/

# List items
curl http://localhost:5000/api/items

# Create an item
curl -X POST http://localhost:5000/api/items \
  -H "Content-Type: application/json" \
  -d '{"name": "my-first-item", "value": "hello world"}'

# Prometheus metrics
curl http://localhost:5000/metrics
```

### Option 2: Docker Run (Individual Containers)

Run each container separately — useful for understanding how multi-container apps work before learning Docker Compose.

**Step 1: Create a Docker network** (so containers can talk to each other by name):
```bash
docker network create student-app-net
```

**Step 2: Start PostgreSQL:**
```bash
docker run -d \
  --name db \
  --network student-app-net \
  -e POSTGRES_DB=studentdb \
  -e POSTGRES_USER=student \
  -e POSTGRES_PASSWORD=password \
  -p 5432:5432 \
  postgres:16-alpine
```

**Step 3: Build and start the API:**
```bash
docker build -t student-app-api:1.0.0 api/

docker run -d \
  --name api \
  --network student-app-net \
  -e DB_HOST=db \
  -e DB_PORT=5432 \
  -e DB_NAME=studentdb \
  -e DB_USER=student \
  -e DB_PASSWORD=password \
  -e APP_NAME=student-app \
  -e POD_NAME=api-docker \
  -e POD_NAMESPACE=local \
  -e NODE_NAME=localhost \
  -p 5000:5000 \
  student-app-api:1.0.0
```

**Step 4: Build and start the frontend:**
```bash
docker build -t student-app-frontend:1.0.0 frontend/

docker run -d \
  --name frontend \
  --network student-app-net \
  -v $(pwd)/nginx-compose.conf:/etc/nginx/nginx.conf:ro \
  -p 8080:80 \
  student-app-frontend:1.0.0
```

**Step 5: Verify everything works:**
```bash
# Check all containers are running
docker ps

# Test the API
curl http://localhost:5000/health

# Test the frontend (proxies to API)
curl http://localhost:8080/pod-info

# Open in browser
open http://localhost:8080
```

**Cleanup:**
```bash
docker stop frontend api db
docker rm frontend api db
docker network rm student-app-net
```

### Docker Concepts Demonstrated

| Concept | Where |
|---------|-------|
| Multi-stage build | `api/Dockerfile` (builder → runtime stages) |
| Non-root user | `api/Dockerfile` (uid 1001) |
| Layer caching | `api/Dockerfile` (COPY requirements.txt before source) |
| Environment variables | `docker run -e` / `docker-compose.yml environment:` |
| Docker networks | `docker network create` / Compose default network |
| Service discovery (DNS) | Containers reach each other by name (`db`, `api`) |
| Volume persistence | `docker-compose.yml volumes:` / `docker run -v` |
| Health checks | `docker-compose.yml healthcheck:` |
| Port mapping | `-p 8080:80` maps host:container |
| Bind mounts | `nginx-compose.conf` mounted as volume override |

---

## Deploying to Kubernetes with Helm

### 1. Build and push Docker images

```bash
# Build the images
docker build -t student-app-api:1.0.0 api/
docker build -t student-app-frontend:1.0.0 frontend/
```

If you are using GKE, push the images to Artifact Registry:

```bash
# Authenticate
gcloud auth configure-docker us-central1-docker.pkg.dev

# Tag and push (replace PROJECT_ID and REGION)
docker tag student-app-api:1.0.0       us-central1-docker.pkg.dev/PROJECT_ID/student-app/api:1.0.0
docker tag student-app-frontend:1.0.0  us-central1-docker.pkg.dev/PROJECT_ID/student-app/frontend:1.0.0
docker push us-central1-docker.pkg.dev/PROJECT_ID/student-app/api:1.0.0
docker push us-central1-docker.pkg.dev/PROJECT_ID/student-app/frontend:1.0.0
```

### 2. Fetch the PostgreSQL sub-chart (Helm dependency)

```bash
helm dependency update chart/student-app
```

### 3. Install the chart (dev environment)

```bash
helm upgrade --install student-app chart/student-app \
  --namespace student-app --create-namespace \
  -f chart/student-app/values.yaml \
  -f chart/student-app/values-dev.yaml \
  --set api.image.repository=us-central1-docker.pkg.dev/PROJECT_ID/student-app/api \
  --set frontend.image.repository=us-central1-docker.pkg.dev/PROJECT_ID/student-app/frontend
```

### 4. Verify the deployment

```bash
# Watch pods come up
kubectl get pods -n student-app -w

# Check all resources
kubectl get all -n student-app

# Check HPA status
kubectl get hpa -n student-app
```

### 5. Access the application

```bash
# Port-forward the frontend to your local machine
kubectl port-forward svc/student-app-frontend -n student-app 8080:80

# Open http://localhost:8080 in your browser
```

Or expose via LoadBalancer (GKE):

```bash
kubectl patch svc student-app-frontend -n student-app \
  -p '{"spec":{"type":"LoadBalancer"}}'

# Wait for the external IP
kubectl get svc student-app-frontend -n student-app -w
```

## Lab Exercises

### Lab 1 — Observe Liveness & Readiness Probes

```bash
# Watch probe events
kubectl describe pod -l app.kubernetes.io/name=student-app-api -n student-app

# Get the readiness check manually
kubectl exec -it <api-pod> -n student-app -- wget -qO- http://localhost:5000/ready
```

### Lab 2 — Downward API (Load Balancing)

Open the frontend in your browser and keep refreshing.
Watch the "Pod Name" and "Node" fields change as requests are sent to different replicas.

```bash
# Also try from the command line
for i in $(seq 1 10); do
  kubectl exec -it <any-pod> -- wget -qO- http://student-app-api/
done
```

### Lab 3 — Scale the API

```bash
# Manual scale
kubectl scale deployment student-app-api -n student-app --replicas=4

# Observe the HPA (if enabled)
kubectl get hpa -n student-app -w
```

### Lab 4 — Inspect ConfigMap and Secret

```bash
# See the non-sensitive config
kubectl get configmap student-app-config -n student-app -o yaml

# See the base64-encoded secret values
kubectl get secret student-app-secret -n student-app -o yaml

# Decode a value
kubectl get secret student-app-secret -n student-app \
  -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
```

### Lab 5 — Rolling Update

```bash
# Update the API image tag to trigger a rolling update
helm upgrade student-app chart/student-app -n student-app \
  --set api.image.tag=1.1.0

# Watch pods roll over
kubectl get pods -n student-app -w
```

### Lab 6 — HPA under load

```bash
# Generate load
kubectl run -it --rm load-gen --image=busybox -n student-app -- \
  sh -c "while true; do wget -q -O- http://student-app-api/api/items; done"

# In another terminal, watch the HPA scale up
kubectl get hpa -n student-app -w
```

## Cleanup

```bash
helm uninstall student-app -n student-app
kubectl delete namespace student-app
```
