# Helm: The Kubernetes Package Manager

> Part of the [Kubernetes Cohort Study-Ahead Materials](./README.md)

## Overview
Helm is the de facto package manager for Kubernetes, used by almost every production team to manage application deployments. This section covers Helm's chart structure, how Go templates power dynamic manifest generation, how `values.yaml` files enable environment-specific configuration, lifecycle hooks, and chart dependencies. Understanding Helm is essential for both consuming community charts and building your own.

---

## 🎥 YouTube Videos

### Creating Helm Charts Tutorial — Build Custom Kubernetes Packages from Scratch
[![Thumbnail](https://img.youtube.com/vi/1XnwuJ6FlUY/0.jpg)](https://www.youtube.com/watch?v=1XnwuJ6FlUY)
**Channel:** KodeKloud
> Published October 2025 — comprehensive beginner-friendly tutorial on building Helm charts from scratch, covering chart structure, templates, and deployment workflows.

### Helm in Kubernetes Explained | Charts, Architecture, Templates & Deployment
[![Thumbnail](https://img.youtube.com/vi/lRpZb0YDWnI/0.jpg)](https://www.youtube.com/watch?v=lRpZb0YDWnI)
**Channel:** DevOps Directive
> Published early 2026 — covers Helm from basics to advanced concepts, including chart architecture, the Helm release lifecycle, and production usage patterns.

### Helm Templates Tutorial: Dynamic Manifest Generation for Kubernetes Beginners
[![Thumbnail](https://img.youtube.com/vi/3-6vjErs5bs/0.jpg)](https://www.youtube.com/watch?v=3-6vjErs5bs)
**Channel:** KodeKloud
> October 2025 tutorial focused on Go templating in Helm — covers `{{ .Values }}`, `{{ .Release }}`, conditionals, loops, and named templates (`define`/`include`).

### Helm Values: Customize Kubernetes Chart Deployments | Complete Tutorial
[![Thumbnail](https://img.youtube.com/vi/ralAdHgcogw/0.jpg)](https://www.youtube.com/watch?v=ralAdHgcogw)
**Channel:** KodeKloud
> October 2025 — deep dive into the Helm values system: default values, value overrides, `--set` flags, and multi-environment value files.

### Helm Tutorial #5 | Helm Templates Explained Simply!
[![Thumbnail](https://img.youtube.com/vi/9fMXpD5BiPI/0.jpg)](https://www.youtube.com/watch?v=9fMXpD5BiPI)
**Channel:** TechWorld with Nana
> March 2025 — clear and accessible explanation of Helm templates, showing how to customize charts for different environments and use cases.

---

## 📚 Articles & Documentation

### Helm Documentation
🔗 [Helm Documentation](https://helm.sh/docs/)
**Source:** helm.sh | **Level:** Beginner
> The official Helm documentation hub — covers installation, quickstart, chart development, the templating guide, best practices, and the Helm CLI reference.

### The Chart Template Guide
🔗 [The Chart Template Guide](https://helm.sh/docs/chart_template_guide/)
**Source:** helm.sh | **Level:** Intermediate
> The definitive guide to Helm's Go templating system — covers the template language, built-in objects (`.Values`, `.Release`, `.Chart`), functions, pipelines, and named templates.

### Chart Hooks
🔗 [Chart Hooks](https://helm.sh/docs/topics/charts_hooks/)
**Source:** helm.sh | **Level:** Intermediate
> Official documentation on Helm hooks — how to run jobs at specific points in the release lifecycle (pre-install, post-install, pre-upgrade, pre-delete, etc.).

### What is a Helm Chart? A Tutorial for Kubernetes Beginners
🔗 [What is a Helm Chart?](https://www.freecodecamp.org/news/what-is-a-helm-chart-tutorial-for-kubernetes-beginners/)
**Source:** freecodecamp.org | **Level:** Beginner
> Accessible introduction to Helm charts — explains the directory structure (`Chart.yaml`, `values.yaml`, `templates/`), and the relationship between charts and releases.

### Helm Chart Tutorial: A Complete Guide
🔗 [Helm Chart Tutorial: A Complete Guide](https://middleware.io/blog/helm-chart-tutorial/)
**Source:** middleware.io | **Level:** Intermediate
> Practical end-to-end tutorial covering chart creation, template customization, deployment to Kubernetes, upgrades, rollbacks, and chart repositories.

---

## 🗝️ Key Concepts to Know Before Class
- **Helm chart structure**: `Chart.yaml` (metadata), `values.yaml` (default config), `templates/` (Go template files), `charts/` (sub-chart dependencies), `NOTES.txt` (post-install notes).
- **Go templating**: `{{ .Values.image.tag }}` injects values; `{{ if }}`, `{{ range }}`, `{{ with }}` for control flow; `{{ define }}`/`{{ include }}` for reusable named templates.
- **Release lifecycle**: `helm install` → `helm upgrade` → `helm rollback` → `helm uninstall`. Helm tracks releases in Kubernetes Secrets in the release namespace.
- **Hooks** run jobs at lifecycle points: `pre-install` (run before first install), `post-upgrade` (run after upgrade), `pre-delete` (cleanup before uninstall).
- **Dependencies** (`Chart.yaml` `dependencies:` section): reference other charts as sub-charts. Use `helm dependency update` to fetch them into `charts/`.
- **`helm template`** renders charts locally without installing — invaluable for debugging templates and integration with GitOps tools.
