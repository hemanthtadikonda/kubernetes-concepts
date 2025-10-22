# 🧠 Istio Deep Dive – Practical Understanding & Internals

## 🎯 Objective

This document helps you understand **how communication works in Kubernetes** before and after installing **Istio** (Service Mesh).  
We’ll explore:
1. Basic service-to-service communication (without Istio)
2. How Istio intercepts and changes this communication
3. Behavior when adding new deployments after Istio installation
4. Deep dive into Istio internals (from official docs)

---

## 🏗️ Phase 1: Kubernetes Basic Service-to-Service Communication

### 🔹 Step 1: Create Two Deployments
We’ll deploy:
- **nginx-deploy** → serving HTTP (port 80)
- **centos-deploy** → running a CentOS container with a sleep command (for debugging)

```bash
# NGINX Deployment
kubectl create deployment nginx-deploy --image=nginx

# Expose as ClusterIP service
kubectl expose deployment nginx-deploy --port=80 --target-port=80 --name=nginx-svc --type=ClusterIP

# CentOS Deployment (sleep for 1 hour)
kubectl create deployment centos-deploy --image=centos -- sleep 3600

# Expose as ClusterIP service
kubectl expose deployment centos-deploy --port=8080 --name=centos-svc --type=ClusterIP
```

🔹 Step 2: Verify Resources
```
kubectl get pods,svc
Expected Output:

swift
Copy code
NAME                                READY   STATUS    RESTARTS   AGE
pod/nginx-deploy-xxxxx              1/1     Running   0          1m
pod/centos-deploy-xxxxx             1/1     Running   0          1m

NAME                 TYPE        CLUSTER-IP     PORT(S)   AGE
service/nginx-svc    ClusterIP   10.96.0.100    80/TCP    1m
service/centos-svc   ClusterIP   10.96.0.110    8080/TCP  1m
```

🔹 Step 3: Access Each Service from Another Pod
To simulate internal communication:

```
# Access NGINX service from CentOS container
kubectl exec -it deploy/centos-deploy -- bash

# Inside container
curl nginx-svc.default.svc.cluster.local

Expected Output:

php-template
Copy code
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```

Similarly, you can access the CentOS service from NGINX (if any app runs inside CentOS).
At this point, both services can communicate freely within the cluster.

✅ Conclusion:
Without Istio, all pods in a namespace can communicate directly via ClusterIP DNS names — there’s no policy or proxy controlling this traffic.

## Phase 2: Install Istio
You already have installation steps in readme.md — install Istio using the demo profile and enable sidecar injection.

```
kubectl label namespace default istio-injection=enabled
```
All new pods created in this namespace will automatically get Envoy sidecar injected.

### Phase 3: Recreate Deployments with Istio Sidecar Injection
To ensure sidecars are attached, recreate the previous deployments:

```
kubectl delete deploy nginx-deploy centos-deploy
kubectl delete svc nginx-svc centos-svc
```

**Recreate NGINX**
```
kubectl create deployment nginx-deploy --image=nginx
kubectl expose deployment nginx-deploy --port=80 --target-port=80 --name=nginx-svc --type=ClusterIP
```
**Recreate CentOS**
```
kubectl create deployment centos-deploy --image=centos -- sleep 3600
kubectl expose deployment centos-deploy --port=8080 --name=centos-svc --type=ClusterIP
```
Now check pods:


kubectl get pods
Expected Output:
```
NAME                                READY   STATUS    RESTARTS   AGE
nginx-deploy-xxxxx                  2/2     Running   0          2m
centos-deploy-xxxxx                 2/2     Running   0          2m
```
✅ Observation:
Each pod now has two containers →

Application container (nginx or centos)

Istio-proxy (Envoy)

🔍 Step 4: Try Service Access Again
```
kubectl exec -it deploy/centos-deploy -- bash
curl nginx-svc.default.svc.cluster.local
```
Now, this will still work, but traffic will not go directly from pod to pod.

Instead, it flows like this:
CentOS app → local Envoy sidecar → remote Envoy sidecar → NGINX app

**✅ Conclusion:**
Now all pod-to-pod communication flows through Envoy proxies, which are controlled by Istiod.
This enables traffic management, tracing, encryption (mTLS), and policies.

### 🧱 Phase 4:Add a New Deployment (After Istio Installation) ###

Now let’s add a new CentOS deployment after Istio is installed.

```
kubectl create deployment centos-new --image=centos -- sleep 3600
kubectl expose deployment centos-new --port=8081 --name=centos-new-svc --type=ClusterIP
```
Check sidecar injection:

```
kubectl get pods centos-new-xxxxx -o jsonpath='{.spec.containers[*].name}'
```
Expected output:

nginx
Copy code
centos istio-proxy
If automatic injection is enabled, sidecar will be injected.
If not, it means:

The namespace is not labeled for injection, or

Injection webhook failed.

You can manually inject like this:

```
kubectl delete pod <pod-name>
kubectl get ns default --show-labels
```
**Ensure: istio-injection=enabled**

✅ Test Communication

```
kubectl exec -it deploy/centos-new -- bash
curl nginx-svc.default.svc.cluster.local
If mTLS is enabled, traffic passes via Envoy proxies and is encrypted.
If policies are not yet configured, it behaves as open (accessible).
```
✅ Key Learning:

New workloads in labeled namespaces automatically join the service mesh.

If not labeled, they remain outside the mesh (communication may fail due to missing mTLS or routing rules).

## 🧠 Phase 5: Deep Dive – Istio Internals (from Official Docs) 
🔸 Bookinfo Example Overview
The Istio Getting Started guide deploys a Bookinfo application with multiple services:

* Service	Description
* productpage	Displays the book details
* details	Provides book information 
* reviews	Displays book reviews
* ratings	Provides review ratings

Each service runs multiple versions (v1, v2, v3).
Istio controls routing, telemetry, and security between these microservices.

🧩 How Istio Works Internally
1. Sidecar Proxy Injection
Istio injects an Envoy sidecar alongside each service pod.

Envoy intercepts all inbound and outbound traffic.

2. Control Plane (Istiod)
Distributes configurations (routing, security policies).

Handles certificate management for mTLS.

Monitors service discovery.

3. Data Plane (Envoy Proxies)
Executes traffic routing, retries, and load balancing.

Enforces authentication and authorization.

Generates telemetry data (metrics, traces, logs).

🧭 Traffic Flow Example (Bookinfo Request)
User sends request → IngressGateway

Gateway forwards to VirtualService → productpage

productpage calls reviews

reviews calls ratings

Each hop:

Outbound request → local Envoy

Envoy forwards to destination Envoy

Destination Envoy → application container

All communication is:

Encrypted (mTLS)

Observed (metrics, tracing)

Controllable (traffic routing rules)

🔐 Istio Policies in Action
Feature	What It Does
mTLS	Encrypts pod-to-pod communication
AuthorizationPolicy	Defines which service can talk to which
PeerAuthentication	Controls TLS mode (STRICT, PERMISSIVE, DISABLE)
VirtualService	Defines HTTP routing rules
DestinationRule	Configures load balancing & connection policies

🧠 Key Takeaways
Without Istio → direct pod-to-pod communication using Kubernetes DNS.

With Istio → traffic flows through Envoy proxies (controlled by Istiod).

New deployments:

Auto-injected if namespace labeled istio-injection=enabled.

Not injected → traffic may fail if strict mTLS is enforced.

Bookinfo example demonstrates:

Traffic routing

Observability (Prometheus, Grafana, Jaeger)

Security enforcement (mTLS & RBAC)

🏁 Summary
Phase	Description	Key Outcome
1	Kubernetes direct communication	Works via ClusterIP DNS
2	Istio installed	Envoy sidecars intercept all traffic
3	New deployment added	Behavior depends on sidecar injection
4	Bookinfo demo	Demonstrates routing, security, and telemetry

📘 Next Steps
Deploy Bookinfo as per Istio docs

Explore dashboards:

```
istioctl dashboard grafana
istioctl dashboard kiali
istioctl dashboard jaeger
```
Try traffic shifting, fault injection, and mirroring
