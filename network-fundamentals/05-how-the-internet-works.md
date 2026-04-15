# 🌍 How the Internet Works — The Full Journey

## Putting it all together

You've learned about IP addresses, ports, protocols, and DNS.
Now let's watch them all work together in a single web request.

**Scenario:** You type `https://github.com` into your browser and press Enter.

---

## The Full Journey 🚀

### Step 1: DNS Lookup
```
Browser: "What's the IP for github.com?"
DNS:     "It's 140.82.114.4"
```

### Step 2: TCP Handshake
Your browser and GitHub's server agree to connect:
```
Browser → GitHub: "SYN"     (hey, want to connect?)
GitHub → Browser: "SYN-ACK" (yes, ready!)
Browser → GitHub: "ACK"     (great, let's go!)
```
This 3-step dance is called the **TCP Three-Way Handshake**.

### Step 3: TLS Handshake (because HTTPS)
They set up encryption:
```
Browser: "Here are the encryption methods I support"
GitHub:  "I'll use AES-256. Here's my certificate proving I'm really GitHub"
Browser: "Certificate checks out! Let's generate a shared secret key"
[Both sides now have the same key — all traffic is encrypted from here]
```

### Step 4: HTTP Request
Your browser asks for the page:
```
GET / HTTP/2
Host: github.com
User-Agent: Chrome/120
Accept: text/html
```

### Step 5: HTTP Response
GitHub sends back the page:
```
HTTP/2 200 OK
Content-Type: text/html

<!DOCTYPE html>
<html>... GitHub homepage ...</html>
```

### Step 6: Browser Renders the Page
HTML is parsed, CSS styles it, JavaScript runs. You see GitHub. ✅

**Total time:** ~200–500ms for a website on the other side of the world. Amazing.

---

## How Packets Hop Across the Internet

Your data doesn't go directly from your laptop to GitHub.
It bounces through many routers along the way — across cities, even continents.

```bash
# Watch your packets travel the internet (Mac/Linux)
traceroute github.com

# Windows
tracert github.com
```

Each line is a router your packet passed through. You can see the whole route!

---

## Firewalls — The Security Guards

A **firewall** inspects traffic and decides what's allowed in or out.

Example rules:
```
ALLOW  TCP port 443 from anywhere       (HTTPS is fine)
ALLOW  TCP port 22 from 10.0.0.0/8     (SSH only from internal network)
DENY   everything else
```

In Kubernetes: **NetworkPolicies** act like firewalls between pods.

---

## Load Balancers — Sharing the Work

A popular site can't run on just one server.
A **load balancer** sits in front of many servers and spreads traffic across them:

```
Client → Load Balancer → Server 1
                       → Server 2
                       → Server 3
```

If one server goes down, the load balancer routes to the others.

In Kubernetes: **Services** do this automatically between your pods.

---

## 🧪 Try It Yourself

```bash
# Trace the path your packets take
traceroute google.com

# Time how long a full request takes
curl -w "\nTime: %{time_total}s\n" -o /dev/null -s https://github.com

# See all active network connections on your machine
netstat -an | grep ESTABLISHED
```

---

## 🎉 Congratulations! You've Completed Network Fundamentals!

You now understand:
- ✅ What a network is and how packets travel
- ✅ How IP addresses and subnets work
- ✅ What ports are and how TCP/UDP differ
- ✅ How DNS resolves names to addresses
- ✅ The full journey of a web request

**This is the foundation for everything in Kubernetes networking.**
When a Pod can't reach a Service, you now have the mental model to debug it.

Ready for the next step? → Check out [Git Fundamentals](../git-fundamentals/README.md)
