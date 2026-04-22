# Lab 06: Docker Networking

## Overview

You'll create user-defined bridge networks, watch DNS-by-name work, isolate stacks, attach
a container to multiple networks, and use `netshoot` to debug a minimal/distroless container.

**Estimated time:** 45 minutes

**Prerequisites:**

- Docker installed and working
- `jq`

---

## Part 1: The Default Networks

```bash
docker network ls
```

You should see:

```
NAME       DRIVER    SCOPE
bridge     bridge    local      ← legacy default; avoid for app networking
host       host      local
none       null      local
```

```bash
docker network inspect bridge | jq '.[0] | {Name, Subnet: .IPAM.Config[0].Subnet, Containers}'
```

---

## Part 2: User-Defined Bridge — DNS for Free

### 2.1 Create a network and put two containers on it

```bash
docker network create app-net

docker container run -d --name api --network app-net nginx:1.25
docker container run -d --name client --network app-net alpine sleep 1d
```

### 2.2 Resolve by container name

```bash
docker container exec client sh -c 'apk add --quiet bind-tools curl 2>/dev/null; getent hosts api'
docker container exec client wget -qO- http://api/ | head
```

DNS by container name works automatically on a user-defined bridge.

### 2.3 Same test on the legacy default

```bash
docker container run -d --name legacy-api --network bridge nginx:1.25
docker container run -d --name legacy-client --network bridge alpine sleep 1d

# This will fail — no DNS by name on the default bridge
docker container exec legacy-client sh -c 'apk add --quiet bind-tools 2>/dev/null; getent hosts legacy-api' || echo "no DNS"
```

### 2.4 Clean up legacy

```bash
docker container rm -f legacy-api legacy-client
```

---

## Part 3: Network Aliases

```bash
docker network create svc-net

docker container run -d --name primary-db \
  --network svc-net \
  --network-alias db \
  --network-alias primary \
  postgres:16 \
  -c 'POSTGRES_PASSWORD=secret' || true

# Both names resolve to the same container
docker container run --rm --network svc-net alpine sh -c \
  'apk add --quiet bind-tools 2>/dev/null; getent hosts db; getent hosts primary'
```

Aliases are how Compose lets you reference services with custom names.

```bash
docker container rm -f primary-db
docker network rm svc-net
```

---

## Part 4: Isolation Between Networks

By default, two containers on **different** user-defined bridges cannot talk.

```bash
docker network create net-a
docker network create net-b

docker container run -d --name in-a --network net-a alpine sleep 1d
docker container run -d --name in-b --network net-b alpine sleep 1d

# From in-a, try to reach in-b
docker container exec in-a sh -c 'apk add --quiet bind-tools 2>/dev/null; getent hosts in-b' || echo "no DNS"

IP_B=$(docker container inspect -f '{{(index .NetworkSettings.Networks "net-b").IPAddress}}' in-b)
docker container exec in-a ping -c 2 -W 2 $IP_B || echo "no route either"
```

> **Question:** What kernel mechanism enforces this isolation? (Hint: look at
> `iptables -L DOCKER-ISOLATION-STAGE-1 -n` on a Linux host.)

---

## Part 5: Multi-Network Containers

Connect a container to a second network at runtime.

```bash
docker network connect net-a in-b
docker container exec in-b ip addr | grep -E 'inet|eth'
```

`in-b` now has interfaces on both `net-a` and `net-b`. From `in-a` it's reachable by name.

```bash
docker container exec in-a sh -c 'apk add --quiet bind-tools 2>/dev/null; getent hosts in-b'
docker container exec in-a wget -qO- http://in-b 2>/dev/null || echo "no http server"
```

Disconnect:

```bash
docker network disconnect net-a in-b
```

Clean up:

```bash
docker container rm -f in-a in-b
docker network rm net-a net-b
```

---

## Part 6: Port Publishing — How It Actually Works

### 6.1 Publish a port

```bash
docker container run -d --name web -p 8080:80 nginx:1.25
docker container port web
curl -I http://localhost:8080
```

### 6.2 Look at the iptables rule (Linux)

```bash
sudo iptables -t nat -L DOCKER -n | head
# DNAT rule: tcp dpt:8080 -> 172.17.0.2:80   (or similar)
```

### 6.3 Bind to localhost only

```bash
docker container rm -f web
docker container run -d --name web -p 127.0.0.1:8080:80 nginx:1.25
curl -I http://localhost:8080                            # works
LAN=$(hostname -I 2>/dev/null | awk '{print $1}')
[ -n "$LAN" ] && curl --max-time 2 -I http://$LAN:8080 || echo "blocked from LAN — good"
docker container rm -f web
```

### 6.4 Random ports

```bash
docker container run -d --name r1 -P nginx:1.25
docker container run -d --name r2 -P nginx:1.25
docker container port r1
docker container port r2
docker container rm -f r1 r2
```

---

## Part 7: Host Networking (Linux only)

> Skip this section on Docker Desktop — "host" is the Desktop VM, not your laptop, so this
> doesn't behave the way you'd expect.

```bash
docker container run -d --name host-nginx --network host nginx:1.25
ss -tlnp | grep :80                       # nginx is bound directly to host:80
curl -I http://localhost
docker container rm -f host-nginx
```

> **Question:** When would you choose `--network host` despite the loss of isolation?

---

## Part 8: None Networking

```bash
docker container run --rm --network none alpine ip addr
# Only loopback — no eth0
```

Useful for: CPU-only batch jobs, sandboxed builds, security demos.

---

## Part 9: Custom Subnets, Gateways, IP Ranges

```bash
docker network create \
  --driver bridge \
  --subnet 10.50.0.0/24 \
  --gateway 10.50.0.1 \
  --ip-range 10.50.0.128/25 \
  custom-net

docker container run -d --name pinned --network custom-net --ip 10.50.0.50 alpine sleep 1d
docker container inspect -f '{{(index .NetworkSettings.Networks "custom-net").IPAddress}}' pinned

docker container rm -f pinned
docker network rm custom-net
```

Static IPs in containerland are usually a smell — but the option exists.

---

## Part 10: Debugging With netshoot

`nicolaka/netshoot` is a debugging container with `dig`, `nslookup`, `tcpdump`, `mtr`,
`curl`, `nc`, and many more tools — useful when your app's image has none of them.

### 10.1 Share another container's network namespace

```bash
docker network create svc-net
docker container run -d --name api --network svc-net nginx:1.25
docker container run -d --name minimal --network svc-net gcr.io/distroless/static:nonroot

# minimal has no shell. Attach netshoot to its netns.
docker container run --rm -it --network container:minimal nicolaka/netshoot
# inside netshoot:
> getent hosts api
> curl -I http://api
> tcpdump -i eth0 -c 5 -n
> exit
```

You debugged a distroless container without modifying it.

### 10.2 Clean up

```bash
docker container rm -f api minimal
docker network rm svc-net
```

---

## Part 11: Reach the Host From a Container

### 11.1 Docker Desktop (mac/Windows)

```bash
docker container run --rm alpine sh -c \
  'apk add --quiet bind-tools curl 2>/dev/null; getent hosts host.docker.internal; curl -s http://host.docker.internal:8080 || true'
```

### 11.2 Linux

```bash
docker container run --rm \
  --add-host=host.docker.internal:host-gateway \
  alpine sh -c 'apk add --quiet bind-tools 2>/dev/null; getent hosts host.docker.internal'
```

The `host-gateway` magic value resolves to the host's docker0 IP (typically `172.17.0.1`).

---

## Clean Up

```bash
docker container rm -f $(docker container ls -aq) 2>/dev/null
docker network prune -f
```

---

## Summary

After completing this lab you should be able to:

- Distinguish the **default bridge**, **user-defined bridges**, **host**, and **none** drivers
- Use **container-name DNS** on user-defined bridges
- Add **network aliases** for stable references regardless of container name
- Demonstrate that two user-defined bridges are isolated by iptables
- Attach a container to **multiple networks** for sidecar / gateway patterns
- Publish ports with `-p`, including localhost-only and random-port forms
- Debug minimal/distroless containers with `netshoot` in a shared netns
- Reach the host from a container on Linux and Docker Desktop

---

## Stretch Goals

1. Use `tcpdump` (in netshoot) to capture an HTTP request between two containers on a
   user-defined bridge. What's the source IP, what's the destination, and what bridge sits
   between them?
2. Build a "DMZ" pattern in pure Docker: an `edge` network with the reverse proxy, an
   `internal` network with the app and DB, and the proxy on both. The DB must be unreachable
   from the edge.
3. Read about and try **macvlan** on a Linux host: give a container its own MAC and IP on
   your LAN. What new things can you do? What new risks?
