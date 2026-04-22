# Lab 07: Docker Volumes

## Overview

You'll see ephemeral storage disappear, persist data with named volumes, share data between
containers, use bind mounts for a dev loop, write a tmpfs, and back up + restore a volume.

**Estimated time:** 45 minutes

**Prerequisites:**

- Docker installed and working
- A few hundred MB of free disk

---

## Part 1: The Ephemeral Filesystem Problem

### 1.1 Write data, then remove the container

```bash
docker container run --name nopersist alpine sh -c 'echo "important" > /data.txt; cat /data.txt'
docker container rm nopersist
docker container run --rm alpine cat /data.txt 2>&1 || echo "data lost"
```

The file lived in the writable layer, which was deleted with the container.

### 1.2 What about a database?

```bash
# A throwaway Postgres
docker container run -d --name pg-throwaway \
  -e POSTGRES_PASSWORD=secret -e POSTGRES_DB=demo \
  postgres:16

sleep 5
docker container exec -u postgres pg-throwaway \
  psql -d demo -c "CREATE TABLE t(id int); INSERT INTO t VALUES (1),(2),(3); SELECT count(*) FROM t;"

docker container rm -f pg-throwaway

# Start fresh — no table
docker container run -d --name pg-throwaway \
  -e POSTGRES_PASSWORD=secret -e POSTGRES_DB=demo \
  postgres:16

sleep 5
docker container exec -u postgres pg-throwaway psql -d demo -c "SELECT count(*) FROM t;" 2>&1 | head
docker container rm -f pg-throwaway
```

Three rows: gone. This is why we need volumes.

---

## Part 2: Named Volumes

### 2.1 Create one and attach it

```bash
docker volume create pg-data
docker volume ls
docker volume inspect pg-data
```

### 2.2 Run Postgres backed by the volume

```bash
docker container run -d --name pg \
  -e POSTGRES_PASSWORD=secret -e POSTGRES_DB=demo \
  --mount type=volume,source=pg-data,target=/var/lib/postgresql/data \
  postgres:16

sleep 5
docker container exec -u postgres pg \
  psql -d demo -c "CREATE TABLE t(id int); INSERT INTO t VALUES (1),(2),(3);"
```

### 2.3 Replace the container — keep the data

```bash
docker container rm -f pg

docker container run -d --name pg \
  -e POSTGRES_PASSWORD=secret -e POSTGRES_DB=demo \
  --mount type=volume,source=pg-data,target=/var/lib/postgresql/data \
  postgres:16

sleep 5
docker container exec -u postgres pg psql -d demo -c "SELECT count(*) FROM t;"
# Returns 3
```

The container is replaceable cattle; the data lives outside it.

---

## Part 3: Where Volumes Actually Live (Linux)

```bash
sudo ls /var/lib/docker/volumes/pg-data/_data | head
sudo du -sh /var/lib/docker/volumes/pg-data/_data
```

On macOS / Windows this lives inside the Docker Desktop VM and isn't directly visible from
the host filesystem.

---

## Part 4: Bind Mounts — Dev Loops

### 4.1 Hot-reload a static site

```bash
mkdir -p ~/docker-lab-07/site
echo "<h1>v1</h1>" > ~/docker-lab-07/site/index.html

docker container run -d --name web \
  -p 8080:80 \
  --mount type=bind,source=$HOME/docker-lab-07/site,target=/usr/share/nginx/html,readonly \
  nginx:1.25

curl -s http://localhost:8080
echo "<h1>v2 — hot reloaded</h1>" > ~/docker-lab-07/site/index.html
curl -s http://localhost:8080
```

The container saw the file change instantly — bind mounts are zero-copy on Linux (and use
gRPC-FUSE / VirtioFS on Docker Desktop).

### 4.2 Read-only — write attempts fail

```bash
docker container exec web sh -c 'echo "hacked" > /usr/share/nginx/html/index.html' 2>&1 || echo "write blocked"
```

### 4.3 Clean up

```bash
docker container rm -f web
```

---

## Part 5: Sharing a Volume Between Containers

### 5.1 Producer / consumer

```bash
docker volume create shared

docker container run -d --name writer \
  --mount type=volume,source=shared,target=/data \
  alpine sh -c 'while :; do date >> /data/log; sleep 2; done'

docker container run --rm \
  --mount type=volume,source=shared,target=/data,readonly \
  alpine tail -n 5 /data/log

# Wait a bit, look again
sleep 5
docker container run --rm \
  --mount type=volume,source=shared,target=/data,readonly \
  alpine tail -n 5 /data/log

docker container rm -f writer
```

### 5.2 Don't try this with two writers

If two containers both write to the same files with no locking, you own the corruption.

---

## Part 6: Anonymous Volumes (Avoid Surprises)

```bash
docker container run -d --name nameless mysql:8 -e MYSQL_ROOT_PASSWORD=secret
docker volume ls
# Note the volume with a long random hash — that's anonymous

docker container rm -f nameless
docker volume ls
# Anonymous volume is still there!
docker volume prune -f
```

Anonymous volumes pile up forever. Use named volumes or `--rm` for ephemeral data.

---

## Part 7: tmpfs — Write to RAM

```bash
docker container run -d --name memdb \
  --tmpfs /scratch:rw,size=64m \
  alpine sh -c 'echo "in RAM only" > /scratch/note; cat /scratch/note; sleep 1d'

docker container exec memdb sh -c 'mount | grep scratch; ls /scratch'
docker container restart memdb
docker container exec memdb ls /scratch         # empty — tmpfs cleared
docker container rm -f memdb
```

Use tmpfs for: decrypted secrets, session caches, anything that must not hit disk.

---

## Part 8: Backup and Restore a Volume

### 8.1 Backup

```bash
mkdir -p ~/docker-lab-07/backups
docker container run --rm \
  --mount type=volume,source=pg-data,target=/data,readonly \
  --mount type=bind,source=$HOME/docker-lab-07/backups,target=/backup \
  alpine tar -czf /backup/pg-data-$(date +%Y%m%d).tgz -C /data .

ls -lh ~/docker-lab-07/backups
```

### 8.2 Restore into a fresh volume

```bash
docker volume create pg-data-restore

LATEST=$(ls -t ~/docker-lab-07/backups/pg-data-*.tgz | head -1)
docker container run --rm \
  --mount type=volume,source=pg-data-restore,target=/data \
  --mount type=bind,source=$HOME/docker-lab-07/backups,target=/backup,readonly \
  alpine tar -xzf /backup/$(basename $LATEST) -C /data

# Verify by attaching it to a fresh Postgres
docker container rm -f pg
docker container run -d --name pg \
  -e POSTGRES_PASSWORD=secret -e POSTGRES_DB=demo \
  --mount type=volume,source=pg-data-restore,target=/var/lib/postgresql/data \
  postgres:16
sleep 5
docker container exec -u postgres pg psql -d demo -c "SELECT count(*) FROM t;"
docker container rm -f pg
```

The "attach a helper + tar through it" pattern works for any volume, any driver.

---

## Part 9: Volume Drivers — NFS Mount (Optional, Linux)

If you have an NFS server (or a quick `nfs-kernel-server` install in a VM):

```bash
docker volume create \
  --driver local \
  --opt type=nfs \
  --opt o=addr=NFS_SERVER_IP,rw \
  --opt device=:/exports/shared \
  nfs-vol

docker container run --rm \
  --mount type=volume,source=nfs-vol,target=/data \
  alpine sh -c 'echo "from container" > /data/hello; ls -l /data'

docker volume rm nfs-vol
```

Same volume API; the data lives on a remote NFS export. You'll see this pattern again with
Kubernetes CSI drivers (Session 20).

---

## Part 10: Inspect Disk Usage

```bash
docker system df
docker system df -v | less       # per-image, per-container, per-volume detail
```

---

## Clean Up

```bash
docker container rm -f $(docker container ls -aq) 2>/dev/null
docker volume rm pg-data pg-data-restore shared 2>/dev/null
docker volume prune -f
rm -rf ~/docker-lab-07
```

---

## Summary

After completing this lab you should be able to:

- Distinguish **named volumes**, **bind mounts**, **anonymous volumes**, and **tmpfs**
- Use the explicit `--mount type=…,source=…,target=…` syntax instead of fragile `-v`
- Persist a database across container replacements with a named volume
- Run a hot-reload dev loop with a read-only bind mount
- Share a volume between a producer and a (read-only) consumer
- Back up a volume to a tarball using a helper container + a host bind mount
- Restore that backup into a fresh volume

---

## Stretch Goals

1. Spin up two replicas of a stateful app pointing at the same named volume — what fails,
   and what does it tell you about why Kubernetes uses **ReadWriteOnce** PVs by default?
2. Using `--read-only` plus tmpfs on `/tmp` and `/run`, run an nginx container with **no
   writable filesystem at all**. What needs to be tmpfs for nginx to start?
3. Write a `cron`-friendly backup script that lists volumes by label, tars each one, names
   the file with the date and digest, and uploads to an S3-compatible bucket via `mc` (in
   a container).
