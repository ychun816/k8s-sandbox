# Protocols

## Index

- [TCP](#tcp)
- [UDP](#udp)
- [HTTP](#http)
- [HTTPS and TLS](#https-and-tls)
- [DNS](#dns)
- [Kubernetes connections](#kubernetes-connections)
- [resources](#resources)

---


## TCP

TCP is a connection-oriented transport protocol. It provides ordered and
reliable delivery of bytes between two endpoints.

Common Kubernetes examples:

- HTTP and HTTPS use TCP.
- Kind's port mappings use TCP in this project.
- The Kubernetes API server uses TCP, normally on port `6443` inside a node.

## UDP

UDP is a connectionless transport protocol. It has lower overhead than TCP but
does not guarantee delivery or ordering.

Kubernetes DNS commonly uses UDP port `53`, although DNS can also use TCP when
responses are large or reliability is needed.

## HTTP

HTTP is an application protocol for request and response messages. Standard
HTTP uses TCP port `80`.

In this project, a readiness probe makes an HTTP request to `/` on the Nginx
container's port `80`:

```text
readiness probe -> Pod:80 -> Nginx
```

## HTTPS and TLS

HTTPS is HTTP carried over TLS. TLS encrypts the connection and authenticates
the server with a certificate. Standard HTTPS uses TCP port `443`.

The Kind mappings in this project are:

```text
Mac:8443 -> Kind node:443
```

The mapping only forwards traffic. An Ingress controller and TLS certificate
configuration are still required to serve HTTPS successfully.

## DNS

DNS translates names into IP addresses. Kubernetes provides internal DNS so a
Service can be reached by name instead of by its changing ClusterIP.

For a Service named `nginx` in the `default` namespace, the full DNS name is:

```text
nginx.default.svc.cluster.local
```

Pods in the same namespace can use the short name `nginx`.

## Kubernetes connections

The protocol layers in the application path are:

```text
HTTP request
	-> TCP connection
	-> Kind host-port mapping
	-> Ingress controller
	-> Service routing
	-> Pod
```

The protocol is different from the Kubernetes resource. A Service or Ingress
describes routing behavior; TCP, HTTP, HTTPS, and DNS describe communication.

---

## resources

