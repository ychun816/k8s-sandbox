# yaml.md


## index 



---

## notes on syntaxes


```
node 0: role=control-plane  keys=["role", "extraPortMappings", "kubeadmConfigPatches"]
node 1: role=worker         keys=["role"]
node 2: role=worker         keys=["role"]
```

### `extraPortMappings`
- `extraPortMappings` has nothing to do with the control-plane role. 
- It's there because you plan to run an ingress controller, and that ingress controller happens to be scheduled onto the control-plane node. The full chain is three hops:
```
localhost:8080  →  node container :80  →  ingress-nginx pod's hostPort 80
   (extraPortMappings)                       (set by the ingress manifest)
```
### `containerPort` `80` `8080` `443` `8443`

These are TCP port numbers:

- `80`: standard HTTP port inside the Kind node
- `8080`: port on the Mac exposed by Kind for HTTP access
- `443`: standard HTTPS port inside the Kind node
- `8443`: port on the Mac exposed by Kind for HTTPS access

The mappings are:

```text
localhost:8080  ->  Kind node:80
localhost:8443  ->  Kind node:443
```

Port `8080` is used instead of host port `80`, and `8443` instead of host port
`443`, to avoid privileged-port requirements and conflicts with other services
on the Mac. The mappings only create the path; the Ingress controller must
listen on ports `80` and `443` inside the node before requests can succeed.

---

## yaml ? / manifest? 
- `YAML`: the file format
- `Manifest`: the file’s purpose, describing a Kubernetes resource

### `resources`

The `resources` field describes how much CPU and memory a container is
expected to use. It has two main parts: `requests` and `limits`.

```yaml
resources:
   requests:
      cpu: "100m"
      memory: "128Mi"
   limits:
      memory: "256Mi"
```

### `requests`

A request is the amount of CPU or memory Kubernetes reserves for scheduling.
The scheduler compares the request with the resources already requested on each
node. If a node cannot satisfy the request, the Pod stays `Pending`.

- `100m` CPU : means `0.1` CPU core.
- `128Mi` : means 128 mebibytes of memory.
- A request should represent normal or expected usage.

Requests are not a live usage measurement and are not a guarantee that the
container will always consume exactly that amount.

### `limits`

- the max resource the container may use while running. 
- a memory limit is enforced at runtime: if the container exceeds it, Kubernetes may terminate it with an out-of-memory kill. 
- The scheduler does not reserve node capacity from a limit; it uses requests for that decision.

```text
request: reserve capacity for scheduling
limit:   cap usage during runtime
```

- The limit should normally be *greater* than the request so the container can handle short bursts. 
- A request that is too small -> can cause a node to be overpacked, while a limit that is too small can cause restarts. 
- These values are not arbitrary in production- > measure the application and adjust them.

#### `selectors` 
By using selectors, Kubernetes can manage the lifecycle of specific pod groups, ensuring that the right pods are created, updated, or deleted as per the deployment’s specifications.

### `templates`
includes nested fields such as metadata, spec, and others that outline the configuration for each pod, including the container images to use, resource requests and limits, and environment variables. Essentially, the template provides a reusable pod definition that ensures consistency when scaling up the deployment.

### `readinessProbe`

A `readinessProbe` tells Kubernetes whether a running container is ready to
receive traffic. It is different from whether the container process is alive:

```yaml
readinessProbe:
   httpGet:
      path: /
      port: 80
   initialDelaySeconds: 5
   periodSeconds: 5
```

- `httpGet`: make an HTTP request to test the container.
- `path: /`: request the root URL served by Nginx.
- `port: 80`: send the request to the container's HTTP port.
- `initialDelaySeconds: 5`: wait five seconds before the first check.
- `periodSeconds: 5`: repeat the check every five seconds.

If the check succeeds, the Pod is `Ready` and a Service may send it traffic.
If it fails, the container can remain `Running` but the Pod becomes not Ready,
so Services remove it from their ready endpoints. A failed readiness probe does
not restart the container; a liveness probe is used for restart decisions.

-- 

## resources / manual 

- [7 Kubernetes deployment strategies: Pros, cons, and how to choose](https://octopus.com/devops/kubernetes-deployments/kubernetes-deployment-strategies/)
- [Services in Kubernetes](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)