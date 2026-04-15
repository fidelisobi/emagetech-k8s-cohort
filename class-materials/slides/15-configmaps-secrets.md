# Session 15 — ConfigMaps, Secrets & Environment Configuration

---

## Why Externalize Configuration?

Container apps can be configured using:
- CLI arguments (Dockerfile: `ENTRYPOINT`/`CMD` → Pod: `command`/`args`)
- Environment variables (Dockerfile: `ENV` → Pod: ConfigMaps)
- Config files (Dockerfile: `COPY` → Pod: ConfigMaps)

**Not a good idea to hardcode configurations into the container image.**

ConfigMaps and Secrets are special volumes that decouple configurations from the container/pod.

---

## ConfigMaps

> **Analogy:** A restaurant doesn't print its menu on the kitchen walls — it uses a chalkboard that can change daily. Your container is the kitchen; the ConfigMap is the chalkboard.

- A Kubernetes API object that contains a list of key/value pairs
- Pods/Containers consume data from ConfigMaps directly without interacting with the kube-api server
- Have a limit of 1 MiB

**Creation:**
```bash
kubectl create configmap <name> --from-literal=key=value       # from K/V
kubectl create configmap <name> --from-file=config.properties   # from file
kubectl create configmap <name> --from-env-file=app.env         # from env file
```

---

## ConfigMap Injection Paths

There are three ways to inject ConfigMap data into a container:

```
ConfigMap: app-config
┌──────────────────────┐
│ LOG_LEVEL=info       │
│ DB_HOST=postgres     │
│ app.properties=...   │
└──────┬───────────────┘
       │
       ├──► env (single key)     → container sees $LOG_LEVEL
       ├──► envFrom (all keys)   → container sees $LOG_LEVEL, $DB_HOST
       └──► volume mount         → container reads /config/app.properties
```

---

## ConfigMap YAML Examples

**Single key injection (`valueFrom`) vs all keys (`envFrom`) — side by side:**

```yaml
# valueFrom: inject one specific key
env:
  - name: LOG_LEVEL
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: LOG_LEVEL
```

```yaml
# envFrom: inject all keys as environment variables
envFrom:
  - configMapRef:
      name: app-config
```

**Volume mount (for file-based config):**

```yaml
volumes:
  - name: config-volume
    configMap:
      name: app-config
      items:
        - key: app.properties
          path: app.properties

containers:
  - name: my-app
    volumeMounts:
      - name: config-volume
        mountPath: /config
```

---

## Secrets

> **Analogy:** Base64 is like writing a password in Pig Latin — anyone who knows the rule can decode it in seconds. It's obfuscation, not encryption.

- Similar to ConfigMaps but stores **sensitive data only**
- Data stored is base64 encoded but **not encrypted** by default

**Secret Types:**
| Type | Description |
|------|-------------|
| `Opaque` | Generic key/value (default) |
| `kubernetes.io/tls` | TLS certificate and key |
| `kubernetes.io/dockerconfigjson` | Docker registry credentials |
| `kubernetes.io/service-account-token` | Service account token |
| `kubernetes.io/basic-auth` | Basic authentication |

---

## Secret YAML Example

**Using `data` (base64-encoded values) vs `stringData` (plaintext):**

```yaml
# Using data: you must base64-encode values yourself
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  username: YWRtaW4=        # echo -n 'admin' | base64
  password: c3VwZXJzZWNyZXQ= # echo -n 'supersecret' | base64
```

```yaml
# Using stringData: write plaintext — Kubernetes base64-encodes it for you
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  username: admin
  password: supersecret
```

> **Note:** The `stringData` field is a write-only convenience field. When you `kubectl get secret`, values always appear base64-encoded under `data`, regardless of which field you used to create the Secret.

---

## Secrets Management in Production

Base64 encoding is NOT security. For production:

- **external-secrets-operator** — syncs secrets from external stores (GCP Secret Manager, AWS Secrets Manager, Azure Key Vault, Vault) into K8s Secrets. Deep dive in Session 19.
- **Sealed Secrets** — encrypt secrets client-side, store encrypted in Git
- **SOPS** — encrypt specific fields in YAML files using KMS
- **CSI Secret Store Driver** — mount secrets directly from backends as volumes

**Best Practice:** Never commit secrets to Git, even base64-encoded.

---

## Downward API

A way to inject values from the Pod's metadata, spec, or status fields into containers.

- Referenced using `fieldRef` for pod-level fields:
  - `metadata.name`, `metadata.namespace`, `metadata.labels`, `metadata.annotations`
  - `spec.nodeName`, `spec.serviceAccountName`
  - `status.podIP`, `status.hostIP`
- Referenced using `resourceFieldRef` for container compute limits/requests:
  - `requests.cpu`, `limits.memory`, etc.

**Downward API env var example:**

```yaml
env:
  - name: MY_POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: MY_NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName
  - name: MY_CPU_LIMIT
    valueFrom:
      resourceFieldRef:
        containerName: my-app
        resource: limits.cpu
```

---

## Projected Volumes

Combines multiple volume sources into a single volume mount:
- ConfigMaps
- Secrets
- Downward API
- Service Account Tokens

Useful when you need multiple sources mounted at the same path.

```
Pod
└── /config/                  ← single mountPath
    ├── app.properties        ← from ConfigMap
    ├── db-password           ← from Secret
    └── pod-name              ← from Downward API
```

**Projected volume YAML example:**

```yaml
volumes:
  - name: combined-config
    projected:
      sources:
        - configMap:
            name: app-config
            items:
              - key: app.properties
                path: app.properties
        - secret:
            name: db-credentials
            items:
              - key: password
                path: db-password
        - downwardAPI:
            items:
              - path: pod-name
                fieldRef:
                  fieldPath: metadata.name

containers:
  - name: my-app
    volumeMounts:
      - name: combined-config
        mountPath: /config
```

---

## Immutable ConfigMaps and Secrets

- Set `immutable: true` on ConfigMap or Secret
- Once set, the data **cannot be changed** — must delete and recreate
- Benefits:
  - Protects against accidental updates
  - Reduces load on kube-apiserver (no watches needed)
- Best Practice: Use immutable ConfigMaps/Secrets and reference by unique names (e.g., with hash suffix)

---

## Key Takeaways

- **ConfigMaps** decouple non-sensitive configuration from your container image — change config without rebuilding the image.
- **Secrets** decouple sensitive data, but base64 is obfuscation, not encryption. Use an external secrets solution in production.
- The `stringData` field lets you write plaintext YAML; Kubernetes base64-encodes it for you at storage time.
- There are **three injection paths**: single env var (`valueFrom`), all env vars (`envFrom`), and file-based (`volumeMount`).
- **Projected volumes** let you combine ConfigMaps, Secrets, and Downward API data under a single mount path.
- **Downward API** lets pods be self-aware — useful for logging, tracing, and dynamic configuration.
- Set `immutable: true` on stable ConfigMaps/Secrets to protect against accidental changes and reduce API server load.
