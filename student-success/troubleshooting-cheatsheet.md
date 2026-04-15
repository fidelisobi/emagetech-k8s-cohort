# 🔧 Troubleshooting Cheat Sheet

The top 30 errors students hit in this cohort — with exact fixes.
Bookmark this. Check here before posting in Slack.

---

## Pod Issues

### 1. `ImagePullBackOff` / `ErrImagePull`
**What it means:** Kubernetes can't pull the container image.
```bash
kubectl describe pod <pod-name> | grep -A5 Events
# Look for: "Failed to pull image"
```
**Fixes:**
- Image name or tag is wrong → check spelling: `kubectl describe pod <name>`
- Registry is private → create an imagePullSecret
- Tag doesn't exist → verify on Docker Hub / GHCR

---

### 2. `CrashLoopBackOff`
**What it means:** Container starts, crashes, restarts, crashes again.
```bash
kubectl logs <pod-name> --previous   # Logs from the crashed container
kubectl describe pod <pod-name>      # Check "Last State" and exit code
```
**Common causes:**
- Wrong environment variable name (DB_HOST vs DATABASE_HOST)
- App can't connect to a dependency (database not ready yet)
- Missing required config file
- Exit code 1 = app error. Exit code 137 = OOMKilled.

---

### 3. `OOMKilled` (Exit Code 137)
**What it means:** Container used more memory than its limit allows.
```bash
kubectl describe pod <pod-name> | grep -A3 "Last State"
# OOMKilled: true
```
**Fix:** Increase memory limit or reduce memory usage
```bash
kubectl set resources deployment/<name> --limits=memory=512Mi
```

---

### 4. Pod stuck in `Pending`
**What it means:** Pod can't be scheduled onto any node.
```bash
kubectl describe pod <pod-name> | grep -A10 Events
```
**Common causes:**
- **Insufficient resources:** `0/3 nodes are available: 3 Insufficient cpu` → increase node size or reduce requests
- **Node selector mismatch:** Pod requires a label no node has
- **PVC not bound:** `pod has unbound immediate PersistentVolumeClaims` → check StorageClass

---

### 5. Pod stuck in `Terminating`
**What it means:** Pod won't die gracefully.
```bash
# Force delete
kubectl delete pod <pod-name> --force --grace-period=0
```

---

### 6. `Init:CrashLoopBackOff`
**What it means:** An init container is failing.
```bash
kubectl logs <pod-name> -c <init-container-name>
kubectl describe pod <pod-name> | grep -A5 "Init Containers"
```

---

## Service & Networking Issues

### 7. Service not routing to pods
**Symptom:** curl to Service IP times out.
```bash
# Check endpoints — empty = no pods match the selector
kubectl get endpoints <service-name>

# Compare service selector vs pod labels
kubectl get svc <service-name> -o jsonpath='{.spec.selector}'
kubectl get pods --show-labels | grep <app-label>
```
**Fix:** Label on pod must exactly match selector in Service spec.

---

### 8. DNS not resolving inside pod
**Symptom:** `nslookup my-service` fails from inside a pod.
```bash
kubectl exec -it <pod> -- nslookup kubernetes.default
kubectl exec -it <pod> -- cat /etc/resolv.conf
```
**Fixes:**
- Check CoreDNS pods: `kubectl get pods -n kube-system | grep coredns`
- NetworkPolicy may be blocking DNS (port 53 UDP) → add egress rule for DNS

---

### 9. `Connection refused` between pods
```bash
# Test connectivity from inside a pod
kubectl exec -it <source-pod> -- curl http://<service-name>:<port>

# Check if service exists
kubectl get svc <service-name>

# Check if target pod is Running and Ready
kubectl get pods -l app=<target-app>
```
**Common cause:** NetworkPolicy blocking traffic. Check: `kubectl get networkpolicies`

---

### 10. Ingress not routing / 404
```bash
kubectl describe ingress <name>
# Check: rules, backend service name, backend port

# Check Ingress controller is running
kubectl get pods -n ingress-nginx

# Verify service exists and has endpoints
kubectl get svc <backend-service>
kubectl get endpoints <backend-service>
```
**Common cause:** `ingressClassName` in Ingress doesn't match installed controller.

---

## Deployment & Rollout Issues

### 11. Rollout stuck / not progressing
```bash
kubectl rollout status deployment/<name>
kubectl describe deployment/<name> | grep -A5 Conditions
kubectl get pods -l app=<name>
```
**Common cause:** New pods failing readiness probe — old pods not removed. Fix the readiness probe.

---

### 12. `kubectl apply` showing no changes but deployment not updating
**Cause:** Image tag is still `:latest` or the same tag — Kubernetes doesn't re-pull.
**Fix:** Always change the image tag on deploy. Use `imagePullPolicy: Always` for dev only.

---

### 13. HPA showing `<unknown>` for metrics
```bash
kubectl get hpa
# TARGETS: <unknown>/50%

# Check metrics-server
kubectl top nodes
kubectl get pods -n kube-system | grep metrics-server
```
**Fix:** metrics-server not running or deployment has no CPU `requests` defined.

---

## Storage Issues

### 14. PVC stuck in `Pending`
```bash
kubectl describe pvc <pvc-name>
# Look for: "no persistent volumes available" or "storageclass not found"

kubectl get storageclass
```
**Fix:** Either no StorageClass exists, or the named StorageClass doesn't match.

---

### 15. `ReadOnlyFileSystem` error in pod
**Cause:** `readOnlyRootFilesystem: true` in securityContext.
**Fix:** Mount a writable volume at the path your app writes to:
```yaml
volumeMounts:
  - name: tmp
    mountPath: /tmp
volumes:
  - name: tmp
    emptyDir: {}
```

---

## RBAC Issues

### 16. `Error from server (Forbidden)`
```bash
# What permissions do you have?
kubectl auth can-i --list

# Check what a specific ServiceAccount can do
kubectl auth can-i get pods --as system:serviceaccount:<namespace>:<sa-name>
```
**Fix:** Add the required verb/resource to the Role or ClusterRole.

---

### 17. ServiceAccount can't access the Kubernetes API
```bash
kubectl describe pod <pod-name> | grep -i serviceaccount
kubectl get rolebinding,clusterrolebinding -A | grep <sa-name>
```

---

## Helm Issues

### 18. `helm install` fails with "resource already exists"
```bash
# Check if resources were manually created before helm
kubectl get all -n <namespace>

# Option 1: Delete conflicting resources
# Option 2: Use --force flag
# Option 3: Adopt existing resources
helm install <name> <chart> --set controller.existingResource=true
```

---

### 19. `helm upgrade` not applying changes
```bash
# Check helm history
helm history <release-name> -n <namespace>

# Force replace
helm upgrade <name> <chart> --force -n <namespace>

# Check rendered templates
helm template <name> <chart> -f values.yaml
```

---

### 20. Helm chart values not taking effect
```bash
# Verify values were passed
helm get values <release-name> -n <namespace>

# Check the actual template output
helm template <release> <chart> -f my-values.yaml | grep <field>
```

---

## ArgoCD Issues

### 21. App stuck `OutOfSync` after syncing
```bash
argocd app diff <app-name>
```
**Common cause:** Runtime-added labels/annotations differ from Git. Add them to the Git manifest or use `ignoreDifferences`.

---

### 22. ArgoCD can't access private GitHub repo
```bash
argocd repo list
# Check: ConnectionState — should be Successful

# Re-add repo with credentials
argocd repo add https://github.com/YOUR_ORG/repo \
  --username <user> --password <token>
```

---

### 23. Self-heal not working
**Check:** `syncPolicy.automated.selfHeal: true` must be set in the Application spec.
Also check for sync windows blocking automation: `argocd app get <name> | grep SyncWindow`

---

## Kyverno / Policy Issues

### 24. All pod creations blocked after applying a policy
```bash
# Check which policy is blocking
kubectl get events | grep kyverno

# Check Kyverno pods are healthy
kubectl get pods -n kyverno
```
**Fix:** If Kyverno pods are down, the webhook blocks everything. Add `failurePolicy: Ignore` to non-critical policies.

---

### 25. Policy in Enforce mode blocking system pods
**Fix:** Always add exclusions for system namespaces:
```yaml
exclude:
  any:
    - resources:
        namespaces: [kube-system, kyverno, argocd, monitoring]
```

---

## Cluster-Level Issues

### 26. `kubectl` command hangs / no response
```bash
# Check API server
kubectl cluster-info

# Check if etcd is healthy (kubeadm)
ETCDCTL_API=3 etcdctl endpoint health --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

---

### 27. Node showing `NotReady`
```bash
kubectl describe node <node-name> | grep -A10 Conditions
# Check: KubeletNotReady, NetworkPlugin, DiskPressure, MemoryPressure

# SSH to node and check kubelet
sudo systemctl status kubelet
sudo journalctl -u kubelet -f --since "5 minutes ago"
```

---

### 28. `metrics-server` not working on kind/k3d
```bash
# Patch to allow insecure kubelet TLS
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

---

## Local Cluster Issues

### 29. `kind` cluster not starting
```bash
kind delete cluster
kind create cluster --config kind-config.yaml

# Check Docker is running
docker info
```

---

### 30. Port-forward keeps disconnecting
**Cause:** kubectl port-forward has no built-in reconnect.
**Fix:** Use a loop:
```bash
while true; do
  kubectl port-forward svc/argocd-server -n argocd 8080:443
  echo "Port-forward dropped, reconnecting in 2s..."
  sleep 2
done
```

---

## Still Stuck?

1. **Search the error message** in the Kubernetes docs: https://kubernetes.io/docs/
2. **Post in Slack** with: what you ran, the full error output, what you've already tried
3. **Come to office hours** — TAs can debug in real time

The rule: **30 minutes stuck = post in Slack**. Don't lose a full day to something a 5-minute conversation would solve.
