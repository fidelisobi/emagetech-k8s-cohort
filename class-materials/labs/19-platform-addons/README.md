# Lab 19 — Platform Addons: cert-manager and TLS

## Overview

cert-manager is a Kubernetes controller that automates TLS certificate management. In this lab you will:

1. Install and verify cert-manager on the cluster
2. Create a **ClusterIssuer** backed by Let's Encrypt staging
3. Request a TLS certificate using a **Certificate** resource
4. Attach the certificate to an **Ingress** resource

**Time estimate:** 40–50 minutes

---

## Prerequisites

- A running GKE cluster with kubectl configured
- A registered domain name with Cloud DNS managing it
- GCP service account with `roles/dns.admin` on project `cluster-dreams`

### Verify cert-manager is installed

```bash
kubectl get pods -n cert-manager
# Expected: cert-manager, cert-manager-cainjector, cert-manager-webhook pods Running
```

If not installed:

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml
kubectl wait --for=condition=Available deployment --all -n cert-manager --timeout=120s
```

---

## Step 1 — Create the Cloud DNS Service Account Secret

cert-manager needs permission to create DNS TXT records to prove domain ownership.

```bash
# Create a GCP service account (if not already done)
gcloud iam service-accounts create cert-manager-dns \
  --project=cluster-dreams \
  --display-name="cert-manager Cloud DNS"

# Grant DNS Admin role
gcloud projects add-iam-policy-binding cluster-dreams \
  --member="serviceAccount:cert-manager-dns@cluster-dreams.iam.gserviceaccount.com" \
  --role="roles/dns.admin"

# Create and download a key
gcloud iam service-accounts keys create /tmp/cert-manager-dns-key.json \
  --iam-account=cert-manager-dns@cluster-dreams.iam.gserviceaccount.com

# Store the key as a Kubernetes Secret in cert-manager namespace
kubectl create secret generic clouddns-sa-key \
  --from-file=key.json=/tmp/cert-manager-dns-key.json \
  -n cert-manager

# Remove the local key file
rm /tmp/cert-manager-dns-key.json
```

---

## Step 2 — Create the ClusterIssuer

```bash
kubectl apply -f 01-clusterissuer.yaml
```

Verify the issuer is ready:

```bash
kubectl get clusterissuer letsencrypt-staging
# READY column should be True

kubectl describe clusterissuer letsencrypt-staging
# Look for: Status: True, Type: Ready
```

---

## Step 3 — Request a Certificate

```bash
# Create the namespace if it doesn't exist
kubectl create namespace gateway-lab --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f 02-certificate.yaml
```

Watch the certificate being issued (this can take 1–3 minutes):

```bash
kubectl describe certificate lab-tls-cert -n gateway-lab
```

Monitor the CertificateRequest and Order objects:

```bash
kubectl get certificaterequest -n gateway-lab
kubectl get order -n gateway-lab
kubectl get challenge -n gateway-lab
```

Once issued, verify the Secret was created:

```bash
kubectl get secret lab-tls-secret -n gateway-lab
# Type should be: kubernetes.io/tls
# Data should contain: tls.crt and tls.key

# Decode and inspect the certificate
kubectl get secret lab-tls-secret -n gateway-lab \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout | grep -A5 "Subject:"
```

---

## Step 4 — Attach TLS to Ingress

```bash
kubectl apply -f 03-ingress-with-tls.yaml
```

Verify the Ingress has a TLS address:

```bash
kubectl get ingress lab-ingress -n gateway-lab
# HOSTS column should show your domains
# ADDRESS column should show the LoadBalancer IP
```

### Test HTTPS

```bash
INGRESS_IP=$(kubectl get ingress lab-ingress -n gateway-lab \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# -k skips verification because staging cert is NOT browser-trusted
curl -k -H "Host: lab.cluster-dreams.example.com" https://$INGRESS_IP/api/health

# Check the cert details
curl -kvI -H "Host: lab.cluster-dreams.example.com" https://$INGRESS_IP/api/health 2>&1 | \
  grep -E "issuer|subject|expire"
```

> The staging certificate will show "Fake LE Intermediate" as the issuer.
> This is correct for staging! Switch to `letsencrypt-prod` for browser-trusted certs.

---

## Discussion Questions

1. What is the difference between `ClusterIssuer` and `Issuer`?
2. Why do we use staging before production with Let's Encrypt?
3. What happens to existing pods when a certificate is renewed?
4. How would you use cert-manager with the Gateway API instead of Ingress?

---

## Cleanup

```bash
kubectl delete namespace gateway-lab
kubectl delete clusterissuer letsencrypt-staging
kubectl delete secret clouddns-sa-key -n cert-manager
```

---

## Key Concepts

| Resource | Scope | Purpose |
|---|---|---|
| `ClusterIssuer` | Cluster | Defines how to obtain certs (ACME, Vault, self-signed) |
| `Issuer` | Namespace | Same but namespace-scoped |
| `Certificate` | Namespace | Requests a cert and specifies the target Secret |
| `CertificateRequest` | Namespace | Auto-created by cert-manager per issuance attempt |
| `Order` / `Challenge` | Namespace | ACME protocol objects (auto-managed) |
| `tls.crt` / `tls.key` | Secret data | The actual certificate and private key |
