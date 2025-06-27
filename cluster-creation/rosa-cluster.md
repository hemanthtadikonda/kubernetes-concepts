# 🚀 ROSA (Red Hat OpenShift Service on AWS) Cluster Provisioning Guide

This document explains step-by-step how to **create, manage, and delete a ROSA cluster on AWS** using the `rosa` CLI—**without relying on the AWS Console**.

---

## 🎯 Why Use the ROSA CLI?

- Fully automatable (like `eksctl` or Terraform)
- Reproducible workflows
- CLI-first experience for DevOps teams
- Avoids manual console navigation

---

## 🟢 Prerequisites

Before starting, install the following tools.

---

### ✅ 1. AWS CLI

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

### Configure your credentials:
```agsl
aws configure
```

##  ✅ 2. ROSA CLI
```bash
curl -o rosa.tar.gz https://mirror.openshift.com/pub/openshift-v4/clients/rosa/latest/rosa-linux.tar.gz
tar -xvf rosa.tar.gz
sudo mv rosa /usr/local/bin/
rosa version
```

## 3. OpenShift CLI (oc)
```bash
rosa download openshift-client
tar -xvf openshift-client-linux.tar.gz
sudo mv oc kubectl /usr/local/bin/
oc version
```

# 🟢 Step-by-Step Cluster Creation

## ✅ 1. Login to Red Hat
```bash
rosa login --use-auth-code

rosa login --use-device-code 
````
This opens a browser window for authentication.

## ✅ 2. Verify AWS Permissions and Quota
```bash
rosa verify permissions
rosa verify quota
```
✅ Tip: Ensure your account has enough quota for EC2, VPC, and EBS.

## ✅ 3. Create Account Roles
This is a critical step. Without these roles, cluster creation will fail or prompt for manual Role ARNs.
```
rosa create account-roles --mode auto --yes
```
Why?
These IAM roles allow ROSA to manage AWS resources securely.

## ✅ 4. Create the Cluster
```bash
rosa create cluster \
  --cluster-name=hemanth-rosa \
  --region=us-east-1 \
  --version=4.19.0 \
  --multi-az \
  --compute-machine-type=t4g.xlarge \
  --replicas=2 \
  --mode=auto \
  --sts
```
```
rosa create cluster \
--cluster-name=dev-cluster \
--region=us-east-1 \
--version=4.19.0 \
--single-az \
--compute-machine-type=t4g.xlarge \
--replicas=1 \
--mode=auto \
--sts
```
✅ Notes:

--replicas=2 replaces the deprecated --compute-nodes

--sts is the recommended security mode

##✅ 5. Create OIDC Provider When Prompted
During cluster creation, you'll see:
```
? Create the OIDC provider for cluster 'hemanth-rosa'? (Y/n)
```
Press Y or Enter to confirm.

Why?

This OIDC provider is required for IAM Roles for Service Accounts (IRSA).

## ✅ 6. Watch Cluster Provisioning
```bash
rosa describe cluster -c hemanth-rosa
rosa logs install -c hemanth-rosa
```
Provisioning takes ~30–45 minutes.
## ✅ 7. Create a Cluster Admin User
After the cluster status is ready:
```bash
rosa create admin -c hemanth-rosa
```
✅ Save:

* Username

* Password

* Console URL

## ✅ 8. Login with oc
```bash
oc login https://api.hemanth-rosa.us-east-1.openshiftapps.com:6443 \
  --username cluster-admin \
  --password <password-from-create-admin>
```
## ✅ 9. Verify Cluster Status
```bash
oc get nodes
```
You should see the nodes in a `Ready` state.
## ✅ 10. Access the OpenShift Console
Open your browser and navigate to the console URL you saved earlier. Log in with the cluster admin credentials.
## ✅ 11. Configure CLI Access
```bash 
rosa create kubeconfig -c hemanth-rosa
```
This command updates your kubeconfig file to allow `oc` commands to interact with your ROSA cluster.



# 🟢 Handling Errors & Common Pitfalls

❗ Missing Account Roles
Error:
```
yaml
Copy
Edit
W: No suitable account with ROSA CLI-created account roles were found.
? Role ARN:
```
✅ Fix:
Run:
```bash
rosa create account-roles --mode auto --yes
```
Then retry rosa create cluster.

❗ OIDC Provider Prompt
Prompt:
``` 
? Create the OIDC provider for cluster 'hemanth-rosa'? (Y/n)
```
✅ Fix:
Answer Y to proceed.

❗ oc Missing Configuration
Error:
```
error: Missing or incomplete configuration info.
```
✅ Fix:
Create admin user and login:
```
rosa create admin -c hemanth-rosa

oc login ...
```
❗ Stopping Cluster Creation Mid-Process
If you decide to stop (e.g., to avoid costs), delete the cluster any time:
```
rosa delete cluster -c hemanth-rosa --yes
```
✅ All AWS resources created so far will be cleaned up.

🟢 Deletion and Cleanup
Delete the cluster:
```bash
rosa delete cluster -c hemanth-rosa --yes
```
Delete the account roles:
```bash
rosa delete account-roles --mode auto --yes
```
Delete the OIDC Provider:
Go to AWS Console:

IAM ➡ Identity Providers ➡ Select the OIDC Provider ➡ Delete

✅ Tip: Always verify that no leftover EC2, ELB, or EBS volumes remain.

# 🟢 Cost Optimization Tips
Use --replicas=1 and smaller instance types (t3.large) for testing.

Delete clusters immediately after evaluation.

Monitor AWS billing dashboards for resource consumption.

# 🟢 Helpful Commands Cheat Sheet
List clusters
```bash
rosa list clusters
````
Describe cluster
```
rosa describe cluster -c hemanth-rosa
```
Get admin credentials again
```
rosa create admin -c hemanth-rosa
```

List nodes
```bash
oc get nodes
```
Delete cluster
```bash
rosa delete cluster -c hemanth-rosa --yes
```
🧹 Conclusion
This guide provides everything needed to create, manage, and delete ROSA clusters via CLI, ensuring predictable, automatable workflows.

✅ Keep this file in your Git repo as a reference for yourself or your team.

Author:
Hemanth Tadikonda
June 2025


✅ **All set!**
This format follows the style you requested, with clear headings, section dividers, and clean code blocks.

If you’d like, I can help you customize it further or prepare a companion shell script.








