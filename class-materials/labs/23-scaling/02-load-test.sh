#!/usr/bin/env bash
# ============================================================
# Lab 23 — Scaling: Load Generator
# ============================================================
# This script spins up a temporary busybox pod in the cluster
# and uses it to hammer the php-apache service with HTTP
# requests in a tight loop.
#
# The increased CPU usage will trigger the HPA to scale up
# the php-apache deployment.
#
# Usage:
#   chmod +x 02-load-test.sh
#   ./02-load-test.sh            # run with defaults
#   ./02-load-test.sh --stop     # delete the load-generator pod
#
# Watch HPA respond (open a separate terminal):
#   kubectl get hpa php-apache-hpa -n scaling-lab -w
#
# Watch pods being created (open another terminal):
#   kubectl get pods -n scaling-lab -w
# ============================================================

set -euo pipefail

NAMESPACE="scaling-lab"
SERVICE="php-apache"
POD_NAME="load-generator"

# --- Handle --stop flag ------------------------------------
if [[ "${1:-}" == "--stop" ]]; then
  echo "Stopping load generator..."
  kubectl delete pod "$POD_NAME" -n "$NAMESPACE" --ignore-not-found
  echo "Load generator stopped."
  echo ""
  echo "Note: HPA will take ~5 minutes to scale back down (stabilizationWindowSeconds=300)"
  exit 0
fi

# --- Safety check: ensure namespace exists -----------------
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  echo "ERROR: Namespace '$NAMESPACE' not found."
  echo "Apply the lab setup first: kubectl apply -f 01-hpa.yaml"
  exit 1
fi

# --- Confirm the target service is reachable ---------------
echo "Checking that $SERVICE service exists in $NAMESPACE..."
kubectl get service "$SERVICE" -n "$NAMESPACE" || {
  echo "ERROR: Service $SERVICE not found in namespace $NAMESPACE"
  exit 1
}

# --- Delete any existing load-generator pod ---------------
kubectl delete pod "$POD_NAME" -n "$NAMESPACE" --ignore-not-found
sleep 2

# --- Start the load generator ------------------------------
echo ""
echo "Starting load generator pod: $POD_NAME"
echo "Target: http://$SERVICE.$NAMESPACE.svc.cluster.local"
echo ""
echo "Press Ctrl+C to stop watching (pod continues running)."
echo "Run with --stop to terminate the pod and let HPA scale down."
echo ""

kubectl run "$POD_NAME" \
  --namespace="$NAMESPACE" \
  --image=busybox:1.36 \
  --restart=Never \
  --command -- /bin/sh -c \
    "while true; do
       wget -q -O- http://${SERVICE}.${NAMESPACE}.svc.cluster.local > /dev/null 2>&1
     done"

echo ""
echo "Load generator pod started. Tailing its logs..."
echo "(The pod prints nothing — it is sending silent wget requests)"
echo ""

# --- Watch HPA in real time ---------------------------------
echo "============================================"
echo " Watching HPA — may take 1-2 min to react"
echo "============================================"
kubectl get hpa php-apache-hpa -n "$NAMESPACE" -w &
HPA_WATCH_PID=$!

# Also watch pod count
echo ""
echo "Watching pod count..."
kubectl get pods -n "$NAMESPACE" -l app=php-apache -w &
POD_WATCH_PID=$!

# Wait for user to press Ctrl+C
trap "kill $HPA_WATCH_PID $POD_WATCH_PID 2>/dev/null; echo ''; echo 'Stopped watching. Load generator is still running.'; echo 'Run: ./02-load-test.sh --stop  to clean up.'" INT
wait $HPA_WATCH_PID $POD_WATCH_PID
