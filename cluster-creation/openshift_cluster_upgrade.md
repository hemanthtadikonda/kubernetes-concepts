
# 🚀 OpenShift 4.XX → Upgrade Guide

This guide explains how to **safely upgrade an OpenShift cluster** to the latest stable release with **pre-checks, implementation steps, post-checks, common issues, and rollback options**.  
It is structured for **easy execution and GitHub readability**.


<!-- PRE CHECK Section -->

<summary><h3>1. PRE CHECK</h3></summary>

<details>
<br/>

### ✅ 1.1 Validate Cluster Health
```bash
oc get clusterversion
oc get nodes
oc get co
oc get pods --all-namespaces


* All nodes → `Ready`
* Cluster Operators (COs) → `Available=True`, `Progressing=False`, `Degraded=False`
* No pods in `CrashLoopBackOff`

```
### ✅ 1.2 Verify Storage & Disk Space

On **master nodes** (etcd hosts):

```bash
df -h /var/lib/etcd
```

* Ensure at least **20% free disk space**.

---

### ✅ 1.3 Backup etcd (Critical)

Take etcd snapshot before upgrade:

Before starting an upgrade, always take a **backup of etcd** and **static pod resources**.  
This ensures you can restore the cluster if the upgrade fails or etcd becomes corrupted

### ✅ 0.1 Backup Using `cluster-backup.sh` (Recommended)

1. SSH into a master node:
```bash
oc get nodes -l node-role.kubernetes.io/master=
ssh core@<master-node>
```
2. Run the backup script:
```
sudo -i
cd /usr/local/bin
```
Take backup to /home/core/backup
```
/usr/local/bin/cluster-backup.sh /home/core/backup
```
3. Verify backup artifacts:
```
ls -l /home/core/backup
```
##### You should see:

* snapshot_<timestamp>.db (etcd database snapshot)

* static_kuberesources_<timestamp>.tar.gz (static pod manifests)
4. Copy backup off the cluster (to S3, NFS, or secure storage):
```
scp -r /home/core/backup <user>@<backup-server>:/backups/ocp/
```
###  ✅ 0.2 Backup Using oc adm cluster-backup
From OCP 4.10+:
```
oc adm cluster-backup /home/core/backup
```
This performs the same action as **cluster-backup.sh**
### ✅ 0.3 Manual etcd Snapshot (Alternative Method, Not preferable)
Although you can run:
```bash
ETCD_POD=$(oc get pods -n openshift-etcd -o name | head -1)
oc exec -n openshift-etcd $ETCD_POD -- etcdctl snapshot save /var/lib/etcd/snapshot.db
oc cp openshift-etcd/$ETCD_POD:/var/lib/etcd/snapshot.db ./snapshot.db
```
This only saves etcd data, **not static pod manifests**, and is **not supported for full recovery.**
* Store snapshot in a **safe external location**.

---

### ✅ 1.4 Validate Networking

Check API & apps DNS:

```bash
dig api.<cluster_name>.<base_domain>
dig console-openshift-console.apps.<cluster_name>.<base_domain>
```

* Ensure they resolve to correct LoadBalancer/Ingress endpoints.

---

### ✅ 1.5 Validate Workloads

Check Pod Disruption Budgets (PDBs):

```bash
oc get pdb -A
```

* Critical apps should have PDBs.
* Scale down non-critical workloads to save resources.

---

### ✅ 1.6 Validate Upgrade Channel

Check upgrade channel:

```bash
oc get clusterversion -o jsonpath='{.items[0].spec.channel}{"\n"}'
```

If needed, set:

```bash
oc adm upgrade channel stable-4.17
```

</details>



<!-- IMPLEMENTATION Section -->


<summary><h3>2. IMPLEMENTATION</h3></summary>

<details>
<br/>

### 🚦 2.1 Check Available Updates

```bash
oc adm upgrade
```

Example:

```
Cluster version is 4.17.29
Updates available: 4.17.30, 4.17.31
```

---

### 🚦 2.2 Initiate Upgrade

Upgrade to desired stable version:

```bash
oc adm upgrade --to=4.17.31
```

* **CVO** (Cluster Version Operator) manages upgrade.
* **MCO** (Machine Config Operator) drains & reboots nodes one by one.

---

### 🚦 2.3 Monitor Progress

Cluster version:

```bash
watch -n30 oc get clusterversion
```

Operators:

```bash
oc get co
```

Nodes:

```bash
watch oc get nodes
```

---

### 🚦 2.4 Pause/Resume Upgrade (If Needed)

Pause:

```bash
oc adm upgrade pause
```

Resume:

```bash
oc adm upgrade resume
```

</details>



<!-- POSTCHECKS Section -->

<summary><h3>3. POSTCHECKS</h3></summary>

<details>
<br/>

### 🔎 3.1 Verify Cluster Version

```bash
oc get clusterversion
```

✅ Should show `Desired=True`, `Available=True`, `Progressing=False`.

---

### 🔎 3.2 Verify Cluster Operators

```bash
oc get co
```

✅ All should be `Available=True`, `Degraded=False`.

---

### 🔎 3.3 Verify Nodes

```bash
oc get nodes -o wide
```

✅ All nodes `Ready` & running updated version.

---

### 🔎 3.4 Verify Workloads

```bash
oc get pods --all-namespaces
```

✅ No pods in error state.

---

### 🔎 3.5 Application Test

Deploy a sample app:

```bash
oc new-project test-upgrade
oc new-app quay.io/openshift/hello-openshift
oc expose svc/hello-openshift
oc get route
```

Open route in browser → should display **Hello OpenShift!**

</details>



<!-- ROLLBACK Section -->


<summary><h3>4. ROLLBACK / RECOVERY</h3></summary>

<details>
<br/>

⚠️ Important: OpenShift does not support a direct rollback to a previous version once upgrade completes.
The following procedures explain  recovery options to minimize downtime.

### 🔄 4.1 Pause/Resume Upgrade (If Issues Detected Midway)

If cluster issues appear during the upgrade (e.g., operators stuck in Progressing state), pause it:
```
oc adm upgrade pause
```

This prevents further rollout of updates.

Fix the issue (e.g., check operator logs, resources).

Once resolved, resume upgrade:
```
oc adm upgrade resume
```


* Use this option before etcd or critical nodes are fully impacted.

### 🔄 4.2 Full Cluster Recovery via etcd Restore
1. Copy backup snapshot to a master node:
```
scp <backup-server>:/backups/ocp/snapshot_<timestamp>.db /home/core/backup/
scp <backup-server>:/backups/ocp/static_kuberesources_<timestamp>.tar.gz /home/core/backup/
```
2. SSH into a master node:
```
ssh core@<master-node>
sudo -i
```
3. Stop static pods on all masters:
```
mv /etc/kubernetes/manifests /etc/kubernetes/manifests.bak
```
4. Run restore command:
```agsl
/usr/local/bin/cluster-restore.sh /home/core/backup
```
* No need to write or create `cluster-restore.sh` — it’s already available out-of-the-box in OpenShift.
* This restores etcd snapshot + static pod manifests.
5. Restart services:
```
mv /etc/kubernetes/manifests.bak /etc/kubernetes/manifests
```
---
> Alternatively, manually restore etcd:
<details>
<br/>

#### To restore etcd manually:
1. SSH into a master node:
2. Stop kubelet:
```
systemctl stop kubelet
```
3. Restore etcd from snapshot:
```
mv /home/core/backup/snapshot_<timestamp>.db /var/lib/etcd/
mv /var/lib/etcd /var/lib/etcd-backup
mkdir /var/lib/etcd
etcdctl snapshot restore /var/lib/etcd/snapshot_<timestamp>.db --data-dir /var/lib/etcd
```
4. Reconfigure static pods (etcd, kube-apiserver, kube-scheduler, kube-controller-manager):

5. Update manifest files under `/etc/kubernetes/manifests/` to point to restored etcd.
    - Edit `/etc/kubernetes/manifests/etcd-pod.yaml` to ensure `--data-dir=/var/lib/etcd` is correct.
    - Ensure other static pod manifests are intact.

6. Restart kubelet:
```
systemctl start kubelet
```
7. Verify etcd health:
```
oc get etcd -n openshift-etcd
```
8. Restore static pod manifests:
```
tar -xzvf /home/core/backup/static_kuberesources_<timestamp>.tar.gz -C /etc/kubernetes/manifests/
```
9. Restart kubelet again:
```
systemctl restart kubelet
```
10. Monitor cluster status:
```
watch -n30 oc get clusterversion
```

</details>

#### 👉 This will roll back the cluster to the exact state at snapshot time (including OpenShift version).
* Downtime: Typically 20–40 min, depending on restore speed.
Best practice: Always take etcd snapshot right before upgrade.

### 🔄 4.3 Worker Node Recovery (Rollback for Workers)

If only **worker nodes** fail during upgrade (e.g., kubelet issues, OS upgrade failure, or nodes stuck in `NotReady` state), you can **rollback workers** without impacting the control plane.  
This method uses **MachineSets** to recreate workers with the **previous OpenShift version**, ensuring workloads continue running with minimal downtime.

---

#### 📌 Step 1: Identify Failed Worker Nodes
```bash
oc get nodes
oc describe node <failed-node>
```
Look for nodes stuck in:

* NotReady

* SchedulingDisabled

Or failing due to kubelet/service issues.

📌 Step 2: Check Current MachineSets
```
oc get machinesets -n openshift-machine-api
```
Example output:

```
NAME                                 DESIRED   CURRENT   READY   AVAILABLE   AGE
worker-us-east-1a                    2         2         2       2           25d
worker-us-east-1b                    2         2         2       2           25d
```
📌 Step 3: Scale Down Failed MachineSet
* If the upgrade created a new MachineSet (with upgraded image), scale it down:

```
oc scale machineset <new-machineset-name> -n openshift-machine-api --replicas=0
```
This prevents creation of additional broken workers.

📌 Step 4: Scale Up Previous Working MachineSet
* Identify the older MachineSet (with pre-upgrade version).

Scale it up to replace failed workers:

```
oc scale machineset <old-machineset-name> -n openshift-machine-api --replicas=<desired-number>
```
This will provision new workers using the older OS/RHCOS version.

📌 Step 5: Verify Node Provisioning
* Check worker nodes are coming up:
```
oc get nodes -w
```
Wait until new workers show Ready state.

Ensure workloads are migrating properly with default pod eviction.

📌 Step 6: Drain & Delete Failed Nodes
For each failed node:
```
oc adm cordon <failed-node>
oc adm drain <failed-node> --ignore-daemonsets --delete-emptydir-data
oc delete node <failed-node>
```
* This ensures workloads are safely rescheduled to the healthy workers.

📌 Step 7: Validate Workloads
* Check Deployments/StatefulSets:
```
oc get pods -A -o wide
```
* Ensure applications are running on the new worker nodes.

* Validate important workloads (Ingress, Monitoring, Registry, Custom Apps).

📌 Step 8: Monitor MCO (Machine Config Operator)
Verify that the Machine Config Operator has reconciled:

```
oc get co machine-config
oc logs -n openshift-machine-config-operator deploy/machine-config-operator
```
#####  ✅ Best Practices
Always keep at least one MachineSet with older version until upgrade success is confirmed.

Perform rollback AZ by AZ (if in multi-AZ) to avoid full capacity loss.

Use PodDisruptionBudgets (PDBs) to protect critical apps during node drain.

Maintain cluster autoscaler for automated recovery if configured.

##### ⚠️ Risks
Longer pod rescheduling times if worker capacity is insufficient.

If workloads have local storage, manual migration is required.

Any custom OS changes (not part of MachineConfig) may be lost when rolling back.

### 🔄 4.4 Best Practices to Minimize Downtime During Recovery

* ✅Always upgrade one environment at a time (Dev → QA → Prod).

* ✅Use multi-master, highly available etcd to reduce single point of failure.

* ✅Keep backup clusters or disaster recovery clusters (common in production).

* ✅Use maintenance windows and inform app teams about possible downtime.

* ✅Automate etcd backup before every upgrade and store securely.

* ✅For worker node recovery → rely on autoscaling & multiple replicas to avoid downtime.

</details>


---

## ✅ Upgrade Checklist(summary)

1. Run **Pre-checks** (health, etcd backup, networking, workloads).
2. Run `oc adm upgrade` → identify available versions.
3. Upgrade using `oc adm upgrade --to=<version>`.
4. Monitor with `oc get clusterversion`, `oc get co`, `oc get nodes`.
5. Perform **Post-checks** (apps, workloads, operators).
6. If broken → pause upgrade or restore from etcd snapshot.





