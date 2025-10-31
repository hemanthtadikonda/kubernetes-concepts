# Building a Custom Kubernetes Operator with Helm Integration

**Author:** Tadikonda Hemanth  
**Date:** 2025-10-31  
**Goal:** Build a custom Kubernetes operator that deploys Helm-based applications using Custom Resources — to understand CRDs, CRs, and controllers deeply.

---

## 🧩 Project Overview

**Project Title:** `hemanth-helm-operator`  
**Goal:** Automate Helm chart deployments using a Custom Resource (CR) in Kubernetes.

---

## 🧠 Concepts Recap

### Custom Resource Definition (CRD)
Defines a **new Kubernetes API object** type (e.g., `WebApp`).

### Custom Resource (CR)
An **instance** of the CRD that defines specific configurations.

### Custom Controller
A **control loop** that watches CRs and performs automation (e.g., installs Helm charts).

### Helm
Used for **application bundling** — helps package multi-service applications easily.

---

## 🧱 Step-by-Step Implementation Plan

### 🔹 Phase 1: Foundation Setup (Day 1–2)

**1. Create your demo app**
```bash
helm create hemanthapp-chart
```
Modify `values.yaml` to use your image:
```yaml
image:
  repository: hemanthapp
  tag: v1
```

**2. Prepare Kubernetes environment**
Use `minikube`, `kind`, or your cloud cluster.

---

### 🔹 Phase 2: Define the CRD and CR (Day 3–4)

**CRD Definition (`webapp-crd.yaml`)**
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
   name: webapps.hemanth.dev
spec:
   group: hemanth.dev
   names:
      plural: webapps
      singular: webapp
      kind: WebApp
      shortNames:
         - wa
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
                    properties:
                       name:
                          type: string
                       image:
                          type: string
                       replicas:
                          type: integer
                       serviceType:
                          type: string
                       port:
                          type: integer
                       targetPort:
                          type: integer
                    required:
                       - name
                       - image
                       - replicas

```

**CR Example (`webapp-cr.yaml`)**
```yaml
apiVersion: hemanth.dev/v1
kind: WebApp
metadata:
   name: myapp
spec:
   name: my-web-app
   image: nginx:latest
   replicas: 2
   serviceType: NodePort
   port: 80
   targetPort: 80

```

---

### 🔹 Phase 3: Build the Custom Controller (Day 5–7)

Using Python + `kopf` for simplicity.

**Install dependencies:**
```bash
pip install kopf kubernetes pyyaml
```

**controller.py**
```python
import kopf
import subprocess
import yaml
import tempfile
import os
import datetime

# Default values for Helm chart
DEFAULT_VALUES = {
    "image": {"repository": "nginx", "tag": "latest"},
    "replicaCount": 1,
    "service": {"type": "ClusterIP", "port": 80, "targetPort": 80}
}

def merge_values(spec):
    """
    Merge user-provided values in CR with defaults.
    """
    image = spec.get("image", f"{DEFAULT_VALUES['image']['repository']}:{DEFAULT_VALUES['image']['tag']}")
    if ":" in image:
        repository, tag = image.split(":")
    else:
        repository = image
        tag = DEFAULT_VALUES["image"]["tag"]

    return {
        # Force Helm to detect updates
        "_crd_update_time": datetime.datetime.utcnow().isoformat(),
        "image": {
            "repository": repository,
            "tag": tag
        },
        "replicaCount": spec.get("replicas", DEFAULT_VALUES["replicaCount"]),
        "service": {
            "type": spec.get("serviceType", DEFAULT_VALUES["service"]["type"]),
            "port": spec.get("port", DEFAULT_VALUES["service"]["port"]),
            "targetPort": spec.get("targetPort", DEFAULT_VALUES["service"]["targetPort"])
        }
    }

def deploy_helm_chart(app_name, namespace, helm_chart_path, values):
    """
    Deploy or upgrade Helm release using merged values.
    """
    # Create a temporary values file
    with tempfile.NamedTemporaryFile("w", delete=False) as f:
        yaml.dump(values, f)
        temp_file = f.name

    # Helm upgrade --install ensures create or update
    helm_cmd = [
        "helm", "upgrade", "--install", app_name, helm_chart_path,
        "-f", temp_file,
        "--namespace", namespace,
        "--reset-values"
    ]
    subprocess.run(helm_cmd, check=True)
    os.remove(temp_file)

@kopf.on.create('hemanth.dev', 'v1', 'webapps')
def create_webapp(spec, name, namespace, logger, **kwargs):
    app_name = spec.get('name', name)
    helm_chart_path = "/home/centos/my-webpage/helm/my-web-page-chart"

    logger.info(f"Creating/Deploying WebApp {app_name} in namespace {namespace}")
    values = merge_values(spec)
    deploy_helm_chart(app_name, namespace, helm_chart_path, values)
    logger.info(f"✅ Successfully deployed {app_name}")

@kopf.on.update('hemanth.dev', 'v1', 'webapps')
def update_webapp(spec, name, namespace, logger, **kwargs):
    app_name = spec.get('name', name)
    helm_chart_path = "/home/centos/my-webpage/helm/my-web-page-chart"

    logger.info(f"Updating WebApp {app_name} in namespace {namespace}")
    values = merge_values(spec)
    deploy_helm_chart(app_name, namespace, helm_chart_path, values)
    logger.info(f"🔄 Successfully updated {app_name}")

@kopf.on.delete('hemanth.dev', 'v1', 'webapps')
def delete_webapp(spec, name, namespace, logger, **kwargs):
    logger.info(f"Deleting WebApp {name} in namespace {namespace}")
    subprocess.run(["helm", "uninstall", name, "--namespace", namespace], check=True)
    logger.info(f"🧹 Successfully deleted {name}")


```

Run locally for testing:
```bash
kopf run controller.py
```

Apply CR:
```bash
kubectl apply -f webapp-cr.yaml
```

---

### 🔹 Phase 4: Deploy Controller in Kubernetes (Day 8–10)

**Dockerfile**
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY controller.py .
RUN pip install kopf kubernetes pyyaml
CMD ["kopf", "run", "/app/controller.py"]
```

**Build & Push Image**
```bash
docker build -t hemanth-helm-operator:v1 .
docker push hemanth-helm-operator:v1
```

**Deploy Controller in Cluster**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hemanth-helm-operator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hemanth-helm-operator
  template:
    metadata:
      labels:
        app: hemanth-helm-operator
    spec:
      serviceAccountName: default
      containers:
        - name: controller
          image: hemanth-helm-operator:v1
```

Apply it:
```bash
kubectl apply -f deployment.yaml
```

---

## 🔁 Step 3 vs Step 4 — Development vs Production

| Step | Purpose | Where It Runs | When to Use |
|------|----------|---------------|--------------|
| **Step 3** | Local testing (`kopf run`) | On your machine | During development |
| **Step 4** | Cluster deployment | Inside Kubernetes | For automation or production use |

They’re **sequential steps**, not alternatives.

---

## 🧠 Enhancements to Add Your Signature (Day 11–14)

- ✅ Add status updates in CR (`status.phase: deployed`)
- ✅ Add logic for automatic updates when image tag changes
- ✅ Add team annotations or labels for tracking
- ✅ Add Prometheus metrics and logs for observability
- ✅ Integrate Slack/webhook alerts on failures

---

## 🏁 Outcome

At the end of this project, you’ll have:
- A **working CRD + CR**  
- A **Custom Controller** written by you  
- Full automation loop: create → deploy Helm → delete → cleanup  
- A unique, demonstrable project to showcase in interviews or GitHub

---

## 🚀 Next Steps (Optional Advanced Learning)

- Learn **Kubebuilder (Go)** for enterprise-grade operator development.
- Add **multi-chart** support (deploying 3-tier apps in one CR).
- Integrate **ArgoCD or FluxCD** for GitOps-based reconciliations.

---

**Hemanth’s Mindset:** 🧩 “Understand deeply, build something your own, then automate it.”
