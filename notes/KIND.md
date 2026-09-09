# Kind for k8s

## index 


--- 

## understand Kind ( Kubernetes IN Docker)
- Kind (Kubernetes IN Docker) is an open-source tool for running local Kubernetes clusters using Docker containers as "nodes."
- it uses Docker containers to simulate Kubernetes nodes. 


---





---

## commonly used commands 


---

## compare : kind vs. minikube

Both run real, unmodified Kubernetes — same API server, same objects, same `kubectl`.
The difference is how a "node" gets created and how much convenience is bundled on top.

| | **kind** | **minikube** |
|---|---|---|
| **What a node is** | a Docker container running kubelet + containerd | a VM by default (HyperKit/QEMU/VirtualBox), or a container with `--driver=docker` |
| **Startup / footprint** | faster, lighter — no VM layer | heavier with a VM driver; comparable with the docker driver |
| **Multi-node** | first-class, declared in a YAML cluster config | supported via `--nodes N`, historically less robust |
| **Addons** | none — install ingress, metrics-server, dashboard yourself | built-in catalog: `minikube addons enable ingress / metrics-server / registry / dashboard / csi-hostpath-driver` |
| **NodePort access** | must declare `extraPortMappings` **at cluster creation** — can't add later without recreating | `minikube service <name>` opens it in the browser; no upfront config |
| **LoadBalancer type** | needs MetalLB or cloud-provider-kind | `minikube tunnel`, or the metallb addon |
| **Ingress** | manual ingress-nginx install + port mappings for 80/443 | one addon command |
| **Swapping the CNI** | `disableDefaultCNI: true` in the config, then install Cilium/Calico yourself | `minikube start --cni=calico` (or `cilium`) — one flag |
| **Default storage** | local-path-provisioner ships as the default StorageClass; PVCs work out of the box | built-in storage-provisioner; PVCs work out of the box |
| **Loading local images** | `kind load docker-image myapp:tag` | `minikube image load myapp:tag`, or `eval $(minikube docker-env)` |
| **CI pipelines** | the standard — Kubernetes' own CI uses it; trivial in GitHub Actions | possible but heavier, rarely chosen |
| **Apple Silicon** | fine via Docker Desktop or colima | fine, docker driver recommended |

**Takeaway:** minikube is the friendlier on-ramp (addons handle ingress, LoadBalancer and
port exposure for you); kind is closer to CI and production workflows and forces you to
understand what a NodePort or an ingress controller actually is.

---

## resource

- [Minikube vs Kind: A Comprehensive Comparison](https://betterstack.com/community/guides/scaling-docker/minikube-vs-kubernetes/)
- [Getting Started with KIND Kubernetes](https://www.youtube.com/watch?v=133B-s1YYCA&list=PL1xPpLHBFNWvKPI0ofmFzJn9lrWiqGukT&index=1)


### namual
- [Kind | Quick Start (with package manager)](https://kind.sigs.k8s.io/docs/user/quick-start/#installing-with-a-package-manager)