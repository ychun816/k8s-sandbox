# TODO

Learning path for this sandbox. The point is to build every piece by hand and be
able to explain *why* it exists — so these are tasks, not answers. Where a step
says "figure out", resist looking up a finished manifest; `kubectl explain` and
`--help` are the intended route.

Order matters. Each stage produces something the next one needs.

**Scope.** Stages 1-8 are the whole sandbox: basic kind setup and deployment,
finishing when your own image serves traffic through an Ingress and you can
diagnose each layer when it breaks. Helm, GitOps, CI and observability are
filmory's phases, not stages here — see [where this ends](#where-this-ends).

## index
Stage 1: [prepare the tools] Installs and pins `kind`, `kubectl`, and other tools
Stage 2: [create a default platform] Creates a default, single-node Kubernetes cluster
Stage 3: [design the platform] cluster exists => Creates a deliberate 3-node cluster from YAML
Stage 4: [run an application on it] one Pod exists, but nothing recreates it => Runs the `nginx` Pod inside the cluster
> placing a workload Pod inside the existing cluster, and Kubernetes chooses the node
Stage 5: Deployment manages Pods and recreates them
Stage 6: Service gives Pods a stable network address
Stage 7: Ingress exposes the Service externally


- [Stage 1 — Make the tools runnable](#stage-1--make-the-tools-runnable)
- [Stage 2 — A cluster the lazy way](#stage-2--a-cluster-the-lazy-way)
- [Stage 3 — A cluster you designed](#stage-3--a-cluster-you-designed)
- [Stage 4 — First Pod](#stage-4--first-pod)
- [Stage 5 — Deployment](#stage-5--deployment)
- [Stage 6 — Service](#stage-6--service)
- [Stage 7 — Ingress](#stage-7--ingress)
- [Stage 8 — Your own image](#stage-8--your-own-image)
- [Where this ends](#where-this-ends)

---

## Stage 1 — Make the tools runnable

`kind get clusters` fails right now with *"No version is set for shim: kind"*.
mise puts shims on `PATH`, not binaries — the tool is downloaded but no version
is selected, and the shim refuses to guess. Fixing this is stage 1.  **— done 2026-09-09**

- [x] Install `mise` CLI
```bash
curl https://mise.run | sh

# verify the install 
~/.local/bin/mise --version
# mise 2026.x.x
``` 
- [x] Run `mise ls` — see what is already downloaded
- [x] Run `which -a kubectl` — **there is more than one.** Something outside
      mise provides a kubectl too. Work out which wins and why
- [x] Pin versions for this directory (try `mise use kind@0.32.0`, then read the
      `mise.toml` it wrote — decide if you want the others pinned too)
- [x] Verify: `kind get clusters` exits clean with no output
- [x] Verify: `kubectl version --client` now matches what `mise ls` reports
- [x] write a script to check+download the needed tools 

**Why bother:** filmory pins the same way. A cluster built with one kubectl and
driven by another is a genuine source of weird failures, and pinning is what
makes the mismatch visible instead of mysterious.

## Stage 2 — A cluster the lazy way

Before writing any config, make the default cluster so you have something to
compare against. **This one is deliberately a single node** — no config file, no
workers. The three-node cluster is stage 3; the point here is to see what the
defaults give you, so the config you write next has something to differ from.

- [x] `kind create cluster --name k8s-sandbox`
- [x] `kubectl get nodes` — how many? What roles?
- [x] `docker ps` — **find your node in the list.** This is the whole idea of
      kind: a "node" is a Docker container
- [x] `docker exec -it k8s-sandbox-control-plane crictl ps` — the containers running
      *inside* the node. Note this is `crictl`, not `docker`
```bash
➜  k8s-sandbox git:(master) ✗ docker exec -it k8s-sandbox-control-plane crictl ps
CONTAINER           IMAGE               CREATED             STATE               NAME                      ATTEMPT             POD ID              POD                                                 NAMESPACE
e9a503ee3549f       fe81a497e85f1       5 minutes ago       Running             coredns                   0                   03b2296300bb1       coredns-589f44dc88-drsp8                            kube-system
a0162a73356c5       fe81a497e85f1       5 minutes ago       Running             coredns                   0                   81de1131088c4       coredns-589f44dc88-hp742                            kube-system
41e2f7c6e063b       3501a03785a84       5 minutes ago       Running             local-path-provisioner    0                   b217814aede3b       local-path-provisioner-855c7b7774-p88w2             local-path-storage
e3f50943475cf       f2ede2b789a61       6 minutes ago       Running             kindnet-cni               0                   7bb774f7d7771       kindnet-rx4k6                                       kube-system
65650b39bd2b5       01ad784c02283       6 minutes ago       Running             kube-proxy                0                   4002102753e9a       kube-proxy-r4rs9                                    kube-system
8cf057235f944       4923943f21256       6 minutes ago       Running             kube-apiserver            0                   2019d13415ab3       kube-apiserver-k8s-sandbox-control-plane            kube-system
d95758d134b75       39d983367f38c       6 minutes ago       Running             kube-controller-manager   0                   7408e699b97df       kube-controller-manager-k8s-sandbox-control-plane   kube-system
fc83e0a3a8a20       76e62361b06b5       6 minutes ago       Running             kube-scheduler            0                   dd8fd1c145b37       kube-scheduler-k8s-sandbox-control-plane            kube-system
469ca78e7b5ea       6da6ea097b384       6 minutes ago       Running             etcd                      0                   eb3aaec006069       etcd-k8s-sandbox-control-plane                      kube-system

What's next:
    Try Docker Debug for seamless, persistent debugging tools in any container or image → docker debug k8s-sandbox-control-plane
    Learn more at https://docs.docker.com/go/debug-cli/
```
- [ ] Find the API server port: `docker ps` shows `127.0.0.1:5xxxx->6443`.
      Confirm it matches `kubectl config view --minify`
- [ ] `kind delete cluster --name k8s-sandbox`

**Answer before moving on:** why is the kubeconfig pointing at a random high port on localhost rather than at 6443?

## Stage 3 — A cluster customized/designed

Now write the config. Aim for 1 control-plane + 2 workers, and port mappings so
you can reach the cluster from your browser later without `port-forward`.

- [ ] Read the [kind configuration docs](https://kind.sigs.k8s.io/docs/user/configuration/)
- [ ] Write `clusters/k8s-sandbox.yaml` — set `kind: Cluster`, the apiVersion, and a
      `nodes:` list
- [ ] Add `extraPortMappings` on the control-plane: container 80 → host 8080,
      container 443 → host 8443. **Note these are per-node, not per-cluster**
- [ ] Add a `node-labels: ingress-ready=true` kubeadm patch on the control-plane.
      You will not use it until stage 7 — work out now what it is *for*
- [ ] `kind create cluster --name k8s-sandbox --config clusters/k8s-sandbox.yaml`
- [ ] verify:
```bash
# check existing clusters
kind get clusters

# check exsiting nodes (all)
kubectl get nodes -w

# check exisitng , specify a name
kind get nodes --name k8s-sandbox
```
- [ ] Nodes come up `NotReady` then go `Ready`. Watch it: `kubectl get nodes -w`.
      **Figure out what has to start before a node is Ready**
- [ ] `kubectl get pods -n kube-system` — identify what each one does. You should
      be able to name the API server, etcd, scheduler, controller-manager, DNS,
      the CNI and kube-proxy
- [ ] **Version skew check** (same as filmory Phase 1): compare the node version
      kind reports against `kubectl version`. More than one minor apart means
      pinning the node image or moving kubectl's pin

## Stage 4 — First Pod

restart cluster 
```bash
open -a Docker

docker ps
kind get nodes --name k8s-sandbox
kubectl get nodes

kubectl run web --image=nginx
kubectl get pod -o wide
kubectl describe pod web
```


- [ ] `kubectl run` a single pod imperatively — any small image
- [ ] `kubectl get pod -o wide` — which node did it land on? Who chose?
- [ ] `kubectl describe pod` — read the Events at the bottom, top to bottom.
      That list is the scheduling story
- [ ] Now write it as YAML in `manifests/`. Use
      `kubectl run ... --dry-run=client -o yaml` to get a skeleton, then strip
      every field you cannot justify
- [ ] Add `resources.requests` and a `limits.memory`. **Work out what the
      scheduler does with `requests` that it does not do with `limits`**
- [ ] `kubectl delete pod <name>` — note that nothing recreates it

**That last bullet is the entire argument for stage 5.** Don't skip it.

## Stage 5 — Deployment

- [ ] Write a Deployment with 3 replicas
- [ ] Get the `selector` / `template.metadata.labels` relationship right. Break
      it on purpose once and read the rejection — it is the most common mistake
- [ ] `kubectl get replicaset` — you did not create this. What made it?
- [ ] `kubectl delete pod -l <your-label>` and watch them return
- [ ] `kubectl scale` to 5, then back
- [ ] Add a `readinessProbe`. Then break it (wrong port) and watch pods run but
      never become Ready. **Understand Running vs Ready before continuing**
- [ ] Change the image tag, `kubectl rollout status`, then `kubectl rollout undo`

## Stage 6 — Service

- [ ] Write a ClusterIP Service selecting your pods
- [ ] Get `port` vs `targetPort` right — say out loud which is which
- [ ] `kubectl get endpointslices -l kubernetes.io/service-name=<svc>` —
      **this is the first thing to check whenever a Service "doesn't work"**
- [ ] Break the selector on purpose. Confirm the endpoint list goes empty and
      the Service still exists and still resolves
- [ ] Exec into a pod and `curl` the Service by DNS name. Work out the full form
      (`<svc>.<namespace>.svc.cluster.local`) and why the short name also works
- [ ] Try `type: LoadBalancer`. It will sit `<pending>` forever — **work out
      why, and what MetalLB does about it.** MetalLB is on filmory's stack table

**Experiment worth doing:** give your stage-4 standalone Pod the *same* labels
the Service selects on, and re-apply it. It joins the Service's endpoints, with
no Deployment involved. A Service selects on labels and has no idea what owns
the pods it routes to.

## Stage 7 — Ingress

An Ingress object does nothing on its own. It is inert config until a
*controller* reads it and reconfigures itself.

- [ ] Install an ingress controller (kind publishes a
      [ready-made nginx manifest](https://kind.sigs.k8s.io/docs/user/ingress/))
- [ ] `kubectl get pods -n ingress-nginx -o wide` — **which node did it land
      on?** Only one node has your port mappings from stage 3
- [ ] If it is on the wrong node, work out how to make the scheduler place it on
      the labelled one — and why a `nodeSelector` alone is not enough for a
      control-plane node
- [ ] Write the Ingress with `ingressClassName` and a path rule
- [ ] `curl http://localhost:8080/` repeatedly — confirm the backend rotates
- [ ] Trace the full path on paper: host port → ? → ? → ? → pod
- [ ] **Learn to read the failures**, they are all different causes:

| Symptom | Means |
|---|---|
| Connection refused | Nothing listening on the host port at all |
| Connection reset | Port published, but nothing behind it inside the node |
| 404 from nginx | Controller reachable, no Ingress rule matched |
| 503 from nginx | Rule matched, Service has no ready endpoints |

## Stage 8 — Your own image

- [ ] Build any trivial image locally with `docker build`
- [ ] Deploy it. **It will fail with `ErrImagePull`** even though `docker images`
      clearly shows it
- [ ] Work out why — the node has its own containerd, separate from your host
- [ ] Fix it with `kind load docker-image`
- [ ] Set `imagePullPolicy` correctly for a local tag, and work out why `:latest`
      is the wrong tag to use here

**This is the single highest-value kind-specific thing to know.** Almost every
"but the image is right there" problem is this.

---

## Where this ends

Stage 8 is the finish line. At that point you can build a cluster, get your own
image serving traffic through an Ingress, and tell the failure modes apart —
which was the whole objective.

What comes next belongs to **filmory**, not here. Listed so the handover is
obvious, but these are not sandbox stages and there is nothing to tick off:

| what | filmory phase |
|---|---|
| Helm — chart per service | Phase 4b, next up there |
| Kustomize — dev/staging/prod overlays | with 4b |
| ArgoCD — GitOps sync | Phase 5 |
| CI — build, push, bump the tag | Phase 6 |
| cert-manager, Prometheus, Loki | Phase 7+ |

Track the order in [filmory/INFRA.md](../filmory/INFRA.md), not the README's
tech table — INFRA.md deliberately works as a walking skeleton and warns against
working down the table.

**Come back here** only when one of those needs a throwaway cluster to fail on
first: a chart that will not template, a controller that will not schedule, an
overlay that produces the wrong YAML. That is the sandbox earning its keep, and
it does not need a new curriculum.

**One divergence to decide when you get there:** stage 7 teaches the
`networking.k8s.io/v1` Ingress, but filmory's stack table specifies **Gateway
API**. Different APIs, same problem. Learn Ingress first — simpler, and far more
written about — then port it as its own exercise before committing in filmory.
