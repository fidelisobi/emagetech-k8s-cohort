# Session 6 — Docker Networking

---

## Why Container Networking Is Interesting

A container is just a process — but it has its **own network stack** (its own interfaces,
routing table, iptables rules, ports). Docker wires this stack up so containers can:

- Reach each other by name
- Reach the outside world
- Be reached from the host (if you publish a port)
- Be isolated from containers that shouldn't see them

Docker implements this through the **Container Network Model (CNM)**.

---

## The Container Network Model (CNM)

Three abstractions:

| Term | What it is |
|---|---|
| **Sandbox** | The container's network stack (interfaces, routes, DNS) — backed by a Linux **network namespace** |
| **Endpoint** | A virtual interface that connects a sandbox to a network — typically one end of a `veth` pair |
| **Network** | A group of endpoints that can talk to each other |

```
   Container A                Container B
   ┌──────────┐              ┌──────────┐
   │ Sandbox  │              │ Sandbox  │
   │ (netns)  │              │ (netns)  │
   │   eth0───┼──┐        ┌──┤eth0      │
   └──────────┘  │        │  └──────────┘
                 │        │
                 ▼        ▼
              ┌─────────────┐
              │   Network   │   (e.g., bridge, overlay)
              └─────────────┘
```

Libnetwork is Docker's CNM implementation. It also provides:

- **Native service discovery** — DNS names inside a user-defined network
- **Built-in load balancing** — for Swarm services

> Kubernetes uses a different abstraction (**CNI**, the Container Network Interface) instead
> of CNM. The Linux primitives underneath — netns, veth, bridge, iptables — are the same.

---

## The Built-In Network Drivers

Run `docker network ls` and you'll always see three default networks:

```
NETWORK ID     NAME      DRIVER    SCOPE
b1c2…          bridge    bridge    local
d3e4…          host      host      local
f5a6…          none      null      local
```

| Driver | Use case |
|---|---|
| **bridge** | Single-host; default. Each container gets a virtual ethernet into a Linux bridge (`docker0`). |
| **host** | Container shares the host's network namespace. No isolation; fastest. |
| **none** | No networking. Useful for batch jobs that don't need the network. |
| **overlay** | Multi-host; for Docker Swarm. Uses VXLAN. |
| **macvlan** | Containers get real MAC addresses on the physical LAN. |
| **ipvlan** | Similar to macvlan; shares the host's MAC. |

---

## The Default Bridge Network

The legacy default. Every container that doesn't specify a network lands here.

- Bridge interface on the host: `docker0`
- Default subnet: `172.17.0.0/16`
- Containers can reach each other by **IP**, but **not by name** — no built-in DNS
- The host can reach containers by IP

```bash
docker container run -d --name web nginx
docker network inspect bridge | jq '.[].Containers'
```

**Don't use the default bridge for application networking.** It exists for backward
compatibility. Use a **user-defined bridge** instead.

---

## User-Defined Bridges (the Right Default)

Create your own bridge network per application or stack.

```bash
docker network create app-net

docker container run -d --name api    --network app-net myapi:1.0
docker container run -d --name web    --network app-net nginx
docker container run -d --name cache  --network app-net redis:7
```

Benefits over the default bridge:

- **Automatic DNS** — `api` can reach `cache` by the container name
- **Container-level isolation** — unrelated apps on other bridges can't see this one
- **Better lifecycle** — remove the network when the app goes away

```bash
# Test DNS from inside a container
docker container exec -it api sh
> ping -c 2 cache
> getent hosts web
```

Container names, network aliases, and Compose service names all become resolvable.

---

## Port Publishing (Revisited)

`-p HOST:CONTAINER` inserts a NAT rule on the host:

```bash
docker container run -d -p 8080:80 --name web nginx
# browse http://<host-ip>:8080
```

- The rule is added to iptables' `DOCKER` chain
- Traffic arriving at `host:8080` is DNATed to `<container-ip>:80`
- The container itself does not know about port 8080

```bash
# Inspect
docker container port web
sudo iptables -t nat -L DOCKER -n
```

To bind only to localhost (safer for dev):

```bash
docker container run -d -p 127.0.0.1:8080:80 nginx
```

---

## Host Networking

```bash
docker container run -d --network host nginx
```

- No network namespace — the container shares the host's
- `nginx` listens on the host's port 80 directly
- Fastest networking; zero NAT overhead
- **No isolation** — the container can see and bind any host port; port conflicts with
  host services become real

On Docker Desktop (macOS/Windows), "host" is the hidden Linux VM — not your laptop — which
makes host networking less useful there.

---

## None Networking

```bash
docker container run --rm --network none alpine ip addr
```

- Only a loopback interface
- Useful for: CPU-bound batch jobs, sandboxing, or when you'll attach a network manually

---

## Embedded DNS Inside User-Defined Bridges

Every container on a user-defined bridge has `/etc/resolv.conf` pointing at Docker's internal
DNS server (`127.0.0.11`).

```bash
docker container exec -it api cat /etc/resolv.conf
# nameserver 127.0.0.11
```

Name resolution order inside the container:

1. Container names on the same user-defined network
2. Network aliases (`--network-alias`)
3. External DNS (forwarded to host or specified by `--dns`)

```bash
docker network create app-net
docker container run -d --name db   --network app-net --network-alias primary postgres:16
docker container run -d --name app  --network app-net myapp:1.0

# From inside 'app':
#   db         → container IP
#   primary    → same container (alias)
#   google.com → forwarded upstream
```

---

## Connecting, Disconnecting, Multiple Networks

A container can be on **multiple networks** at once — useful for sidecars or gateway patterns.

```bash
docker network create backend
docker network create frontend

docker container run -d --name api --network backend myapi:1.0
docker network connect frontend api
docker network disconnect backend api
```

Inside `api` you'll see multiple interfaces (`eth0`, `eth1`). Use this to keep a database
on `backend` but expose an `api` on `frontend` without bridging the two networks directly.

---

## Isolation and Security

- Containers on **different user-defined bridges** cannot talk by default — Docker installs
  iptables rules to drop inter-bridge traffic
- The host can always reach any container (it owns the namespace)
- By default, containers can reach **out** to anything the host can reach — egress is open.
  Lock this down with firewall rules on the host or use `--network none` + explicit attach

**For fine-grained policy (whitelisting which service can call which), you want Kubernetes
NetworkPolicies + a CNI like Cilium or Calico (Session 17).**

---

## Overlay Networks (Swarm)

For multi-host networking without Kubernetes, Docker Swarm offers overlay networks backed
by **VXLAN**:

- Containers on different hosts see the same L2 network
- Encrypted control plane; optional data-plane encryption
- Built-in service VIPs and round-robin load balancing

```bash
docker swarm init
docker network create -d overlay --attachable app-net
```

Swarm is still maintained, but most production deployments use Kubernetes. You'll rarely
build new systems on overlay + Swarm.

---

## macvlan & ipvlan

Use when you need containers to appear as first-class machines on the physical network
(legacy apps that require specific MACs/IPs, network appliances).

```bash
docker network create -d macvlan \
  --subnet=192.168.1.0/24 \
  --gateway=192.168.1.1 \
  -o parent=eth0 lanseg
```

- Each container gets its own MAC on the physical LAN
- DHCP from the LAN's DHCP server is supported
- Not supported on Docker Desktop
- Use sparingly — it bypasses most of Docker's iptables-based isolation

---

## Inspecting Networks

```bash
docker network ls
docker network inspect app-net
docker network inspect bridge | jq '.[].IPAM'

# Which network(s) is a container on?
docker container inspect web -f '{{json .NetworkSettings.Networks}}' | jq
```

From inside a container:

```bash
docker container exec -it web sh
> ip addr
> ip route
> getent hosts api
> nc -zv api 8080
```

If `nc`/`ping`/`ip` are missing (distroless, minimal images), start a debugging container
on the same network:

```bash
docker container run --rm -it --network container:web nicolaka/netshoot
```

`netshoot` shares the target's netns, giving you full tooling without adding it to the
production image.

---

## Common Networking Gotchas

- **"Why can't my two containers see each other?"** — You put them on the default bridge.
  Use a user-defined bridge.
- **"Why can't I reach `localhost:3306` from my container?"** — `localhost` inside the
  container is the container itself. To reach the host, use `host.docker.internal` (Desktop)
  or the host's LAN IP (Linux, or add `--add-host=host.docker.internal:host-gateway`).
- **"My published port doesn't work."** — Firewall on the host, wrong interface binding
  (`127.0.0.1` vs `0.0.0.0`), or another process already on that port.
- **"DNS works, then stops working."** — Container was connected to a network and later
  disconnected; `/etc/resolv.conf` might still reference `127.0.0.11`.

---

## Key Takeaways

- Docker networking is built on Linux **netns, veth pairs, bridges, and iptables NAT**
- The default bridge is for back-compat — **always use user-defined bridges**
- User-defined bridges give you **DNS by container name** for free
- `host` skips isolation for speed; `none` turns networking off
- `-p` publishes a port via NAT; the container doesn't know about the host port
- For multi-host networking, use **overlay (Swarm)** or move to **Kubernetes**
- Use `netshoot` in a shared netns to debug minimal/distroless containers

---

## Review Questions

### Beginner

1. What are the three default networks and when would you use each?
2. Why can containers on a user-defined bridge reach each other by name, but containers on
   the default bridge cannot?
3. What does `-p 8080:80` actually do on the host?
4. What's the difference between a container's `localhost` and the host's `localhost`?
5. What does `--network host` give you, and what do you give up?

### Intermediate

1. Two containers on the same user-defined network can't reach each other. Walk through
   the commands you'd run from inside one of them to diagnose the problem.
2. Your app needs to reach a database on the host machine (installed outside Docker).
   Describe the options to make that work from inside a container on each of: Docker Desktop
   for macOS, a Linux server, and a Windows host.
3. You need strict east-west network policy ("only service A can call service B"). Why is
   plain Docker a poor fit for this, and what's the standard answer at Kubernetes scale?
