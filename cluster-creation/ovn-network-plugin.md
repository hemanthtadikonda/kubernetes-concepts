# OpenShift — OVN-Kubernetes (OVN-K8s) Deep Dive

> **Status:** Updated — corrected historical/version notes (OVN default from OpenShift **4.11**; OpenShift SDN **deprecated 4.14**, removed/unsupported for later upgrades). See the **Version History** section.

---

## Table of contents

1. TL;DR
2. Version history (corrected)
3. Why OVN-Kubernetes is important / high-level benefits
4. OVN architecture & components (deep dive)
5. Quick checks & diagnostics (commands)
6. Hands-on labs (beginner → pro)
7. Migration notes (OpenShift SDN → OVN)
8. Debugging & observability
9. Performance tuning & best practices
10. Advanced topics & integrations
11. Example manifests & helper scripts
12. References & further reading

---

## 1. TL;DR

OVN-Kubernetes (OVN-K8s) is a CNI implementation that uses OVN (Open Virtual Network) and Open vSwitch (OVS) to provide overlay networking, distributed routing, and native enforcement of Kubernetes Network Policies. For OpenShift, OVN became the **default** CNI for *new installations starting with OpenShift 4.11*. OpenShift SDN was deprecated later (see Version History).

This document is a single-file guide (ready for GitHub) with commands, YAML examples, and labs to go from beginner to pro.

---

## 2. Version history (corrected)

* **OCP ≤ 4.10** — default CNI: **OpenShift SDN** on most installs.
* **OCP 4.11** — OVN-Kubernetes becomes the *default* CNI for **new** installations. (Existing clusters using OpenShift SDN continued to run SDN until migration.)
* **OCP 4.14** — OpenShift SDN is **deprecated**.
* **OCP 4.15** — OpenShift SDN is **no longer available as an option for new installations** in OKD / OpenShift docs.
* **OCP 4.17** — Clusters running OpenShift SDN **must migrate** to OVN-Kubernetes before upgrading to 4.17.

> Keep this timeline in your README; OpenShift lifecycle notes may update so always check Red Hat docs for the latest release-specific guidance.

---

## 3. Why OVN-Kubernetes is important — benefits

* **Distributed routing**: east–west routing is distributed across nodes — no single routing bottleneck.
* **Overlay networking** (Geneve): isolates tenant/pod networks without touching underlay.
* **Scalability**: designed for large clusters.
* **Native NetworkPolicy support**: built-in enforcement for Kubernetes NetworkPolicy objects.
* **Egress & NAT features**: egress IPs, egress firewall semantics.
* **Service load-balancing**: OVN includes an L4 load balancer for ClusterIP/NodePort services.
* **Dual-stack & IPv6 support** (mature in newer releases).

---

## 4. OVN Architecture & components (deep dive)

### Key components

* **OVN Northbound DB (NBDB)** — desired logical topology (logical switches, routers, ACLs).
* **OVN Southbound DB (SBDB)** — state required to program OVS on nodes (logical flows etc.).
* **OVN Central / Northd** — translates NBDB to SBDB.
* **ovn-controller** — runs on each node and programs OVS according to SBDB (and reports local status).
* **ovnkube-master / ovnkube-node** — OpenShift packaged components that integrate OVN with Kubernetes (watching k8s objects and writing to NBDB).
* **Open vSwitch (OVS)** — datapath on each node implementing flows and tunnels (Geneve VXLAN alternatives exist but OVN uses Geneve by default).

### Logical constructs

* **Logical Switch** — per Kubernetes node or per namespace/pod network segmentation depending on configuration.
* **Logical Router** — distributed router connecting logical switches.
* **ACLs** — implemented as logical flows; correspond to NetworkPolicy + security rules.
* **Load balancers** — L4 LB to implement service VIPs and affinity.

### Tunneling / encapsulation

OVN uses **Geneve** tunnels by default (configurable). Each node has a local OVS bridge that sends/receives Geneve traffic.

---

## 5. Quick checks & diagnostics (commands)

> Run these on nodes / via `oc debug node/<node>` as needed.

### Check which network provider the cluster uses

```bash
oc get network.operator cluster -o jsonpath='{.spec.defaultNetwork.type}\n'
# -> OVNKubernetes  (or OpenShiftSDN)
```

### List OVN/OpenShift pods

```bash
oc get pods -n openshift-ovn-kubernetes -o wide
oc get pods -n openshift-sdn -o wide  # if present
```

### OVS / OVN tools (on node)

```bash
# OVS bridges and ports
sudo ovs-vsctl show
sudo ovs-ofctl dump-ports-desc br-int

# OVN Southbound / Northbound
sudo ovn-sbctl show
sudo ovn-nbctl show

# OVN systemctl/containers logs
oc logs -n openshift-ovn-kubernetes <ovnkube-node-pod>
oc logs -n openshift-ovn-kubernetes <ovnkube-master-pod>
```

### Network policy checks

```bash
# Show applied NetworkPolicy objects in namespace
oc get networkpolicy -n my-namespace -o yaml

# From inside a pod, check connectivity
kubectl exec -n my-namespace pod/mypod -- ping -c 3 <ip>
```

---

## 6. Hands-on labs (beginner → pro)

> Each lab assumes you already have a working OpenShift cluster and `oc` configured.

### Lab 0 — Pre-reqs

* `oc` client logged into cluster
* cluster admin permissions for some tasks
* `jq`, `yq` helpful on workstation

### Lab 1 — Verify CNI & OVN pods (Beginner)

1. Check default network type:

```bash
oc get network.operator cluster -o jsonpath='{.spec.defaultNetwork.type}\n'
```

2. List OVN pods and their node placement:

```bash
oc get pods -n openshift-ovn-kubernetes -o wide
```

3. Pick a worker node and run OVN tools there (use `oc debug node/<node>` or SSH if permitted):

```bash
sudo ovs-vsctl show
sudo ovn-sbctl show
sudo ovn-nbctl show
```

---

### Lab 2 — Deploy two pods and test connectivity (Beginner)

```bash
oc new-project ovn-test
oc run pod-a --image=busybox --restart=Never -- sleep 3600
oc run pod-b --image=busybox --restart=Never -- sleep 3600

# wait for pods Ready
oc get pods -n ovn-test -o wide

# exec and test
oc exec -n ovn-test pod/pod-a -- ping -c 3 <pod-b-ip>
```

---

### Lab 3 — NetworkPolicy basics (Intermediate)

1. Create deny-all policy:

```yaml
# deny-all.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: ovn-test
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

```bash
oc apply -f deny-all.yaml
# test from pod-a to pod-b -> should fail
```

2. Allow only pod-a to talk to pod-b:

```yaml
# allow-a-to-b.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-a-to-b
  namespace: ovn-test
spec:
  podSelector:
    matchLabels:
      app: pod-b
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: pod-a
```

```bash
oc label pod pod-a app=pod-a
oc label pod pod-b app=pod-b
oc apply -f allow-a-to-b.yaml
# test connectivity -> only pod-a should reach pod-b
```

---

### Lab 4 — Egress IP (Intermediate)

> Requires cluster admin access and appropriate IP ranges. Example uses NetNamespace patching.

```bash
oc create namespace ovn-egress
# assign egress IP (example IP must be valid and routed by infra)
oc patch netnamespace ovn-egress --type=merge -p '{"egressIPs":["10.0.0.50"]}'
```

Validate: from a pod in `ovn-egress`, check outbound IP seen by external service.

---

### Lab 5 — Inspect logical topology (Pro)

On an administrative node with `ovn-*` tools:

```bash
ovn-nbctl show   # logical switches/routers
ovn-sbctl show   # tunnels and chassis
ovn-trace "<packet description>"  # simulate/troubleshoot flows
```

Use `ovn-trace` to follow how a given packet will be processed by OVN logical flows — very powerful for debugging ACLs and DNAT/SNAT logic.

---

### Lab 6 — Simulate an offline migration (Pro — dry run)

> This is a safe dry-run checklist to help plan a real migration.

1. Read documentation and create backups of `etcd` and cluster manifests.
2. Ensure node spare capacity (evacuate apps if needed).
3. Test migration on a staging cluster of similar size and configuration.
4. Document pod IP plan expectations — IPs may change.

(See Migration notes below for operational steps.)

---

## 7. Migration notes (OpenShift SDN → OVN)

**Important high-level points**:

* SDN was deprecated in OCP 4.14 and cannot be used for upgrades to 4.17 — **you must migrate to OVN before a 4.17 upgrade**.
* Red Hat documents an **offline migration** method; historically, migrations may require some downtime and node reboots.
* The migration is non-trivial for large clusters — consult Red Hat support for clusters above certain scale thresholds.

**Planning checklist**:

* Read the official migration guide for your OCP/OKD version.
* Ensure backups (etcd, manifests) and a rollback plan.
* Prepare spare node capacity and maintenance windows.
* Test the migration path in a lab/staging cluster.

**Notes on live migration**: There are community/Red Hat materials about live migration, but these are environment-dependent and often have limitations or caveats. Do not assume zero-downtime without testing for your workloads.

---

## 8. Debugging & observability

* **Logs**: `oc logs -n openshift-ovn-kubernetes <pod>`
* **OVS**: `sudo ovs-vsctl show` and `ovs-ofctl dump-flows br-int`
* **OVN DBs**: `ovn-nbctl show`, `ovn-sbctl show`
* **Trace packets**: `ovn-trace` (simulate flows through logical topology)
* **Prometheus metrics**: OVN components expose metrics — use them in Grafana dashboards for health and performance.

---

## 9. Performance tuning & best practices

* **MTU & fragmentation**: Set MTU carefully so Geneve encapsulation doesn’t cause fragmentation.
* **Offloading**: Be cautious with large scale; offload features to NICs where stable and tested.
* **Node sizing**: Ensure nodes have CPU headroom for OVS and ovn-controller.
* **Chunked rollouts**: When changing OVN settings, roll changes gradually and monitor.

---

## 10. Advanced topics & integrations

* **BGP / External Routing** integration (use cases: bare metal, advanced routing).
* **Multicluster networking** — Submariner + OVN interaction patterns.
* **Service Mesh** — OVN + Istio / Linkerd interactions (endpoint discovery, mTLS not impacted by OVN but routing/east-west policies are).
* **Integration with cloud-provider load balancers** for North-South traffic.

---

## 11. Example manifests & helper scripts

(Short snippets included earlier in labs; keep a `examples/` folder in the repo and expand with operator lifecycle scripts like: `verify-ovn.sh`, `ovn-dump.sh`, `ovn-trace-example.sh`.)

---

## 12. References & further reading

(Keep these links in your GitHub README for quick access):

* Red Hat: OVN-Kubernetes default CNI network provider (OCP 4.11 docs)
* OpenShift 4.14 release notes (deprecation of OpenShift SDN)
* OpenShift preparing to update a cluster (note: must migrate to OVN before 4.17 upgrades)
* OKD/Red Hat migration guides for offline migration
* ovn-kubernetes upstream: [https://github.com/ovn-org/ovn-kubernetes](https://github.com/ovn-org/ovn-kubernetes)

---

### How to use this file

1. Save as `OpenShift_OVN-Kubernetes_Deep_Dive.md` in your repository.
2. Expand `examples/` with your own scripts and YAML files.
3. Add diagrams (Mermaid) and screenshots — GitHub will render mermaid if enabled in repo settings.

