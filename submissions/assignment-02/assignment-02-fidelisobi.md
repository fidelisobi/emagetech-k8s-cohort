# Assignment 02 — Fidelis Obi

**GitHub username:** fidelisobi
**Date completed:** YYYY-MM-DD
**Language chosen:** Python

## 1. The image I built

- Final image ID: sha256:e7162fb36c6a3a6e98cc322d09bdb8212486449c9579a290b22ba624e50db235

- Image size: cohort-greet:0.1.0   e7162fb36c6a        186MB         45.4MB
- Number of layers: `<from docker image history | wc -l minus 1 for header>`

### Dockerfile
\`\`\`dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY app.py .
ENV PORT=8000
EXPOSE 8000
CMD ["python", "app.py"]
\`\`\`

### .dockerignore
\`\`\`
.git
.gitignore
node_modules
__pycache__
*.pyc
*.log
README.md
\`\`\`

## 2. Answers to the 8 questions

**Q1 — what `.dockerignore` affects:** dockerignore affects the build context — the set of files Docker sends to the Docker daemon when you run docker build.

Without .dockerignore: Docker sends every single file in the directory (and subdirectories) to the build context

With .dockerignore: Docker excludes matching files from being sent

**Q2 — what is the image ID a hash of:** The Image ID is a SHA256 hash of the image's configuration object, which contains metadata (environment variables, commands, ports) and an ordered list of all filesystem layer IDs that make up the image.

**Q3 — largest layer and why:** The largest row was 87.44MB from the Debian base OS layer (# debian.sh --arch 'amd64'...). This is the foundational Linux operating system that includes core utilities (bash, ls, grep), system libraries (glibc), package managers (apt), and the basic filesystem structure.

**Q4 — `--memory 64m` shows up as what value:** 67108864

**Q5 — PID of my app inside the container:** 1

**Q6 — `stop` vs `kill`, and which for a database:** docker stop sends SIGTERM (graceful shutdown), waits up to 10 seconds for the app to exit cleanly, then sends SIGKILL if needed. docker kill sends SIGKILL immediately, forcing the process to terminate without cleanup.
For a database container, always use stop. Databases need time to flush write buffers, close client connections, commit transactions, and write recovery logs. A forced kill risks data corruption, incomplete writes, or a longer recovery time on next startup.


**Q7 — what same-IMAGE-ID-across-tags proves:** It proves that Docker tags are just mutable pointers (references) to the same underlying image, not separate copies.

**Q8 — tag vs digest mutability:** Tags are mutable but digest are not mutable 

## 3. Evidence

Paste the **command + output** for each of these. Use fenced code blocks. Trim long output to the relevant lines.

- `docker image history cohort-greet:0.1.0`
```fidelis@workstation:~/assignment/assignment-02$ docker image history cohort-greet:0.1.0
IMAGE          CREATED        CREATED BY                                      SIZE      COMMENT
e7162fb36c6a   20 hours ago   CMD ["python" "app.py"]                         0B        buildkit.dockerfile.v0
<missing>      20 hours ago   EXPOSE [8000/tcp]                               0B        buildkit.dockerfile.v0
<missing>      20 hours ago   ENV PORT=8000                                   0B        buildkit.dockerfile.v0
<missing>      20 hours ago   COPY app.py . # buildkit                        12.3kB    buildkit.dockerfile.v0
<missing>      20 hours ago   WORKDIR /app                                    8.19kB    buildkit.dockerfile.v0
<missing>      2 days ago     CMD ["python3"]                                 0B        buildkit.dockerfile.v0
<missing>      2 days ago     RUN /bin/sh -c set -eux;  for src in idle3 p…   16.4kB    buildkit.dockerfile.v0
<missing>      2 days ago     RUN /bin/sh -c set -eux;   savedAptMark="$(a…   48.4MB    buildkit.dockerfile.v0
<missing>      2 days ago     ENV PYTHON_SHA256=272179ddd9a2e41a0fc8e42e33…   0B        buildkit.dockerfile.v0
<missing>      2 days ago     ENV PYTHON_VERSION=3.11.15                      0B        buildkit.dockerfile.v0
<missing>      2 days ago     ENV GPG_KEY=A035C8C19219BA821ECEA86B64E628F8…   0B        buildkit.dockerfile.v0
<missing>      2 days ago     RUN /bin/sh -c set -eux;  apt-get update;  a…   4.94MB    buildkit.dockerfile.v0
<missing>      2 days ago     ENV LANG=C.UTF-8                                0B        buildkit.dockerfile.v0
<missing>      2 days ago     ENV PATH=/usr/local/bin:/usr/local/sbin:/usr…   0B        buildkit.dockerfile.v0
<missing>      6 days ago     # debian.sh --arch 'amd64' out/ 'trixie' '@1…   87.4MB    debuerreotype 0.17```

- `docker container run` (Part 2.2 — the detached run with all flags)
```fidelis@workstation:~/assignment/assignment-02$ docker container run -d \
  --name greet \
  -p 8080:8000 \
  -e STUDENT_NAME="<your name>" \
  -e GREETING="hi" \
  --restart unless-stopped \
  --memory 64m \
  --cpus 0.25 \
  cohort-greet:0.1.0
d9db40180d4883484fc0615229ad16790737ee1cc37bcc0fa336ecca2060a6db```

- `docker container logs greet` after 2 curl requests

```fidelis@workstation:~/assignment/assignment-02$ docker container logs greet
listening on :8000
[req] 172.17.0.1 "GET / HTTP/1.1" 200 -
[req] 172.17.0.1 "GET / HTTP/1.1" 200 -
[req] 172.17.0.1 "GET /favicon.ico HTTP/1.1" 200 -
[req] 172.17.0.1 "GET / HTTP/1.1" 200 -
[req] 172.17.0.1 "GET /favicon.ico HTTP/1.1" 200 -```

- `docker container stats --no-stream greet`

```
fidelis@workstation:~/assignment/assignment-02$ docker container stats --no-stream greet
CONTAINER ID   NAME      CPU %     MEM USAGE / LIMIT   MEM %     NET I/O           BLOCK I/O         PIDS
49b1ed263fe2   greet     0.02%     13.49MiB / 64MiB    21.08%    5.84kB / 3.04kB   4.43MB / 1.95MB   1```

- `docker container inspect -f '{{.HostConfig.RestartPolicy.Name}} {{.HostConfig.Memory}}' greet`

```
fidelis@workstation:~/assignment/assignment-02$ docker container inspect -f '{{.HostConfig.RestartPolicy.Name}} {{.HostConfig.Memory}}' greet
unless-stopped 67108864```

- `docker image ls cohort-greet` (showing the three tags from Part 3.1)

```                                                                                                                                                          
IMAGE                 ID             DISK USAGE   CONTENT SIZE   EXTRA
cohort-greet:0.1      e7162fb36c6a        186MB         45.4MB    U
cohort-greet:0.1.0    e7162fb36c6a        186MB         45.4MB    U
cohort-greet:latest   e7162fb36c6a        186MB         45.4MB    U```

- (Optional) URL of your pushed image on Docker Hub / GHCR

## 4. One thing that surprised me

The size of the memory when I did a docker inspect image. It was different because docker read human memory description different (in bytes) when outputting it on the inspect command.

## 5. One thing I'm still unsure about

creating a dockerfile to know how to download some application on docker container run. 
