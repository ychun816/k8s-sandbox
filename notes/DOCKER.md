# Docker


## notes on syntaxes 

### latest v.s. v1 

The image tag silently decides Kubernetes' `imagePullPolicy`, and that decides
whether a `kind load`ed image is used at all.

| tag                          | default `imagePullPolicy` | works with `kind load`?        |
|------------------------------|---------------------------|--------------------------------|
| `:v1`, `:1.2.3`, any real tag | `IfNotPresent`            | yes — uses the local copy      |
| `:latest`, or no tag at all  | `Always`                  | **no** — ignores it, hits the registry |

- `IfNotPresent`: use the copy already on the node; only pull if missing.
- `Always`: go to the registry every time, whatever is on the node.
- `Never`: never pull. Fails loudly if the image is not on the node — often the
  desired behaviour locally, because there is no silent fallback to a registry
  that might serve something different.

### the experiment

Same image, both loaded onto the node with `kind load`. Only the tag differs:

```bash
docker exec k8s-sandbox-worker crictl images | grep -E "myapp|nginx"
# docker.io/library/myapp   latest   29MB     <- present, and still fails
# docker.io/library/nginx   v1       29MB     <- present, and works
```

```bash
kubectl run nginx --image=nginx:v1
kubectl get pod nginx -o jsonpath='{.spec.containers[0].imagePullPolicy}'
# IfNotPresent  ->  1/1 Running, serves 'nginx v1 — chun'

kubectl run latest-test --image=myapp:latest
kubectl get pod latest-test -o jsonpath='{.spec.containers[0].imagePullPolicy}'
# Always        ->  0/1 ErrImagePull
```

The failure message points at the registry, not at the policy:

```text
Failed to pull image "myapp:latest": failed to resolve reference
"docker.io/library/myapp:latest": pull access denied, repository does not
exist or may require authorization
```

That is the trap. The image was in the node's containerd the whole time. The
kubelet never looked, because `Always` means *always go to the registry*, and
there is no `myapp` repository on Docker Hub. "repository does not exist" leads
to investigating the registry when the actual cause is the tag.

### the fix

1. Tag with a real version — `v1`, not `latest`. Cleanest, and the default
   policy then does the right thing on its own.
2. Or force it explicitly, needed when a manifest must use `:latest`:

```yaml
imagePullPolicy: IfNotPresent   # or Never, to forbid registry pulls entirely
```

### why this is not only a kind problem

Anywhere an image reaches a node out-of-band — `kind load`, a preloaded AMI, a
local registry mirror — a `:latest` tag quietly overrides it and goes to the
registry instead. Same symptom, same misleading error. Worth recognising on
sight.
