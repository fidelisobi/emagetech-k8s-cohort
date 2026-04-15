# 🏠 IP Addresses — How Computers Get Their "Address"

## Every device needs an address

Imagine trying to mail a letter without an address. It would never arrive.
Computers have the same problem — without addresses, packets have nowhere to go.

An **IP address** is that address.

---

## What Does an IP Address Look Like?

**IPv4 (the most common):**
```
192.168.1.100
```
Four numbers separated by dots. Each number is 0–255.

**IPv6 (newer, much bigger):**
```
2001:0db8:85a3:0000:0000:8a2e:0370:7334
```
IPv6 exists because we ran out of IPv4 addresses (too many devices in the world!).

For now, focus on IPv4 — it's what you'll see most often.

---

## Public vs. Private IP Addresses

### Private IPs 🔒 (inside your home/office)
These are used inside a network. They are NOT reachable from the internet.

Reserved private ranges:
- `10.0.0.0 – 10.255.255.255`
- `172.16.0.0 – 172.31.255.255`
- `192.168.0.0 – 192.168.255.255`

Your home Wi-Fi router gives out addresses like `192.168.1.x` to your devices.

### Public IPs 🌍 (visible on the internet)
Your internet provider (ISP) gives your home ONE public IP.
Your router uses a trick called **NAT** to let all your devices share it.

---

## What Is a Subnet?

A **subnet** is a smaller chunk of a network.

The `/24` in `192.168.1.0/24` describes the size:
- `/24` = up to 254 devices (very common for home networks)
- `/16` = up to 65,534 devices
- `/8`  = up to 16 million devices

**Analogy:** Think of IP addresses like mailing addresses.
- `/8`  = "United States" (massive, many addresses)
- `/24` = "Your street" (small, local)

---

## How Does a Computer Get Its IP?

### 1. DHCP (automatic) ✅
A DHCP server (usually your router) automatically assigns an IP when a device connects.
This is how your phone gets an IP when joining Wi-Fi — you don't do anything.

### 2. Static (manual) ⚙️
You assign the IP yourself. Used for servers that need a consistent, predictable address.

---

## 🧪 Try It Yourself

```bash
# See your IP address (Mac/Linux)
ip addr show
# or
ifconfig

# Windows
ipconfig /all

# Check your public IP
curl https://ifconfig.me
```

---

## ✅ What You Learned

- IP addresses are how computers find each other
- Private IPs stay inside your network; public IPs are internet-facing
- `/24` notation describes network size (subnets)
- DHCP assigns IPs automatically; static IPs are set manually

**Next up:** [Ports and Protocols →](03-ports-and-protocols.md)
