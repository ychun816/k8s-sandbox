# kubernetes sandbox

practice hands-on Kind set up

---

## objective

Understand the **basic setup and deployment** of a kind cluster — well enough
to then do the complex deployment work in [filmory](../filmory) without
learning kubernetes and the app at the same time.

That sets a deliberate boundary:

| | here | filmory |
|---|---|---|
| **scope** | one cluster, one trivial app | the real stack |
| **goal** | understand each primitive | ship something |
| **when it breaks** | good, that was the exercise | a problem |
| **ends at** | stage 8 — your own image running | Phase 7+ |

**Done when** you can build a cluster, get your own image serving traffic
through an Ingress, and diagnose each layer when it fails. Anything past that
— Helm, GitOps, CI, observability — is filmory's work, not the sandbox's.

---

## index
- [objective](#objective)
- [general workflow](#general-workflow)
- [repo structure](#repo-structure)
- [quick start](#quick-start)
- [cluster shape](#cluster-shape)
- [roadmap](#roadmap)
- [relation to filmory](#relation-to-filmory)

---

## general workflow

A throwaway cluster to break things in. Nothing here is precious — when the
cluster gets into a strange state, deleting and recreating it is faster than
debugging it, and that is the point.

The loop for each topic:

```
        ┌──────────────── repeat for the next topic ────────────────┐
        │                                                           │
        ▼                                                           │
┌───────────────┐   ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ 1  imperative │──▶│ 2  declare    │──▶│ 3  break it   │──▶│ 4  write it up│
├───────────────┤   ├───────────────┤   ├───────────────┤   ├───────────────┤
│ kubectl run   │   │ same thing    │   │ wrong port    │   │ notes/*.md    │
│ expose, get   │   │ as YAML,      │   │ bad selector  │   │ symptom  ->   │
│ see it work   │   │ strip cruft   │   │ read the error│   │ cause         │
└───────────────┘   └───────────────┘   └───────────────┘   └───────────────┘
                            │
                            └─▶ cluster wedged?  kind delete cluster && kind create cluster
                                nothing here is precious — recreating beats debugging
```

**1 — imperative first.** `kubectl run`, `kubectl expose`. Fastest way to see
the thing exist and confirm it works at all.

**2 — then declarative.** Rewrite it as YAML, using
`--dry-run=client -o yaml` for a skeleton, then delete every field you cannot
justify. What survives is what you actually understand.

**3 — break it on purpose.** Wrong `targetPort`, mismatched selector, a
readiness probe pointed at a closed port. This is the step that transfers:
anyone can apply a working manifest, the skill is recognising *which* of five
identical-looking failures you are staring at.

**4 — write down the symptom, not the fix.** "Connection reset means the port
is published but nothing is behind it" is reusable. "I added a nodeSelector" is
not. That is what [notes/](notes/) is for.

---

## repo structure

```
k8s-sandbox/
│
├── README.md                   workflow, cluster shape, roadmap
├── TODO.md                     the curriculum, stage by stage
├── mise.toml                   pinned tool versions — single source of truth
│
├── scripts/
│   └── check-requisites.sh     verify tooling, install what is missing
│
├── notes/                      what was learned, and what the failures looked like
│   ├── KIND.md                 kind concepts, kind vs minikube
│   ├── MISE.md                 version pinning, command cheatsheet
│   └── *.png                   screenshots from the exercises
│
├── clusters/                   ─── stage 3 creates this ───
│   └── k8s-sandbox.yaml        node topology + host port mappings
│
└── manifests/                  Kubernetes resource definitions
  ├── pods/                    standalone Pod learning example
  │   └── nginx-pod.yaml
  ├── base/                    reusable application resources
  │   └── nginx/
  │       ├── deployment.yaml
  │       ├── service.yaml
  │       ├── ingress.yaml
  │       └── kustomization.yaml
  └── overlays/                environment-specific configuration
    ├── dev/
    │   └── kustomization.yaml
    └── prod/
      └── kustomization.yaml
```

Three kinds of file, and the distinction is worth keeping:

- **committed and load-bearing** — `mise.toml`, `clusters/`, `manifests/`.
  Delete one and something stops working.
- **the curriculum** — [TODO.md](TODO.md) and this README. What to do, in what
  order, and how to know a stage is finished.
- **what you learned** — [notes/](notes/). Written *after* an exercise, not
  before. [KIND.md](notes/KIND.md) and [MISE.md](notes/MISE.md) are the two so
  far.

The standalone Pod is kept outside the application base because it is a
learning example, not part of the normal application deployment. The base
contains reusable resources, while overlays select the base and add
environment-specific changes. Kustomize applies resources through an explicit
`kustomization.yaml`, so numbered directories are not necessary.

---

## quick start

```sh
./scripts/check-requisites.sh     # verify tooling, install anything missing
mise install                      # tools pinned in mise.toml
kind create cluster --config clusters/k8s-sandbox.yaml
kubectl get nodes                 # expect 3, all Ready
```

`clusters/k8s-sandbox.yaml` does not exist yet — writing it is stage 3, and
`manifests/` fills up from stage 4. Until then only the first two lines run.

Tools come from `mise`, pinned per project. If a bare `kind` is not found, mise
is not activated in your shell — see [notes/MISE.md](notes/MISE.md).

---

## cluster shape

**1 control-plane + 2 workers.** Three containers, but only *two* places a pod
can actually land:

```sh
$ kubectl get nodes -o custom-columns='NODE:.metadata.name,TAINTS:.spec.taints[*].key'
NODE                    TAINTS
k8s-sandbox-control-plane   node-role.kubernetes.io/control-plane   # NoSchedule
k8s-sandbox-worker          <none>
k8s-sandbox-worker2         <none>
```

The control-plane carries a `NoSchedule` taint, so ordinary workloads are kept
off it and only the workers take pods.

**Why two workers and not one** — with a single worker every pod lands in the
same place, so scheduling is invisible and a whole category of behaviour cannot
be practised at all:

| needs 2+ workers | what you would see |
|---|---|
| default spread | replicas landing on different nodes |
| `cordon` / `drain` | pods evicted and rescheduled somewhere else |
| pod anti-affinity | "not two of these on the same node" actually doing something |
| DaemonSet | one pod per node, appearing twice |
| node failure | `docker stop` a worker, watch the workload move |

**Why not three control-planes** — that is HA, and a separate lesson. etcd needs
an odd number for quorum, so real HA is 3 or 5, and it triples the memory cost
without teaching anything about workloads. Worth doing once, later, deliberately.

**Takeaway:** three nodes is the smallest cluster where scheduling is a real
decision rather than a foregone conclusion. filmory uses the same shape for the
same reason — *"so scheduling, affinity, and node failure behave like a real
cluster rather than a single-node toy."*

---

## roadmap

The full checklist with "done when" criteria lives in [TODO.md](TODO.md). At a
glance:

| # | stage | you can explain |
|---|---|---|
| 1 | tooling | why a shim fails when the binary is installed |
| 2 | default cluster | why a "node" appears in `docker ps` |
| 3 | cluster config | why port mappings are per-node and fixed at create time |
| 4 | Pod | why deleting one is not recovered from |
| 5 | Deployment | what a ReplicaSet adds, Running vs Ready |
| 6 | Service | why endpoints go empty, `port` vs `targetPort` |
| 7 | Ingress | the difference between refused, reset, 404 and 503 |
| 8 | your own image | why a local build gives `ErrImagePull` |

Stage 8 is the finish line. Everything below belongs to filmory — listed only
so the handover is obvious, not as sandbox work:

| what | filmory phase |
|---|---|
| Helm | Phase 4b — next up there |
| Kustomize overlays | dev / staging / prod |
| ArgoCD | Phase 5 — GitOps |
| CI | Phase 6 |
| cert-manager, Prometheus, Loki | Phase 7+ |

Come back here only when something in that list needs a throwaway cluster to
fail on first — a chart that will not template, a controller that will not
schedule. That is the sandbox earning its keep, not a new curriculum.

---

## relation to filmory

This sandbox exists to de-risk [filmory](../filmory) — same stack, no
consequences. The split is one of *scope*, not of subject: kubernetes primitives
are learned here, the real deployment happens there.

Once stage 8 is done, work moves to filmory and follows the phase order in
[filmory/INFRA.md](../filmory/INFRA.md), which deliberately works as a walking
skeleton rather than down the README's tech table. Come back here only when
something over there needs a throwaway cluster to fail on first.

One divergence to decide when you get there: stage 7 teaches the
`networking.k8s.io/v1` Ingress, but filmory's stack table specifies **Gateway
API**. Learn Ingress first — simpler, and far more written about — then port it
as its own exercise before committing to it there.

---

## notes

- [notes/KIND.md](notes/KIND.md) — kind concepts, kind vs minikube
- [notes/MISE.md](notes/MISE.md) — tool versions, command cheatsheet
