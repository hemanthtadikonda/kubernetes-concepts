# 🚀 OpenShift 4.x (Installer-Provisioned Infrastructure) Cluster Provisioning Guide
This document explains step-by-step how to create, manage, and delete a self-managed OpenShift 4.x cluster on AWS using the openshift-install and oc CLI—without relying on the AWS Console.

### 🎯 Why Use Self-Managed IPI?
* Lower cost than ROSA

* Full control over your cluster infrastructure

* Ideal for labs, evaluation, and advanced customization

* No vendor lock-in for upgrades or lifecycle

## 🟢 Prerequisites
Before starting, install the following tools and collect required credentials.

## ✅ 1. AWS CLI
* Install:
```bash
sudo dnf install awscli -y
aws --version
```
* Configure credentials:
```bash
aws configure
```
* Enter your AWS Access Key ID, Secret Access Key, region (e.g., us-east-1), and output format (json).
* Verify identity:
```bash
aws sts get-caller-identity
```
✅ Tip: Ensure your IAM user has sufficient permissions to create EC2, VPC, Route53, and IAM roles.

## ✅ 2. SSH Key (OpenSSH format)
If you already have an .ppk file (PuTTY Private Key), convert it:

Install putty-tools:

```bash
sudo yum update   
sudo yum install putty-tools -y
```
Convert .ppk to OpenSSH private key:

```bash
puttygen hema.ppk -O private-openssh -o id_rsa
```
Extract public key:

```bash
ssh-keygen -y -f id_rsa > id_rsa.pub
```
Secure permissions:
```bash
chmod 600 id_rsa
chmod 644 id_rsa.pub
```
✅ Important: Keep your private key (id_rsa) safe.

## ✅ 3. OpenShift Installer
* Download Installer:

```
curl -LO https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-install-linux.tar.gz
```
* Extract and install:
```
tar -xvf openshift-install-linux.tar.gz
chmod +x openshift-install
sudo mv openshift-install /usr/local/bin/
```
Verify:
```
openshift-install version
```
## ✅ 4. OpenShift CLI (oc)
Download:

```
curl -LO https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux-amd64-rhel8.tar.gz
```

Extract and install:
```
tar -xvf openshift-client-linux-amd64-rhel8.tar.gz
chmod +x oc kubectl
sudo mv oc kubectl /usr/local/bin/
```
Verify:
```
oc version
```
## ✅ 5. Red Hat Pull Secret
* Download your pull secret from:
Red Hat OpenShift Cluster Manager

    * Save it as pull-secret.txt.

### 🟢 Step-by-Step Cluster Creation
* ✅ 1. Prepare Working Directory
Create a folder for your install files:
```
mkdir ~/openshift-install
cd ~/openshift-install
```
* ✅ 2. Generate Install Configuration
Run:

```
openshift-install create install-config
You will be prompted for:

AWS region

Base domain

Cluster name

Pull secret

SSH public key
```
✅ Tip: Paste the Pull secret carefully, which is copied from Redhat portal.

✅ Tip: Paste the contents of id_rsa.pub when asked for the SSH key.

* ✅ 3. Customize install-config.yaml (Optional)
Edit the file:
```
vi install-config.yaml
```
Example to set no worker nodes at install:
```
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform: {}
  replicas: 0
  controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform: {}
  replicas: 3
 ```
✅ Tip: You can customize instance types, networking, and more.

* #### ✅ 4. Create the Cluster
Run:
```
openshift-install create cluster
```
* This process:

Creates VPC, subnets, and EC2 resources

Sets up Route53 DNS entries

Deploys OpenShift control plane and workers

Provisioning takes ~30–45 minutes.

✅ Tip: If you lose the session, you can resume:
```
openshift-install wait-for install-complete --log-level=info
```
* ✅ 5. Save Cluster Information


At the end, the installer shows:
```
INFO Install complete!
INFO To access the cluster as the system:admin user when using 'oc', run
INFO     export KUBECONFIG=/home/ec2-user/openshift-install/auth/kubeconfig
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.<domain>
INFO Login to the console with user: "kubeadmin", and password: "<password>"
```
✅ Save:

kubeconfig file path

Console URL

kubeadmin credentials

## ✅ 6. Access the Cluster
Set KUBECONFIG:
```
export KUBECONFIG=$(pwd)/auth/kubeconfig
```
Verify nodes:
```
oc get nodes
```
* #### Login to the console in your browser using the saved credentials.

## ✅ 7. SSH Access (Optional)
Use your converted private key (id_rsa):
```
ssh -i id_rsa core@<worker-or-master-public-ip>
```


# 🟢 Handling Errors & Common Pitfalls
❗ AWS Permissions Issues
Error:
```
error: insufficient permissions to create VPC/subnets
```
✅ Fix:
Ensure your AWS IAM user has AdministratorAccess.


❗ SSH Key Errors
Error:
```
Permission denied (publickey)
```
✅ Fix:

Confirm correct key is used (id_rsa).

Check permissions (chmod 600 id_rsa).

#### ❗ Stuck Provisioning

✅ Fix:
Check logs:
```
openshift-install wait-for bootstrap-complete --log-level=debug
```
If needed, destroy and recreate.

## 🟢 Cluster Deletion and Cleanup
To avoid AWS costs:

1. Destroy the cluster:
```
openshift-install destroy cluster
```
This deletes all AWS resources created.

### 🟢 Cost Optimization Tips
Use smaller instance types (e.g., m5.large) in install-config.yaml.

Set replicas: 0 for workers during initial install.

Destroy clusters immediately when not in use.

### 🟢 Helpful Commands Cheat Sheet
List all nodes:
```
oc get nodes
```
Check cluster operators:
```
oc get co
```
Export kubeconfig:
```
export KUBECONFIG=$(pwd)/auth/kubeconfig
```
Delete cluster:
```
openshift-install destroy cluster
```
## 🧹 Conclusion

This guide provides everything needed to create, manage, and delete self-managed OpenShift clusters on AWS via CLI, ensuring predictable, automatable workflows.

✅ Keep this file in your Git repo as a reference for yourself or your team.

#### Author: Hemanth Tadikonda, June 2025

✅ All set!
If you’d like, I can help you prepare:

* Terraform equivalents

* Automation scripts

* Monitoring guides

