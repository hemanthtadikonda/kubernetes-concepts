# 🚀 Minimal-Cost EKS Cluster Setup using eksctl

This guide helps you create a **minimal-cost EKS cluster** to practice **Service Mesh (Istio or AWS App Mesh)** using the `eksctl` tool.

---

## 🧩 Step 1️⃣: Install Required Tools

Run these on your local Linux/Mac terminal (or AWS CloudShell — which already includes AWS CLI).

### Install eksctl
```bash
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"
tar -xzf eksctl_$(uname -s)_amd64.tar.gz
sudo mv eksctl /usr/local/bin/
eksctl version
```

### Install kubectl
```bash
curl -o kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.0/2024-07-09/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client
```

### Install AWS CLI
```bash
sudo apt install awscli -y
aws --version
```

---

## 🔑 Step 2️⃣: Configure AWS CLI

```bash
aws configure
```
Provide:
- Access Key ID  
- Secret Key  
- Default region → `us-east-1`  
- Output format → `json`

---

## ⚙️ Step 3️⃣: Create SSH Key Pair (Optional)
```bash
aws ec2 create-key-pair --key-name my-eks-keypair --query "KeyMaterial" --output text > my-eks-keypair.pem
chmod 400 my-eks-keypair.pem
```

---

## 🧾 Step 4️⃣: Create EKS Cluster Configuration File

Create `minimal-eks.yaml`:

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: minimal-mesh-cluster
  region: us-east-1

vpc:
  cidr: 10.0.0.0/16

managedNodeGroups:
  - name: ng-mesh
    instanceType: t3.small
    desiredCapacity: 1
    minSize: 1
    maxSize: 2
    volumeSize: 20
    ssh:
      allow: true
      publicKeyName: my-eks-keypair
    labels:
      role: worker
    tags:
      Name: eks-mesh-node
```

---

## 🚀 Step 5️⃣: Create the EKS Cluster

```bash
eksctl create cluster -f minimal-eks.yaml
```

Takes about **15–20 minutes**.

---

## 🔍 Step 6️⃣: Verify the Cluster

```bash
kubectl get nodes
kubectl get pods -A
```

Expected output:
```
NAME                                           STATUS   ROLES    AGE   VERSION
ip-10-0-1-12.ec2.internal                      Ready    <none>   1m    v1.30.x
```

---

## 🧹 Step 7️⃣: Save Costs

```bash
eksctl delete cluster -f minimal-eks.yaml
```

Deletes all associated resources.

---

## 🧩 Optional: Use Spot Instances

Cheaper setup (~70% less):
```yaml
managedNodeGroups:
  - name: ng-spot
    instanceType: t3.small
    desiredCapacity: 1
    spot: true
```

---

## ✅ Step 8️⃣: Install Istio (Minimal Profile)

```bash
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH
istioctl install --set profile=minimal -y
kubectl label namespace default istio-injection=enabled
kubectl get pods -n istio-system
```

---

## ✅ Summary Table

| Step | Action | Command |
|------|--------|----------|
| 1 | Install eksctl, kubectl, awscli | `curl`, `tar`, `sudo mv` |
| 2 | Configure AWS credentials | `aws configure` |
| 3 | Create key pair | `aws ec2 create-key-pair` |
| 4 | Define config | `minimal-eks.yaml` |
| 5 | Create cluster | `eksctl create cluster -f minimal-eks.yaml` |
| 6 | Verify | `kubectl get nodes` |
| 7 | Save cost | `eksctl delete cluster -f minimal-eks.yaml` |
| 8 | Install Istio | `istioctl install` |

---

### 💡 Tips
- Use `us-east-1` region for lowest EKS cost.
- Delete cluster when idle to prevent EC2 charges.
- Optionally test locally with `kind` for zero AWS cost.

---

**Author:** Tadikonda Hemanth  
**Purpose:** Minimal-Cost EKS Cluster for Service Mesh Practice
