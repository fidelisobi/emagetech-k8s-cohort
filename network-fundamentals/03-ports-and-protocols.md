# 🚪 Ports and Protocols — How Services Talk to Each Other

## A building with many doors

An IP address gets you to the right building (computer).
But a computer runs *many* services at once — web server, email, database, etc.

**Ports** are the individual doors into that building.

```
192.168.1.50:80   ← web server
192.168.1.50:22   ← SSH (remote login)
192.168.1.50:5432 ← PostgreSQL database
```

Same computer, three different services, three different doors (ports).

---

## Common Port Numbers to Know

| Port | Service | What It Does |
|------|---------|--------------|
| 22 | SSH | Secure remote login to a server |
| 80 | HTTP | Websites (unencrypted) |
| 443 | HTTPS | Websites (encrypted) |
| 3306 | MySQL | MySQL database |
| 5432 | PostgreSQL | Postgres database |
| 6443 | Kubernetes API | Kubernetes control plane |
| 8080 | HTTP alt | Common for dev/test servers |

Ports 0–1023 are reserved for well-known standard services.
Ports 1024–65535 are free for your own apps.

---

## TCP vs. UDP — The Two Main Protocols

A **protocol** is a set of agreed-upon rules for communication.

### TCP (Transmission Control Protocol) 📬
- **Reliable:** Every packet is guaranteed to arrive
- **Ordered:** Packets come back in the right order
- **Slightly slower:** Because of those guarantees
- **Use cases:** Web browsing, email, file transfers

TCP is like certified mail — you get a confirmation it arrived.

### UDP (User Datagram Protocol) 📮
- **Fast:** No overhead, just fire and forget
- **No guarantees:** Packets might not arrive
- **Use cases:** Video streaming, gaming, DNS lookups

UDP is like dropping a postcard in a mailbox.
Streaming video uses UDP because a dropped frame is better than freezing to wait.

---

## HTTP in Plain English

HTTP (HyperText Transfer Protocol) is the language browsers and servers use.

A typical conversation:

```
Browser sends (Request):
  GET /index.html HTTP/1.1
  Host: www.example.com

Server responds:
  HTTP/1.1 200 OK
  Content-Type: text/html

  <html>Hello World</html>
```

HTTP Status Codes you'll see often:
| Code | Meaning |
|------|---------|
| 200 | OK — everything worked |
| 301 | Moved permanently (redirect) |
| 404 | Not found |
| 500 | Server error |

HTTPS = HTTP + encryption (the 🔒 padlock in your browser).

---

## 🧪 Try It Yourself

```bash
# See what ports are open on your machine
netstat -tuln
# or (Mac)
lsof -i -P | grep LISTEN

# Make an HTTP request from the command line
curl -v http://example.com

# Check if a port is open on a remote host
nc -zv google.com 443
```

---

## ✅ What You Learned

- Ports are like doors — each service gets its own
- TCP is reliable and ordered; UDP is fast but unguaranteed
- HTTP is the language of the web; HTTPS adds encryption
- Common ports: 22 (SSH), 80 (HTTP), 443 (HTTPS), 6443 (Kubernetes)

**Next up:** [How DNS works →](04-dns.md)
