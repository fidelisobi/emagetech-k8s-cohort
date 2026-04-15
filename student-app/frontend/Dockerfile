# =============================================================================
# Frontend — static HTML served by Nginx
#
# K8S CONCEPT: Separation of concerns
# The frontend is a completely separate Deployment and Service from the API.
# They scale independently and can be updated independently.
# =============================================================================

FROM nginx:1.27-alpine

# K8S CONCEPT: Non-root user (where possible)
# Nginx needs port 80 which requires root, so we run on port 8080 instead.
# The Service definition maps port 80 -> 8080 on the container.
# If your cluster enforces runAsNonRoot you would use port 8080 here.
# For simplicity this demo uses the default nginx user approach.

# Copy our custom nginx configuration (demonstrates ConfigMap-style config)
COPY nginx.conf /etc/nginx/nginx.conf

# Copy the static frontend file
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

# Nginx writes its pid to /var/run which the default user owns.
# The default CMD from the base image works fine here.
