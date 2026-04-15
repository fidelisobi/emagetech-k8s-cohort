# 🗂️ DNS — The Internet's Phone Book

## The problem DNS solves

You can't memorize `142.250.80.46`. But you can remember `google.com`.

**DNS (Domain Name System)** translates human-friendly names into IP addresses that computers can use.

```
google.com → 142.250.80.46
```

---

## How a DNS Lookup Works (Step by Step)

You type `github.com` into your browser:

```
1. Browser checks its own cache
   → "Do I already know github.com's IP? No."

2. Ask your computer's local cache
   → "Do you know it? No."

3. Ask your DNS resolver (usually your router or ISP's server)
   → "Do you know it? No — I'll find out."

4. Resolver asks a Root DNS Server
   → "Who handles .com domains?"
   → "Ask the .com name server"

5. Resolver asks the .com name server
   → "Who handles github.com?"
   → "Ask GitHub's own name server"

6. Resolver asks GitHub's name server
   → "What's the IP for github.com?"
   → "140.82.114.4"

7. Resolver returns 140.82.114.4 to your browser
8. Browser connects to GitHub. Page loads!
```

This whole process takes **milliseconds**.

---

## DNS Record Types

| Record | Purpose | Example |
|--------|---------|---------|
| **A** | Name → IPv4 address | `github.com → 140.82.114.4` |
| **AAAA** | Name → IPv6 address | `github.com → 2606:50c0:...` |
| **CNAME** | Alias (nickname) for another name | `www.github.com → github.com` |
| **MX** | Where to deliver email for a domain | Used by Gmail, etc. |
| **TXT** | Text info (domain verification, spam protection) | Google uses this to prove ownership |

---

## The /etc/hosts File

Before DNS existed, computers had a local file mapping all names to IPs.
That file still exists today and is checked **before** DNS.

```bash
cat /etc/hosts
```

You'll see:
```
127.0.0.1   localhost
::1         localhost
```

`127.0.0.1` = **loopback** — always points to your own computer.
`localhost` is just a friendly name for it.

You can add custom entries:
```
192.168.1.100   my-dev-server
```
Now `my-dev-server` resolves locally, no DNS needed.

---

## 🧪 Try It Yourself

```bash
# Look up an IP address for a domain
nslookup google.com

# More detailed DNS info
dig google.com

# Check what DNS server your system uses
cat /etc/resolv.conf   # Linux/Mac

# Look up a specific record type
dig github.com MX   # Mail records
dig github.com A    # IPv4 records
```

---

## Why This Matters for Kubernetes

Kubernetes has its own **internal DNS**! Every Service automatically gets a DNS name:
```
my-service.default.svc.cluster.local
```
Pods use these names instead of IP addresses — because Pod IPs change when pods restart.
Understanding DNS = understanding how services find each other in Kubernetes.

---

## ✅ What You Learned

- DNS translates names → IP addresses
- Multiple servers work together to resolve a name (root → TLD → authoritative)
- `/etc/hosts` is checked before DNS
- Kubernetes uses DNS for internal service discovery

**Next up:** [How the full internet works →](05-how-the-internet-works.md)
