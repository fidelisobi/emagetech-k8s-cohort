# Kubernetes Networking

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Overview
Kubernetes networking is one of the most important — and most complex — areas to understand. This section covers the flat pod networking model, CNI plugins, how Services expose applications (ClusterIP, NodePort, LoadBalancer), Ingress for HTTP routing, Network Policies for traffic control, CoreDNS for service discovery, and kube-proxy's role in iptables/IPVS rules. Networking affects everything from availability to security.

---

## 🎥 YouTube Videos

### Kubernetes Tutorial for Beginners [FULL COURSE in 4 Hours]
[![Thumbnail](https://img.youtube.com/vi/X48VuDVv0do/0.jpg)](https://www.youtube.com/watch?v=X48VuDVv0do)
**Channel:** TechWorld with Nana
> The services and networking section of this course covers ClusterIP, NodePort, and LoadBalancer service types with clear diagrams and live demos.

### Complete Kubernetes Course — From BEGINNER to PRO
[![Thumbnail](https://img.youtube.com/vi/2T86xAtR6Fo/0.jpg)](https://www.youtube.com/watch?v=2T86xAtR6Fo)
**Channel:** DevOps Directive
> This 2024 course includes hands-on networking sections — Services, Ingress setup with nginx-ingress, and Network Policies — all with working YAML examples.

### Kubernetes Architecture Explained | Control Plane Components
[![Thumbnail](https://img.youtube.com/vi/5zImYn0isPk/0.jpg)](https://www.youtube.com/watch?v=5zImYn0isPk)
**Channel:** DevOps Shack
> Covers kube-proxy's role in the networking model and how iptables rules are used to route traffic to service endpoints.

### Kubernetes Explained in 15 Minutes | Hands On (2024 Edition)
[![Thumbnail](https://img.youtube.com/vi/r2zuL9MW6wc/0.jpg)](https://www.youtube.com/watch?v=r2zuL9MW6wc)
**Channel:** Travis Media
> Includes a practical walkthrough of creating Services and exposing applications — accessible for beginners learning Kubernetes networking for the first time.

---

## 📚 Articles & Documentation

### Services
🔗 [Service](https://kubernetes.io/docs/concepts/services-networking/service/)
**Source:** kubernetes.io | **Level:** Beginner
> Official documentation for Kubernetes Services — explains ClusterIP, NodePort, LoadBalancer, and ExternalName types, plus selector-based endpoint management.

### Ingress
🔗 [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
**Source:** kubernetes.io | **Level:** Intermediate
> Official Ingress docs — covers rules-based HTTP routing, TLS termination, and the relationship between Ingress resources and Ingress controllers.

### Network Policies
🔗 [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
**Source:** kubernetes.io | **Level:** Intermediate
> Official Network Policy docs — explains how to define ingress and egress rules based on pod selectors, namespace selectors, and IP blocks.

### Network Plugins (CNI)
🔗 [Network Plugins](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)
**Source:** kubernetes.io | **Level:** Intermediate
> Explains the CNI (Container Network Interface) standard, how plugins integrate with kubelet, and the requirements for Kubernetes-compatible CNI plugins.

### Kubernetes CNI: The Ultimate Guide (2025)
🔗 [Kubernetes CNI: The Ultimate Guide](https://www.plural.sh/blog/kubernetes-cni-guide/)
**Source:** plural.sh | **Level:** Intermediate
> Practical 2025 guide comparing popular CNI plugins (Calico, Cilium, Flannel, Weave) and when to choose each, with discussion of Network Policy support.

### Understanding Kubernetes Services, Ingress, and Networking
🔗 [Understanding Kubernetes Services, Ingress, and Networking](https://www.harness.io/harness-devops-academy/kubernetes-services-ingress-networking-explained)
**Source:** harness.io | **Level:** Beginner
> Clear, diagram-heavy article explaining the full Kubernetes networking flow — from pod-to-pod communication to external traffic ingress.

---

## 🗝️ Key Concepts to Know Before Class
- **The Kubernetes networking model**: Every pod gets its own IP. Pods can communicate with any other pod without NAT. This flat network is provided by CNI plugins (Calico, Cilium, Flannel, etc.).
- **Service types**: `ClusterIP` (internal only), `NodePort` (exposes on every node's IP at a static port), `LoadBalancer` (provisions a cloud load balancer). Most production traffic enters via `LoadBalancer` + `Ingress`.
- **Ingress** is an API object that defines HTTP/HTTPS routing rules. An **Ingress Controller** (like nginx-ingress or Traefik) is the actual component that implements those rules.
- **CoreDNS** makes service discovery work: a Service named `my-svc` in namespace `prod` is reachable at `my-svc.prod.svc.cluster.local` from anywhere in the cluster.
- **kube-proxy** watches the API server for Service/Endpoint changes and updates iptables or IPVS rules on each node to route traffic correctly.
- **Network Policies** are the Kubernetes equivalent of a firewall — they default-allow all traffic, but once you apply a policy to a pod, only explicitly allowed traffic is permitted.
- **EndpointSlices** (replacing Endpoints) provide scalable tracking of pod IPs backing a service.
