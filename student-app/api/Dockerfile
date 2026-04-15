# =============================================================================
# K8S CONCEPT: Multi-stage Docker build
# Stage 1 (builder) installs dependencies and compiles any C extensions.
# Stage 2 (runtime) copies only what is needed — no build tools in the final
# image.  This reduces image size and attack surface.
# =============================================================================

# ---- Stage 1: builder -------------------------------------------------------
FROM python:3.12-slim AS builder

WORKDIR /app

# Copy only the requirements file first so Docker can cache this layer.
# If requirements.txt does not change, pip install is skipped on rebuild.
COPY requirements.txt .

RUN pip install --upgrade pip \
 && pip install --no-cache-dir --prefix=/install -r requirements.txt


# ---- Stage 2: runtime -------------------------------------------------------
FROM python:3.12-slim AS runtime

# K8S CONCEPT: Non-root user
# Running as a non-root user is a Kubernetes security best-practice and is
# often enforced by PodSecurityAdmission (restricted policy).
RUN groupadd --gid 1001 appgroup \
 && useradd  --uid 1001 --gid appgroup --no-create-home appuser

WORKDIR /app

# Copy installed packages from the builder stage
COPY --from=builder /install /usr/local

# Copy application source
COPY app.py .

# Drop to non-root user before the process starts
USER appuser

# Expose the port — documentation only; does not actually publish the port.
# The Kubernetes Service definition controls external accessibility.
EXPOSE 5000

# K8S CONCEPT: Health / readiness probes
# Gunicorn starts the Flask app.  The kubelet will probe /health and /ready
# via HTTP — those routes are defined in app.py.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "30", "app:app"]
