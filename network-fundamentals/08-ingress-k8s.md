# 🚦 Ingress — Exposing Your App to the Internet

> **Pre-req:** Read [05-how-the-internet-works.md](05-how-the-internet-works.md) and [06-kubernetes-pod-networking.md](06-kubernetes-pod-networking.md) first.

---

## The Problem: ClusterIP Stays Inside

You've learned about Services. By default, a `ClusterIP` Service is only reachable **inside** the cluster.

To get traffic from the outside world (real users, browsers, other systems), you need something that bridges the outside and inside.

---

## Option 1: LoadBalancer Service

The simplest way: set Service type to `LoadBalancer`.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080
```

Your cloud provider (GKE, EKS, AKS) provisions a public IP and routes port 80 to your Pods.

**Problem:** Each Service gets its own load balancer = its own public IP = its own cloud bill.
If you have 10 Services, you pay for 10 load balancers. Gets expensive fast.

---

## Option 2: Ingress — One Entry Point, Many Services

An **Ingress** is a smart HTTP router that sits at the edge of your cluster.
One load balancer, many services — routing based on hostname or URL path.

```
External Traffic
       │
       ▼
  LoadBalancer (1 IP, 1 bill)
       │
       ▼
  Ingress Controller
       │
       ├─ app.example.com/api    ──→  api-service
       ├─ app.example.com/web    ──→  web-service
       └─ admin.example.com      ──→  admin-service
```

One public IP, three services, all routed by the Ingress rules.

---

## An Ingress Resource

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 80
          - path: /web
            pathType: Prefix
            backend:
              service:
                name: web-service
                port:
                  number: 80
    - host: admin.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: admin-service
                port:
                  number: 80
```

---

## Ingress Controllers

An Ingress resource is just configuration — it doesn't do anything alone.
You need an **Ingress Controller** to actually process those rules and route traffic.

Popular options:
| Controller | Notes |
|-----------|-------|
| **nginx-ingress** | Most popular, battle-tested |
| **Traefik** | Great for dynamic config, popular with developers |
| **HAProxy** | High performance |
| **GKE Ingress** | GCP-native, integrates with Cloud Load Balancing |
| **AWS ALB Ingress** | AWS-native, integrates with Application Load Balancer |

---

## Adding TLS / HTTPS

Remember HTTPS from the networking tutorials? Ingress handles TLS termination.

```yaml
spec:
  tls:
    - hosts:
        - app.example.com
      secretName: my-tls-secret    # A Kubernetes Secret with your certificate
  rules:
    - host: app.example.com
      ...
```

With **cert-manager** (covered in Session 19), certificates from Let's Encrypt are provisioned and renewed automatically. You never touch a certificate file manually.

---

## Gateway API — The Future of Ingress

Ingress works well, but it has limitations (vendor-specific annotations, limited routing rules).

The **Gateway API** (covered in Session 18) is the next generation — more expressive, more consistent across providers.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-route
spec:
  parentRefs:
    - name: my-gateway
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: api-service
          port: 80
```

You'll use Gateway API in the class — think of it as Ingress 2.0.

---

## 🧪 Try It Yourself

```bash
# List all Ingress resources
kubectl get ingress -A

# Describe an Ingress (shows rules and backend services)
kubectl describe ingress my-app-ingress

# Check if an Ingress Controller is installed
kubectl get pods -n ingress-nginx

# See the external IP assigned to your Ingress
kubectl get ingress my-app-ingress
# Look for the ADDRESS column
```

---

## The Full Picture

```
User's Browser
    │
    │ HTTPS request to app.example.com
    ▼
DNS: app.example.com → 34.120.50.10
    │
    ▼
Cloud Load Balancer (34.120.50.10:443)
    │
    ▼
Ingress Controller Pod (inside cluster)
    │
    │ TLS terminated here, decrypted
    │ Route: /api → api-service
    ▼
api-service (ClusterIP)
    │
    ▼
api Pod (10.244.1.5:8080)
```

You now understand every step of that journey.

---

## ✅ What You Learned

- ClusterIP Services are internal only — Ingress exposes them to the world
- Ingress is a smart HTTP router: one load balancer, many services
- You need an Ingress Controller to process Ingress resources
- TLS termination happens at the Ingress layer
- Gateway API is the modern replacement for Ingress

**You've completed the Kubernetes Networking section!** 🎉
Go check out [Session 17 (Network Policies)](../class-materials/labs/lab-17-network-policies/) and [Session 18 (Gateway API)](../class-materials/labs/lab-18-gateway-api/) in the class labs.
