# 📡 What Is a Network?

## Think of it like a city

Imagine a city. There are buildings (computers), roads (cables/Wi-Fi), and addresses (IP addresses).
A **network** is just a group of computers that can talk to each other — like neighbors on the same street.

When you have just two computers connected together, that's a network.
When you connect millions of them together, that's the **internet**.

---

## The Two Types of Networks You'll Hear About

### Local Area Network (LAN) 🏠
This is your home or office network. Your phone, laptop, smart TV — they're all on the same LAN.
They can talk to each other very fast because they're physically close.

**Example:** You stream a movie from your laptop to your TV — that stays on your LAN.

### Wide Area Network (WAN) 🌍
This is what connects your home network to the rest of the world — the internet.
When you visit a website, your request travels across WANs.

---

## How Do Computers Actually Talk?

They break information into tiny chunks called **packets**.

Think of it like mailing a book by tearing out each page and mailing them separately.
Each page (packet) has:
- Where it came from
- Where it's going
- Its page number (so the book can be reassembled)

The receiving computer puts the pages back in order and reads the book.

---

## Key Devices on a Network

| Device | What It Does | Real-World Analogy |
|--------|-------------|-------------------|
| **Router** | Directs traffic between networks | Traffic cop at an intersection |
| **Switch** | Connects devices within one network | Post office for a building |
| **Modem** | Connects your network to the internet | Your front door to the city |

---

## 🧪 Try It Yourself

```bash
# See all devices on your local network (Mac/Linux)
arp -a

# See your own IP address
ifconfig | grep "inet "   # Mac/Linux
ipconfig                  # Windows
```

You'll see a list of IP addresses — each one is a device on your network!

---

## ✅ What You Learned

- A network = computers that can talk to each other
- LAN = local (home/office), WAN = wide area (the internet)
- Data travels in small packets
- Routers, switches, and modems each play a different role

**Next up:** [How computers get addresses →](02-ip-addresses.md)
