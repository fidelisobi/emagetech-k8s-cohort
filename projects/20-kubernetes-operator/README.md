# Project 20 — Write a Kubernetes Operator

> 🔴 **Senior Track** | 👥 Team (2–3) | ⏱ 8–10 hours
> **Seniority Path:** This is the most technically differentiating project in the cohort. Building an Operator means you understand Kubernetes from the inside — controllers, reconciliation loops, CRDs. This separates K8s users from K8s platform builders.

---

## Overview

Build a custom **Kubernetes Operator** that watches a `DatabaseCluster` Custom Resource Definition (CRD) and automatically provisions a StatefulSet + headless Service + backup CronJob whenever the resource is applied. When the resource is deleted, everything is cleaned up. You'll use Python with the `kopf` framework so the focus stays on Kubernetes concepts, not language complexity.

**Why this matters:** Every major Kubernetes tool — ArgoCD, Prometheus Operator, cert-manager, Vault, Istio — is an Operator. Understanding how they work internally means you can debug them, extend them, and build your own. A "I wrote a Kubernetes Operator" on a resume immediately signals senior-level capability.

## Architecture

```mermaid
graph TD
    USER[kubectl apply -f db-cluster.yaml] --> API[Kubernetes API Server]
    API -->|stores| ETCD[etcd]
    API -->|event| CTRL[DatabaseCluster Operator<br/>Python + kopf]
    CTRL -->|creates| STS[StatefulSet: postgres-{name}]
    CTRL -->|creates| SVC[Service: postgres-{name}]
    CTRL -->|creates| CJ[CronJob: backup-{name}]
    CTRL -->|updates| STATUS[CR Status: phase=Ready]
    
    subgraph Custom Resource
        CR[DatabaseCluster CR<br/>name: prod-db<br/>replicas: 3<br/>version: 15]
    end
```

## Learning Objectives
- Understand Custom Resource Definitions (CRDs)
- Learn the reconciliation loop pattern (desired state vs actual state)
- Write an operator using kopf (Python)
- Handle create, update, and delete events
- Update CR status subresource
- Package and deploy an Operator as a Deployment

---

## Step 1 — Define the CRD

```yaml
# crd-databasecluster.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databaseclusters.emagetech.io
spec:
  group: emagetech.io
  names:
    kind: DatabaseCluster
    plural: databaseclusters
    singular: databasecluster
    shortNames: [dbc]
  scope: Namespaced
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: [replicas, version, storageSize]
              properties:
                replicas:
                  type: integer
                  minimum: 1
                  maximum: 5
                version:
                  type: string
                  enum: ["14", "15", "16"]
                storageSize:
                  type: string
                  pattern: '^[0-9]+(Gi|Mi)$'
                backupEnabled:
                  type: boolean
                  default: true
                backupSchedule:
                  type: string
                  default: "0 2 * * *"
            status:
              type: object
              properties:
                phase:
                  type: string
                readyReplicas:
                  type: integer
                message:
                  type: string
      subresources:
        status: {}    # Enable status subresource for separate status updates
      additionalPrinterColumns:
        - name: Replicas
          type: integer
          jsonPath: .spec.replicas
        - name: Version
          type: string
          jsonPath: .spec.version
        - name: Phase
          type: string
          jsonPath: .status.phase
        - name: Age
          type: date
          jsonPath: .metadata.creationTimestamp
```

```bash
kubectl apply -f crd-databasecluster.yaml
kubectl get crd databaseclusters.emagetech.io

# Verify the CRD is registered
kubectl api-resources | grep emagetech
# databaseclusters   dbc   emagetech.io/v1   true   DatabaseCluster
```

---

## Step 2 — Write the Operator (Python + kopf)

```python
# operator.py
import kopf
import kubernetes
import logging

kubernetes.config.load_incluster_config()    # When running inside the cluster
# kubernetes.config.load_kube_config()       # When running locally for dev

apps_v1 = kubernetes.client.AppsV1Api()
core_v1 = kubernetes.client.CoreV1Api()
batch_v1 = kubernetes.client.BatchV1Api()


@kopf.on.create('databaseclusters')
def create_database(spec, name, namespace, logger, patch, **kwargs):
    """Called when a DatabaseCluster CR is created."""
    
    replicas   = spec['replicas']
    version    = spec['version']
    storage    = spec['storageSize']
    backup_on  = spec.get('backupEnabled', True)
    backup_sch = spec.get('backupSchedule', '0 2 * * *')

    logger.info(f"Creating DatabaseCluster {name} — postgres:{version} x{replicas}")

    # Update status: Provisioning
    patch.status['phase'] = 'Provisioning'
    patch.status['message'] = 'Creating StatefulSet...'

    # 1. Create headless Service
    service = kubernetes.client.V1Service(
        metadata=kubernetes.client.V1ObjectMeta(
            name=f"postgres-{name}",
            namespace=namespace,
            labels={"app": f"postgres-{name}", "managed-by": "databasecluster-operator"},
            owner_references=[_owner_ref(name, kwargs['body'])]
        ),
        spec=kubernetes.client.V1ServiceSpec(
            cluster_ip="None",          # Headless
            selector={"app": f"postgres-{name}"},
            ports=[kubernetes.client.V1ServicePort(port=5432, name="postgres")]
        )
    )
    core_v1.create_namespaced_service(namespace, service)
    logger.info(f"Service postgres-{name} created")

    # 2. Create StatefulSet
    statefulset = _build_statefulset(name, namespace, version, replicas, storage, kwargs['body'])
    apps_v1.create_namespaced_stateful_set(namespace, statefulset)
    logger.info(f"StatefulSet postgres-{name} created")

    # 3. Create backup CronJob (if enabled)
    if backup_on:
        cronjob = _build_backup_cronjob(name, namespace, backup_sch, kwargs['body'])
        batch_v1.create_namespaced_cron_job(namespace, cronjob)
        logger.info(f"Backup CronJob for {name} created")

    # Update status: Ready
    patch.status['phase'] = 'Ready'
    patch.status['readyReplicas'] = 0
    patch.status['message'] = f"StatefulSet {name} provisioned with {replicas} replicas"


@kopf.on.update('databaseclusters')
def update_database(spec, name, namespace, old, new, logger, **kwargs):
    """Called when a DatabaseCluster CR is updated."""
    
    old_replicas = old['spec']['replicas']
    new_replicas = new['spec']['replicas']

    if old_replicas != new_replicas:
        logger.info(f"Scaling {name}: {old_replicas} → {new_replicas}")
        apps_v1.patch_namespaced_stateful_set(
            name=f"postgres-{name}",
            namespace=namespace,
            body={"spec": {"replicas": new_replicas}}
        )


@kopf.on.delete('databaseclusters')
def delete_database(name, namespace, logger, **kwargs):
    """Called when a DatabaseCluster CR is deleted.
    Owner references handle cascade deletion automatically —
    all child resources are deleted when the CR is deleted.
    """
    logger.info(f"DatabaseCluster {name} deleted — child resources will be garbage collected")


def _owner_ref(cr_name, body):
    """Generate an ownerReference so child resources are deleted with the CR."""
    return kubernetes.client.V1OwnerReference(
        api_version="emagetech.io/v1",
        kind="DatabaseCluster",
        name=cr_name,
        uid=body['metadata']['uid'],
        block_owner_deletion=True,
        controller=True
    )


def _build_statefulset(name, namespace, version, replicas, storage, body):
    labels = {"app": f"postgres-{name}"}
    return kubernetes.client.V1StatefulSet(
        metadata=kubernetes.client.V1ObjectMeta(
            name=f"postgres-{name}",
            namespace=namespace,
            labels={**labels, "managed-by": "databasecluster-operator"},
            owner_references=[_owner_ref(name, body)]
        ),
        spec=kubernetes.client.V1StatefulSetSpec(
            service_name=f"postgres-{name}",
            replicas=replicas,
            selector=kubernetes.client.V1LabelSelector(match_labels=labels),
            template=kubernetes.client.V1PodTemplateSpec(
                metadata=kubernetes.client.V1ObjectMeta(labels=labels),
                spec=kubernetes.client.V1PodSpec(containers=[
                    kubernetes.client.V1Container(
                        name="postgres",
                        image=f"postgres:{version}-alpine",
                        ports=[kubernetes.client.V1ContainerPort(container_port=5432)],
                        env=[
                            kubernetes.client.V1EnvVar(name="POSTGRES_DB", value="appdb"),
                            kubernetes.client.V1EnvVar(name="POSTGRES_PASSWORD", value="changeme"),
                            kubernetes.client.V1EnvVar(name="PGDATA", value="/var/lib/postgresql/data/pgdata"),
                        ],
                        resources=kubernetes.client.V1ResourceRequirements(
                            requests={"cpu": "250m", "memory": "256Mi"},
                            limits={"cpu": "1", "memory": "1Gi"}
                        ),
                        volume_mounts=[kubernetes.client.V1VolumeMount(
                            name="data", mount_path="/var/lib/postgresql/data"
                        )]
                    )
                ])
            ),
            volume_claim_templates=[
                kubernetes.client.V1PersistentVolumeClaim(
                    metadata=kubernetes.client.V1ObjectMeta(name="data"),
                    spec=kubernetes.client.V1PersistentVolumeClaimSpec(
                        access_modes=["ReadWriteOnce"],
                        resources=kubernetes.client.V1ResourceRequirements(
                            requests={"storage": storage}
                        )
                    )
                )
            ]
        )
    )


def _build_backup_cronjob(name, namespace, schedule, body):
    labels = {"app": f"backup-{name}"}
    return kubernetes.client.V1CronJob(
        metadata=kubernetes.client.V1ObjectMeta(
            name=f"backup-{name}",
            namespace=namespace,
            labels=labels,
            owner_references=[_owner_ref(name, body)]
        ),
        spec=kubernetes.client.V1CronJobSpec(
            schedule=schedule,
            successful_jobs_history_limit=3,
            failed_jobs_history_limit=1,
            job_template=kubernetes.client.V1JobTemplateSpec(
                spec=kubernetes.client.V1JobSpec(
                    template=kubernetes.client.V1PodTemplateSpec(
                        spec=kubernetes.client.V1PodSpec(
                            restart_policy="OnFailure",
                            containers=[kubernetes.client.V1Container(
                                name="backup",
                                image="postgres:15-alpine",
                                command=["/bin/sh", "-c",
                                    f"pg_dumpall -h postgres-{name} -U postgres > /backups/backup-$(date +%Y%m%d).sql"
                                ],
                                resources=kubernetes.client.V1ResourceRequirements(
                                    requests={"cpu": "100m", "memory": "128Mi"},
                                    limits={"cpu": "200m", "memory": "256Mi"}
                                )
                            )]
                        )
                    )
                )
            )
        )
    )
```

---

## Step 3 — Dockerfile for the Operator

```dockerfile
# Dockerfile
FROM python:3.11-slim
WORKDIR /app
RUN pip install kopf kubernetes
COPY operator.py .
CMD ["kopf", "run", "--standalone", "operator.py"]
```

---

## Step 4 — RBAC for the Operator

```yaml
# operator-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: databasecluster-operator
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: databasecluster-operator
rules:
  - apiGroups: [emagetech.io]
    resources: [databaseclusters, databaseclusters/status]
    verbs: ["*"]
  - apiGroups: [apps]
    resources: [statefulsets]
    verbs: ["*"]
  - apiGroups: [""]
    resources: [services, persistentvolumeclaims]
    verbs: ["*"]
  - apiGroups: [batch]
    resources: [cronjobs]
    verbs: ["*"]
  - apiGroups: [""]
    resources: [events]
    verbs: [create, patch]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: databasecluster-operator
roleRef:
  kind: ClusterRole
  name: databasecluster-operator
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: databasecluster-operator
    namespace: default
```

---

## Step 5 — Deploy and Test

```bash
# Build and push operator image
docker build -t yourusername/databasecluster-operator:1.0.0 .
docker push yourusername/databasecluster-operator:1.0.0

kubectl apply -f crd-databasecluster.yaml
kubectl apply -f operator-rbac.yaml

# Deploy the operator
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: databasecluster-operator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: databasecluster-operator
  template:
    metadata:
      labels:
        app: databasecluster-operator
    spec:
      serviceAccountName: databasecluster-operator
      containers:
        - name: operator
          image: yourusername/databasecluster-operator:1.0.0
          resources:
            requests: {cpu: 100m, memory: 128Mi}
            limits: {cpu: 200m, memory: 256Mi}
EOF

# Watch the operator logs
kubectl logs -f deploy/databasecluster-operator

# Now CREATE a DatabaseCluster
kubectl apply -f - <<EOF
apiVersion: emagetech.io/v1
kind: DatabaseCluster
metadata:
  name: prod-db
spec:
  replicas: 2
  version: "15"
  storageSize: 10Gi
  backupEnabled: true
  backupSchedule: "0 2 * * *"
EOF

# Watch resources being created
kubectl get dbc prod-db -w
kubectl get statefulset postgres-prod-db
kubectl get service postgres-prod-db
kubectl get cronjob backup-prod-db
```

> 📸 **Expected:** Operator logs show "Creating DatabaseCluster prod-db". StatefulSet, Service, and CronJob all appear automatically. `kubectl get dbc` shows Phase=Ready.

---

## Step 6 — Test Update and Delete

```bash
# Scale up by editing the CR
kubectl patch dbc prod-db --type='json' \
  -p='[{"op":"replace","path":"/spec/replicas","value":3}]'

# Watch StatefulSet scale
kubectl get statefulset postgres-prod-db -w

# Delete the CR — all child resources should cascade-delete
kubectl delete dbc prod-db

# Verify everything cleaned up
kubectl get statefulset,service,cronjob | grep prod-db
# Should be empty — ownerReferences handled cleanup
```

## Validation Checklist
- [ ] CRD registered: `kubectl get crd databaseclusters.emagetech.io`
- [ ] Operator running without errors in logs
- [ ] Creating a DatabaseCluster CR creates StatefulSet + Service + CronJob
- [ ] CR status shows Phase=Ready
- [ ] Scaling replicas in CR scales the StatefulSet
- [ ] Deleting the CR deletes all child resources (ownerReference cascade)
- [ ] `kubectl get dbc` shows custom columns (Replicas, Version, Phase)

## Troubleshooting

**Operator gets permission denied** — ClusterRole must include the CRD group. Check `apiGroups: [emagetech.io]` in ClusterRole rules.

**ownerReference not working (child resources not deleted)** — The `uid` in ownerReference must match the CR's actual UID. `kubectl get dbc prod-db -o jsonpath='{.metadata.uid}'`

**CRD validation rejecting valid manifests** — Check the `openAPIV3Schema` patterns. `kubectl apply` will show the validation error clearly.

## Extension Challenges
1. Add a **health check** to the operator — watch the StatefulSet's readyReplicas and update the CR status accordingly
2. Implement a **version upgrade path** — when `spec.version` changes, perform a rolling upgrade of the StatefulSet image
3. Port the operator to **Go using controller-runtime** — Go is the production standard for operators

## Resources
- [kopf Documentation](https://kopf.readthedocs.io/)
- [Operator SDK](https://sdk.operatorframework.io/)
- [Writing an Operator in Go](https://book.kubebuilder.io/)
- [OperatorHub.io](https://operatorhub.io/) — Browse real-world operators for inspiration
- 📺 [Building a Kubernetes Operator — CNCF](https://www.youtube.com/watch?v=08O9QLPlSBo)
- 📖 [Programming Kubernetes (O'Reilly)](https://www.oreilly.com/library/view/programming-kubernetes/9781492047094/)
