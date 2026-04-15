"""
Student Demo App — API Service
================================
A simple Flask REST API that demonstrates core Kubernetes concepts:

  - Environment variables (ConfigMap, Secret, Downward API)
  - Health/readiness probes
  - Prometheus metrics (custom instrumentation)
  - Database connectivity (PostgreSQL via psycopg2)

Students: look for the K8S CONCEPT comments throughout this file.
"""

import os
import time
import logging

import psycopg2
from flask import Flask, request, jsonify
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

# ---------------------------------------------------------------------------
# Logging setup — structured logs are easier to read in kubectl logs
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
log = logging.getLogger("student-app")

# ---------------------------------------------------------------------------
# Flask application
# ---------------------------------------------------------------------------
app = Flask(__name__)

# ---------------------------------------------------------------------------
# K8S CONCEPT: Downward API
# The pod can expose information about itself to the container via environment
# variables.  These are set in the Deployment manifest using fieldRef.
# See: chart/student-app/templates/deployment-api.yaml
# ---------------------------------------------------------------------------
POD_NAME      = os.getenv("POD_NAME", "unknown-pod")
POD_NAMESPACE = os.getenv("POD_NAMESPACE", "default")
NODE_NAME     = os.getenv("NODE_NAME", "unknown-node")

# ---------------------------------------------------------------------------
# K8S CONCEPT: ConfigMap + Secret
# Non-sensitive config comes from a ConfigMap; sensitive values (password)
# come from a Secret.  Both are injected as environment variables.
# ---------------------------------------------------------------------------
DB_HOST     = os.getenv("DB_HOST", "localhost")
DB_PORT     = int(os.getenv("DB_PORT", "5432"))
DB_NAME     = os.getenv("DB_NAME", "studentdb")
DB_USER     = os.getenv("DB_USER", "student")
DB_PASSWORD = os.getenv("DB_PASSWORD", "password")

APP_NAME    = os.getenv("APP_NAME", "student-app")
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")

# ---------------------------------------------------------------------------
# K8S CONCEPT: Prometheus metrics (ServiceMonitor)
# Define custom metrics here.  The /metrics endpoint exposes them and a
# ServiceMonitor CR tells Prometheus where to scrape.
# ---------------------------------------------------------------------------
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total number of HTTP requests",
    ["method", "endpoint", "status"],
)

REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "endpoint"],
    buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5],
)

ACTIVE_CONNECTIONS = Gauge(
    "http_active_connections",
    "Number of HTTP connections currently being processed",
)

DB_CONNECTION_UP = Gauge(
    "db_connection_up",
    "1 if the database connection is healthy, 0 otherwise",
)

# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------

def get_db_connection():
    """Open a new database connection.  Raises on failure."""
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        connect_timeout=3,
    )


def init_db():
    """Create the items table if it does not already exist."""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS items (
                id      SERIAL PRIMARY KEY,
                name    TEXT    NOT NULL,
                value   TEXT,
                created TIMESTAMP DEFAULT NOW()
            )
            """
        )
        conn.commit()
        cur.close()
        conn.close()
        log.info("Database initialised successfully")
        DB_CONNECTION_UP.set(1)
    except Exception as exc:
        log.warning("Database init failed (will retry on first request): %s", exc)
        DB_CONNECTION_UP.set(0)


def check_db_health():
    """Return True if the database is reachable."""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        DB_CONNECTION_UP.set(1)
        return True
    except Exception as exc:
        log.warning("DB health check failed: %s", exc)
        DB_CONNECTION_UP.set(0)
        return False


# ---------------------------------------------------------------------------
# Instrumentation middleware
# ---------------------------------------------------------------------------

@app.before_request
def before_request():
    """Record start time and increment active connection gauge."""
    request._start_time = time.time()
    ACTIVE_CONNECTIONS.inc()


@app.after_request
def after_request(response):
    """Record request metrics after each response."""
    latency = time.time() - request._start_time
    endpoint = request.path
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=endpoint,
        status=response.status_code,
    ).inc()
    REQUEST_LATENCY.labels(method=request.method, endpoint=endpoint).observe(latency)
    ACTIVE_CONNECTIONS.dec()
    return response


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.route("/")
def index():
    """
    K8S CONCEPT: Downward API demo.
    Returns info about the running pod — useful when demonstrating
    how requests are load-balanced across multiple replicas.
    """
    return jsonify(
        {
            "app": APP_NAME,
            "version": APP_VERSION,
            "pod_name": POD_NAME,          # changes with each replica
            "pod_namespace": POD_NAMESPACE,
            "node_name": NODE_NAME,        # shows which node is serving
            "message": "Hello from the student demo app!",
        }
    )


@app.route("/health")
def health():
    """
    K8S CONCEPT: Liveness probe.
    If this endpoint returns non-200 the kubelet restarts the container.
    It should only fail when the process is truly broken — NOT for
    transient issues like a database being down.
    """
    return jsonify({"status": "healthy", "pod": POD_NAME}), 200


@app.route("/ready")
def ready():
    """
    K8S CONCEPT: Readiness probe.
    If this endpoint returns non-200 the pod is removed from the Service
    endpoints — it stops receiving traffic.  Use this to signal that a
    dependency (e.g. the database) is not yet available.
    """
    if check_db_health():
        return jsonify({"status": "ready", "db": "connected"}), 200
    return jsonify({"status": "not ready", "db": "unreachable"}), 503


@app.route("/api/items", methods=["GET"])
def get_items():
    """Return all items from the database."""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT id, name, value, created FROM items ORDER BY id DESC LIMIT 100")
        rows = cur.fetchall()
        cur.close()
        conn.close()
        items = [
            {"id": r[0], "name": r[1], "value": r[2], "created": str(r[3])}
            for r in rows
        ]
        return jsonify({"items": items, "count": len(items), "served_by": POD_NAME})
    except Exception as exc:
        log.error("GET /api/items failed: %s", exc)
        return jsonify({"error": "database error", "detail": str(exc)}), 500


@app.route("/api/items", methods=["POST"])
def create_item():
    """Create a new item.  Expects JSON body: {"name": "...", "value": "..."}"""
    body = request.get_json(silent=True) or {}
    name  = body.get("name", "").strip()
    value = body.get("value", "").strip()

    if not name:
        return jsonify({"error": "name is required"}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO items (name, value) VALUES (%s, %s) RETURNING id",
            (name, value),
        )
        item_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()
        log.info("Created item id=%s name=%s", item_id, name)
        return jsonify({"id": item_id, "name": name, "value": value}), 201
    except Exception as exc:
        log.error("POST /api/items failed: %s", exc)
        return jsonify({"error": "database error", "detail": str(exc)}), 500


@app.route("/metrics")
def metrics():
    """
    K8S CONCEPT: Prometheus / ServiceMonitor.
    Exposes all registered metrics in Prometheus text format.
    The ServiceMonitor CR tells the Prometheus Operator to scrape this path.
    """
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


# ---------------------------------------------------------------------------
# Application entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    # Initialise the database schema on startup
    init_db()
    # In production we use gunicorn (see Dockerfile CMD).
    # This block is for local development only.
    app.run(host="0.0.0.0", port=5000, debug=False)
else:
    # Gunicorn calls this module as a library; still need to init the DB.
    init_db()
