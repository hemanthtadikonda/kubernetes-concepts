# 🚀 Deploying OpenShift CodeReady Containers (CRC) on Azure VM
*📘 Overview*
This guide walks you through deploying an OpenShift CRC cluster on an Azure VM running Ubuntu 20.04 LTS. It’s written for beginners with clear steps, explanations, and troubleshooting tips.

## 🔧 Prerequisites
1. Azure VM Setup
   VM Size: Recommended – Standard_D4s_v3 (4 vCPUs, 16GB RAM)

OS: Ubuntu 20.04 LTS (Preferred over RHEL to avoid Red Hat subscription issues)

2. Open Required Ports

| Port | Protocol | Purpose               |
| ---- | -------- | --------------------- |
| 22   | TCP      | SSH Access            |
| 6443 | TCP      | Kubernetes API Server |
| 80   | TCP      | HTTP access to apps   |
| 443  | TCP      | HTTPS access to apps  |


## ⚙️ Installation Steps

*Step 1: SSH into Your VM*

```bash
ssh <your_username>@<your_vm_public_ip>
```
*Step 2: Install Dependencies*
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y libvirt-daemon-system libvirt-clients qemu-kvm virt-manager virtinst bridge-utils dnsmasq-base socat jq iptables uidmap
```

Step 3: Add User to Required Groups
```bash
sudo usermod -aG libvirt $(whoami)
newgrp libvirt
```
*Step 4: Enable and Start Libvirtd*
```bash
sudo systemctl enable --now libvirtd
sudo systemctl start libvirtd
```
*Step 5: Download CRC* from https://console.redhat.com/openshift/create/local
```bash
mkdir -p ~/downloads && cd ~/downloads
curl -LO https://developers.redhat.com/content-gateway/file/pub/openshift-v4/clients/crc/latest/crc-linux-amd64.tar.xz
tar -xvf crc-linux-amd64.tar.xz
sudo mv crc-linux-2.52.0-amd64/crc /usr/local/bin/
```
*Step 6: Get a Pull Secret*
Go to: https://cloud.redhat.com/openshift/install/crc/installer-provisioned

#### Log in or create a Red Hat account.

Download the *pull-secret.txt.*

*Step 7: Setup CRC*
```bash
crc setup
```
*Step 8: Start CRC*
```bash
crc start --pull-secret-file ~/downloads/pull-secret.txt
```
✅ Success Output Looks Like:
```bash
Started the OpenShift cluster
To access the cluster:
- oc login -u developer -p developer https://api.crc.testing:6443
- Access the web console at https://console-openshift-console.apps-crc.testing
```
  🔐 Access OpenShift Web Console
  Add this to /etc/hosts:

```bash
sudo nano /etc/hosts
```
Add the following line (adjust IP from crc ip):

```
192.168.130.11 console-openshift-console.apps-crc.testing api.crc.testing
```
Open your browser:
```agsl
https://console-openshift-console.apps-crc.testing
```

Use login:

* Username: `developer`

* Password: `developer`

## 🔎 Common Errors & Fixes

| Error                      | Cause                                     | Fix                                                    |
| -------------------------- | ----------------------------------------- | ------------------------------------------------------ |
| `virtiofsd not found`      | Missing dependency                        | `sudo apt install virtiofsd`                           |
| `Permission denied (sudo)` | Sudo not installed or user not configured | Ensure you're using Ubuntu and user has `sudo` rights  |
| `Hypervisor not found`     | Nested virtualization not enabled         | Make sure Azure VM size supports nested virtualization |
| `crc start` hangs          | Network issues or DNS misconfiguration    | Check network settings, ensure ports are open, and DNS is set up correctly |

## 🧼 Cleanup
To delete the CRC cluster and clean up resources:
```bash
crc stop
crc delete --force
```

