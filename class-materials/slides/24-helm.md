# Session 24 — Helm

---

## Helm Overview

Helm — an open source tool for packaging and deploying Kubernetes applications. Often referred to as the **Kubernetes Package Manager**.

**Benefits:**
- Abstracting the complexity of Kubernetes resources
- Maintaining an ongoing history of revisions
- Configuring declarative resources in a dynamic fashion
- Simplifying local and live state synchronization
- Deploying resources in an intelligent order
- Providing automated lifecycle hooks

---

## Terminologies

| Term | Description |
|------|-------------|
| **Chart** | A Helm package. Contains all resource definitions for a K8s application |
| **Repository** | A place where Helm charts are stored and shared |
| **Release** | An instance of a chart running in a cluster. Namespaced object |
| **Values file** | YAML file containing the default Helm chart configuration |
| **Helm CLI** | CLI for end-users |

Helm installs charts into Kubernetes, creating a new release for each installation.

**Analogy:** Think of Helm like `apt` (or `brew`) for Kubernetes — repo = apt source, chart = package, release = installed instance, values = config flags. `helm install redis bitnami/redis` is like `apt install redis` but for Kubernetes.

**Helm Roles:**
- **Chart User** — configures and installs helm releases
- **Chart Developer** — creates helm charts to be used by users

---

## Charts - Finding & Installing

**Finding Charts:**
```bash
helm search hub <keyword>        # search Artifact Hub
helm search repo <keyword>       # search added repos
```

**Installing a Chart:**
```bash
helm install <release_name> <repo>/<chart>
```

Example:
```bash
helm install my-redis bitnami/redis
```

- Follows a specific order when installing resources

**Idempotent install/upgrade (preferred in CI/CD):**
```bash
helm upgrade --install <release> <repo>/<chart> -f values.yaml
```

`--install` creates the release if it does not exist, upgrades it if it does — safe to run repeatedly in pipelines without checking state first.

**Customizing Before Install:**
```bash
helm show values <chart>                                    # view defaults
helm install <release> <repo>/<chart> -f custom-values.yaml        # override with file
helm install <release> <repo>/<chart> --set key=value              # override inline
```

**Upgrade / Rollback:**
```bash
helm upgrade <release> <repo>/<chart>  # upgrade a release
helm rollback <release> <revision>     # rollback to revision
```

---

## Repositories

```bash
helm repo add <repo_name> <url>         # add a repo
helm repo list                          # list repos
helm repo update                        # update repo index
helm search repo <repo_name>            # search charts
helm search repo <repo_name> --versions # show all versions
```

---

## Releases

```bash
helm list -n <namespace>       # list releases in namespace
helm list -A                   # list all releases
helm status <release>          # release status
helm get hooks <release>       # show hooks
helm get manifest <release>    # show rendered manifests
helm get notes <release>       # show release notes
helm get values <release>      # show user-supplied values
helm get all <release>         # show everything
```

---

## Chart Scaffolding

```bash
helm create <chart_name>
```

**Directory Structure:**
```
mychart/
├── Chart.yaml          # Chart metadata (name, version, dependencies)
├── values.yaml         # Default configuration values
├── charts/             # Chart dependencies
├── templates/          # Templated Kubernetes manifests (YAML)
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── _helpers.tpl    # Template helpers/partials
│   ├── NOTES.txt       # Usage instructions after install
│   └── tests/
└── .helmignore         # Files to omit from packaging
```

---

## Chart Render Pipeline

When you run `helm install` or `helm template`, Helm combines your values with the templates and renders plain Kubernetes YAML:

```
values.yaml + templates/*.yaml
          │
          ▼
    helm template (Go templating engine)
          │
          ▼
    Rendered Kubernetes YAML
          │
          ▼
    kubectl apply (to cluster)
```

You can inspect the rendered output before applying with:
```bash
helm template <release> <repo>/<chart> -f values.yaml
```

---

## Dependencies

```bash
helm dependency list <chart>     # list dependencies
helm dependency update <chart>   # download dependencies
helm dependency build <chart>    # rebuild charts/ directory
```

Dependencies are defined in `Chart.yaml`:
```yaml
dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
```

---

## Templates

Used to dynamically generate Kubernetes YAML. Templating engine: **Go (Helm) Template**.

Syntax: begins with `{{` and ends with `}}`

**Built-In Objects:**

| Object | Description |
|--------|-------------|
| `.Values` | Access values in `values.yaml` |
| `.Release` | Release metadata (name, namespace, revision) |
| `.Chart` | Chart metadata (name, version) |
| `.Files` | Access arbitrary files in chart directory |
| `.Capabilities` | Info about the Kubernetes cluster |
| `.` | The root object |

**Common Functions:**
```yaml
{{ .Values.image.repository }}           # access values
{{ include "mychart.fullname" . }}       # include a template
{{ range .Values.env }}                  # loop
{{ if .Values.ingress.enabled }}         # conditional
{{ default "nginx" .Values.image }}      # default value
{{ toYaml .Values.resources | nindent 4 }}  # YAML formatting
```

**Real Template Example — `templates/deployment.yaml`:**

`values.yaml`:
```yaml
image:
  repository: myregistry.io/my-app
  tag: "1.4.2"

replicaCount: 3

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

`templates/deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "mychart.fullname" . }}
  labels:
    app: {{ include "mychart.fullname" . }}
    chart: {{ .Chart.Name }}-{{ .Chart.Version }}
    release: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "mychart.fullname" . }}
  template:
    metadata:
      labels:
        app: {{ include "mychart.fullname" . }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: 8080
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

The `include "mychart.fullname" .` call invokes the helper defined in `_helpers.tpl`, which typically returns `<release-name>-<chart-name>` — keeping resource names unique per release.

---

## Lifecycle Hooks

Helm releases go through multiple phases: install, upgrade, rollback, delete.

| Hook | When It Runs |
|------|-------------|
| `pre-install` | After templates rendered, before resources created |
| `post-install` | After all resources created |
| `pre-delete` | Before any resources deleted |
| `post-delete` | After all resources deleted |
| `pre-upgrade` | After templates rendered, before resources updated |
| `post-upgrade` | After all resources upgraded |
| `pre-rollback` | After templates rendered, before rollback |
| `post-rollback` | After all resources rolled back |

Hooks are regular Kubernetes resources with the annotation:
```yaml
"helm.sh/hook": pre-install
```

---

## Helmfile (Declarative Helm Management)

- Declare multiple Helm releases in a single file
- Manage releases across environments (dev, staging, prod)
- Supports: diffs, sync, apply, destroy
- Alternative to running many `helm install/upgrade` commands

```yaml
# helmfile.yaml
releases:
  - name: cert-manager
    namespace: cert-manager
    chart: jetstack/cert-manager
    version: v1.14.0
    values:
      - values/cert-manager.yaml
  - name: external-dns
    namespace: external-dns
    chart: kubernetes-sigs/external-dns
    values:
      - values/external-dns.yaml
```

---

## Key Takeaways

- Helm is the standard Kubernetes package manager — a chart bundles all manifests, a release is one running instance, and values let you customize without forking the chart.
- The correct install syntax is `helm install <release> <repo>/<chart>` — repo prefix comes before the chart name, not after.
- Use `helm upgrade --install` in CI/CD pipelines — it is idempotent (install on first run, upgrade on subsequent runs) and avoids checking whether a release already exists.
- `helm template` lets you preview the fully-rendered Kubernetes YAML before applying anything to the cluster — invaluable for debugging templates.
- The Go template `include "mychart.fullname" .` pattern keeps resource names scoped to the release, allowing multiple instances of the same chart in the same cluster.
- Helmfile is the GitOps-friendly layer on top of Helm — declare all your releases in one file and manage them as a unit.

---

## Review Questions

### Beginner

1. What is the difference between a Helm chart, a release, and a repository? Use an analogy if it helps.
2. What command would you run to see the default configuration values for a chart before installing it?
3. What does `helm upgrade --install` do, and why is it preferred over `helm install` in CI/CD pipelines?
4. What is the purpose of the `_helpers.tpl` file in a Helm chart, and what does the `include "mychart.fullname" .` pattern typically produce?
5. Describe the Helm chart render pipeline: what inputs go in, what processing happens, and what comes out at the end?

### Intermediate

1. You have installed a Helm chart and a subsequent upgrade has broken the application. Walk through the commands you would use to investigate the release history, inspect what changed in the failing revision, and roll back to a known-good state.
2. A colleague suggests using `--set` flags in a deploy script to override ten different chart values. Explain two reasons why a `values.yaml` file is a better approach, and describe how you would structure the override file for a multi-environment setup (dev, staging, prod).
