# Session 21b — Workload Identity: Cloud IAM for Kubernetes

---

## The Problem

Pods often need to access cloud APIs — reading from a storage bucket, pulling secrets from a vault, publishing to a message queue. The traditional approach: create a cloud service account key, store it as a Kubernetes Secret, and mount it in the pod.

**Why that's dangerous:**
- Static JSON key files are long-lived credentials — if leaked, an attacker has access until you rotate
- Keys stored in K8s Secrets are base64-encoded, not encrypted
- Rotation is manual and error-prone
- Keys can be copied out of the cluster and used from anywhere

> **Analogy:** Giving every employee a physical copy of the office master key. If anyone loses their copy, you have to change every lock. Workload Identity is like a badge system — the badge only works at the front door, it's tied to one person, and you can revoke it instantly.

---

## The Solution: Workload Identity

Workload Identity eliminates static credentials by **federating Kubernetes ServiceAccounts with cloud IAM**. The pod authenticates to cloud APIs using a short-lived token issued by the Kubernetes API server — no keys to store, rotate, or leak.

```
┌─────────────────────────────────────────────────────┐
│                   Without Workload Identity          │
│                                                     │
│  Cloud IAM SA ──► JSON key ──► K8s Secret ──► Pod   │
│                   (static, long-lived, dangerous)    │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                   With Workload Identity             │
│                                                     │
│  Cloud IAM SA ◄──► OIDC Federation ◄──► K8s SA ──► Pod │
│                   (short-lived tokens, no keys)      │
└─────────────────────────────────────────────────────┘
```

**How it works (all providers):**
1. Kubernetes API server issues a **ServiceAccount token** (a signed JWT)
2. The cloud provider trusts this token via **OIDC federation**
3. The pod exchanges the JWT for a short-lived cloud credential
4. The cloud credential expires and is automatically refreshed — no static keys

---

## GKE Workload Identity

GKE Workload Identity is the recommended way for GKE workloads to access Google Cloud APIs.

### Architecture

```
┌──────────────────────────────────┐
│  GKE Cluster                     │
│                                  │
│  Pod                             │
│  ├── K8s ServiceAccount          │
│  │   (annotated)                 │
│  └── GKE metadata server        │
│      (intercepts metadata calls) │
└──────────┬───────────────────────┘
           │ OIDC token exchange
           ▼
┌──────────────────────────────────┐
│  Google Cloud IAM                │
│                                  │
│  GCP Service Account             │
│  ├── roles/storage.objectViewer  │
│  └── roles/secretmanager.accessor│
└──────────────────────────────────┘
```

### Setup Steps

**1. Enable Workload Identity on the GKE cluster:**
```bash
# At cluster creation
gcloud container clusters create my-cluster \
  --workload-pool=PROJECT_ID.svc.id.goog

# On an existing cluster
gcloud container clusters update my-cluster \
  --workload-pool=PROJECT_ID.svc.id.goog

# On a specific node pool
gcloud container node-pools update my-pool \
  --cluster=my-cluster \
  --workload-metadata=GKE_METADATA
```

**2. Create a Google Cloud Service Account:**
```bash
gcloud iam service-accounts create my-app-sa \
  --display-name="My App Service Account"
```

**3. Grant the GCP SA the permissions it needs:**
```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:my-app-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```

**4. Create a Kubernetes ServiceAccount and annotate it:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: production
  annotations:
    iam.gke.io/gcp-service-account: my-app-sa@PROJECT_ID.iam.gserviceaccount.com
```

**5. Bind the K8s SA to the GCP SA (allow impersonation):**
```bash
gcloud iam service-accounts add-iam-policy-binding \
  my-app-sa@PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:PROJECT_ID.svc.id.goog[production/my-app]"
```

The format is: `serviceAccount:PROJECT.svc.id.goog[NAMESPACE/KSA_NAME]`

**6. Use the ServiceAccount in your Pod/Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: production
spec:
  template:
    spec:
      serviceAccountName: my-app       # references the annotated SA
      containers:
        - name: my-app
          image: my-app:latest
          # No env vars, no mounted keys — authentication is automatic
```

### How it works under the hood

- GKE runs a metadata server on each node that intercepts calls to `169.254.169.254`
- When your app uses a Google Cloud SDK (e.g., `google-cloud-storage` Python library), it calls the metadata server
- The metadata server exchanges the K8s SA token for a GCP access token
- The GCP access token has the permissions of the GCP Service Account
- Tokens are short-lived (1 hour) and automatically refreshed

### Verification

```bash
# Verify the binding
kubectl run test --rm -it \
  --image=google/cloud-sdk:slim \
  --serviceaccount=my-app \
  --namespace=production \
  -- gcloud auth list

# Should show: my-app-sa@PROJECT_ID.iam.gserviceaccount.com
```

---

## AWS IRSA (IAM Roles for Service Accounts)

IRSA is the original EKS mechanism for mapping Kubernetes ServiceAccounts to AWS IAM Roles. It works on any EKS cluster version.

### Architecture

```
┌──────────────────────────────────┐
│  EKS Cluster                     │
│                                  │
│  Pod                             │
│  ├── K8s ServiceAccount          │
│  │   (annotated with role ARN)   │
│  └── Projected SA token          │
│      (JWT signed by OIDC issuer) │
└──────────┬───────────────────────┘
           │ STS AssumeRoleWithWebIdentity
           ▼
┌──────────────────────────────────┐
│  AWS IAM                         │
│                                  │
│  IAM Role                        │
│  ├── s3:GetObject                │
│  └── secretsmanager:GetSecret    │
│                                  │
│  Trust policy: OIDC provider     │
└──────────────────────────────────┘
```

### Setup Steps

**1. Create an OIDC provider for your EKS cluster:**
```bash
eksctl utils associate-iam-oidc-provider \
  --cluster my-cluster \
  --approve
```

**2. Create an IAM Role with a trust policy for the OIDC provider:**
```bash
eksctl create iamserviceaccount \
  --name my-app \
  --namespace production \
  --cluster my-cluster \
  --role-name my-app-role \
  --attach-policy-arn arn:aws:iam::ACCOUNT_ID:policy/MyAppPolicy \
  --approve
```

This creates both the IAM Role (with OIDC trust policy) and the Kubernetes ServiceAccount (with the annotation).

**Or manually — create the IAM Role trust policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/oidc.eks.REGION.amazonaws.com/id/OIDC_ID"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:sub": "system:serviceaccount:production:my-app",
          "oidc.eks.REGION.amazonaws.com/id/OIDC_ID:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

**3. Create and annotate the Kubernetes ServiceAccount:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: production
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/my-app-role
```

**4. Use in your Deployment:**
```yaml
spec:
  template:
    spec:
      serviceAccountName: my-app
      containers:
        - name: my-app
          image: my-app:latest
          # AWS SDK automatically discovers the role via env vars injected by EKS
```

### How it works under the hood

- EKS injects two environment variables into the pod:
  - `AWS_ROLE_ARN` — the IAM role to assume
  - `AWS_WEB_IDENTITY_TOKEN_FILE` — path to the projected SA token (JWT)
- AWS SDKs detect these variables automatically
- The SDK calls `sts:AssumeRoleWithWebIdentity` with the JWT
- AWS STS validates the JWT against the OIDC provider and returns temporary credentials
- Credentials are short-lived (default 1 hour) and auto-refreshed

---

## AWS EKS Pod Identity (Newer Alternative)

EKS Pod Identity is a simpler alternative to IRSA, available on EKS clusters running Kubernetes 1.24+. It eliminates the need for OIDC provider configuration and complex trust policies.

### Key Differences from IRSA

| Aspect | IRSA | Pod Identity |
|--------|------|-------------|
| OIDC provider required | Yes | No |
| Trust policy per SA | Yes (complex JSON) | No (managed by EKS) |
| Cross-account support | Manual trust policy | Built-in |
| Setup complexity | Higher | Lower |
| Annotation | `eks.amazonaws.com/role-arn` | Not needed |
| Agent required | No | Yes (Pod Identity Agent) |

### Setup Steps

**1. Install the Pod Identity Agent add-on:**
```bash
aws eks create-addon \
  --cluster-name my-cluster \
  --addon-name eks-pod-identity-agent
```

**2. Create an IAM Role with the Pod Identity trust policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }
  ]
}
```

**3. Create the Pod Identity association:**
```bash
aws eks create-pod-identity-association \
  --cluster-name my-cluster \
  --namespace production \
  --service-account my-app \
  --role-arn arn:aws:iam::ACCOUNT_ID:role/my-app-role
```

**4. Create a plain ServiceAccount (no annotation needed):**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: production
```

The Pod Identity Agent handles the credential injection — AWS SDKs discover it automatically.

---

## AKS Workload Identity

AKS Workload Identity uses Azure AD federated credentials to map Kubernetes ServiceAccounts to Azure Managed Identities.

### Architecture

```
┌──────────────────────────────────┐
│  AKS Cluster                     │
│                                  │
│  Pod                             │
│  ├── K8s ServiceAccount          │
│  │   (annotated + labeled)       │
│  └── Projected SA token          │
│      (JWT from OIDC issuer)      │
└──────────┬───────────────────────┘
           │ Azure AD token exchange
           ▼
┌──────────────────────────────────┐
│  Azure AD                        │
│                                  │
│  User-Assigned Managed Identity  │
│  ├── Storage Blob Data Reader    │
│  └── Key Vault Secrets User     │
│                                  │
│  Federated Identity Credential   │
│  (trusts the AKS OIDC issuer)    │
└──────────────────────────────────┘
```

### Setup Steps

**1. Enable Workload Identity on the AKS cluster:**
```bash
az aks update \
  --resource-group my-rg \
  --name my-cluster \
  --enable-oidc-issuer \
  --enable-workload-identity
```

**2. Get the OIDC issuer URL:**
```bash
export AKS_OIDC_ISSUER=$(az aks show \
  --resource-group my-rg \
  --name my-cluster \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)
```

**3. Create a User-Assigned Managed Identity:**
```bash
az identity create \
  --name my-app-identity \
  --resource-group my-rg
```

**4. Assign Azure roles to the Managed Identity:**
```bash
az role assignment create \
  --assignee MANAGED_IDENTITY_CLIENT_ID \
  --role "Storage Blob Data Reader" \
  --scope /subscriptions/SUB_ID/resourceGroups/my-rg/providers/Microsoft.Storage/storageAccounts/mystorageaccount
```

**5. Create a Federated Identity Credential:**
```bash
az identity federated-credential create \
  --name my-app-federated \
  --identity-name my-app-identity \
  --resource-group my-rg \
  --issuer $AKS_OIDC_ISSUER \
  --subject system:serviceaccount:production:my-app \
  --audience api://AzureADTokenExchange
```

**6. Create and annotate the Kubernetes ServiceAccount:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: production
  annotations:
    azure.workload.identity/client-id: MANAGED_IDENTITY_CLIENT_ID
  labels:
    azure.workload.identity/use: "true"
```

**7. Use in your Deployment:**
```yaml
spec:
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"    # required label on the pod
    spec:
      serviceAccountName: my-app
      containers:
        - name: my-app
          image: my-app:latest
```

### How it works under the hood

- The Workload Identity webhook injects environment variables:
  - `AZURE_CLIENT_ID` — the Managed Identity client ID
  - `AZURE_TENANT_ID` — the Azure AD tenant
  - `AZURE_FEDERATED_TOKEN_FILE` — path to the projected SA token
- Azure SDKs use these to request an Azure AD token via federated credential exchange
- Tokens are short-lived and auto-refreshed

---

## Cross-Provider Comparison

| Feature | GKE Workload Identity | AWS IRSA | AWS Pod Identity | AKS Workload Identity |
|---------|----------------------|----------|-----------------|----------------------|
| Cloud identity type | GCP Service Account | IAM Role | IAM Role | Managed Identity |
| Federation mechanism | GKE metadata server | OIDC + STS | Pod Identity Agent | OIDC + Azure AD |
| K8s SA annotation | `iam.gke.io/gcp-service-account` | `eks.amazonaws.com/role-arn` | None | `azure.workload.identity/client-id` |
| OIDC provider setup | Automatic | Manual | Not needed | Automatic with flag |
| Trust policy | IAM binding | JSON trust policy | Managed association | Federated credential |
| Setup complexity | Low | Medium | Low | Medium |
| Token lifetime | 1 hour | 1 hour (configurable) | 1 hour | 1 hour |

---

## Best Practices

1. **Never use static keys** — Workload Identity should be the default for all new workloads
2. **One SA per workload** — don't share ServiceAccounts across unrelated apps (least privilege)
3. **Scope permissions tightly** — grant the minimum IAM role/permissions the workload needs
4. **Audit bindings regularly** — review which K8s SAs are mapped to which cloud identities
5. **Use `automountServiceAccountToken: false`** on pods that don't need cloud access
6. **Terraform the bindings** — IAM-to-K8s-SA bindings should be in IaC, not manual CLI commands

---

## Common Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `403 Forbidden` from cloud API | Missing IAM role/permission | Check role bindings with `gcloud`/`aws`/`az` |
| `could not assume role` (AWS) | OIDC trust policy mismatch | Verify `sub` claim matches `system:serviceaccount:NS:SA` |
| Pod uses default SA | `serviceAccountName` not set in pod spec | Add `serviceAccountName` to the Deployment template |
| Token file not found | Workload Identity not enabled on cluster/node pool | Enable the feature on the cluster and node pool |
| `metadata server not available` (GKE) | Node pool missing `GKE_METADATA` workload metadata | Update node pool with `--workload-metadata=GKE_METADATA` |

---

## Key Takeaways

- **Workload Identity eliminates static credentials** — no more JSON keys, access keys, or client secrets stored in K8s Secrets.
- All three cloud providers use the same core mechanism: **OIDC federation** between the K8s API server and the cloud IAM system.
- The pattern is always: **K8s ServiceAccount → annotation → cloud identity → IAM permissions**.
- AWS offers two options: **IRSA** (works everywhere, more complex) and **Pod Identity** (simpler, requires agent add-on).
- **Least privilege matters** — one ServiceAccount per workload, scoped to the minimum permissions needed.
- Workload Identity integrates naturally with other platform add-ons: external-secrets-operator, external-dns, and cert-manager all use it to authenticate to cloud APIs (Session 19).

---

## Review Questions

### Beginner

1. What is the main security risk of storing a cloud service account JSON key file as a Kubernetes Secret?
2. What underlying protocol does Workload Identity use to federate a Kubernetes ServiceAccount with a cloud IAM identity across all three providers (GKE, EKS, AKS)?
3. On GKE, what annotation do you add to a Kubernetes ServiceAccount to link it to a GCP Service Account?
4. What is the difference between AWS IRSA and AWS EKS Pod Identity in terms of setup complexity and what each requires?
5. What is the recommended token lifetime for Workload Identity credentials, and why is this preferable to long-lived static keys?

### Intermediate

1. A pod running on GKE is returning a `403 Forbidden` error when calling the GCS API, even though the correct annotation is on the Kubernetes ServiceAccount. Walk through the checklist of things you would verify to diagnose the root cause, referencing the specific GKE setup steps.
2. Your organization uses Terraform to manage infrastructure. Why is it considered a best practice to Terraform the IAM-to-ServiceAccount bindings for Workload Identity rather than running the `gcloud`/`aws`/`az` CLI commands manually? What risks does the manual approach introduce at scale?
