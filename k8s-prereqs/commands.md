# Linux Commands and File Permissions Cheatsheet

## Table of Contents
- [Linux Commands and File Permissions Cheatsheet](#linux-commands-and-file-permissions-cheatsheet)
  - [Table of Contents](#table-of-contents)
  - [1. Basic Navigation Commands](#1-basic-navigation-commands)
  - [2. File Operations](#2-file-operations)
  - [3. Directory Operations](#3-directory-operations)
  - [4. Text Viewing and Editing](#4-text-viewing-and-editing)
  - [5. File Permissions](#5-file-permissions)
    - [Permission Format](#permission-format)
    - [Numeric Permissions (chmod)](#numeric-permissions-chmod)
    - [Common Permission Commands](#common-permission-commands)
    - [Special Permissions](#special-permissions)
    - [Common File Permission Examples](#common-file-permission-examples)
  - [6. Process Management](#6-process-management)
  - [7. System Information](#7-system-information)
  - [8. Network Commands](#8-network-commands)
  - [9. Package Management](#9-package-management)
    - [Debian/Ubuntu (apt)](#debianubuntu-apt)
    - [Red Hat/CentOS/Fedora (yum/dnf)](#red-hatcentosfedora-yumdnf)
  - [10. Search Commands](#10-search-commands)
  - [11. Compression and Archiving](#11-compression-and-archiving)
  - [12. Disk Usage](#12-disk-usage)
  - [13. User Management](#13-user-management)
  - [14. Environment Variables](#14-environment-variables)
  - [15. Shell Redirections and Pipes](#15-shell-redirections-and-pipes)
  - [16. Docker Commands](#16-docker-commands)
    - [Common Docker Run Options](#common-docker-run-options)
    - [Docker Compose Example](#docker-compose-example)
  - [17. Kubernetes Commands](#17-kubernetes-commands)
    - [Common kubectl Options](#common-kubectl-options)
    - [kubectl Context Management Tools](#kubectl-context-management-tools)
    - [k9s - Kubernetes CLI Dashboard](#k9s---kubernetes-cli-dashboard)
  - [18. Helm Commands](#18-helm-commands)

---

## 1. Basic Navigation Commands

| Command | Description | Example |
|---------|-------------|---------|
| `pwd` | Print working directory | `pwd` |
| `ls` | List directory contents | `ls -la` |
| `ls -l` | List in long format | `ls -l` |
| `ls -a` | Show hidden files | `ls -a` |
| `ls -la` | Long format with hidden files | `ls -la` |
| `ls -lh` | Long format with human-readable sizes | `ls -lh` |
| `cd` | Change directory | `cd /etc` |
| `cd ~` | Go to home directory | `cd ~` |
| `cd ..` | Go up one directory | `cd ..` |
| `cd -` | Go to previous directory | `cd -` |

## 2. File Operations

| Command | Description | Example |
|---------|-------------|---------|
| `touch` | Create an empty file | `touch file.txt` |
| `cp` | Copy files or directories | `cp file1 file2` |
| `cp -r` | Copy directories recursively | `cp -r dir1 dir2` |
| `mv` | Move or rename files | `mv file1 file2` |
| `rm` | Remove files | `rm file.txt` |
| `rm -f` | Force remove files | `rm -f file.txt` |
| `rm -r` | Remove directories recursively | `rm -r directory` |
| `rm -rf` | Force remove directories recursively | `rm -rf directory` |
| `ln -s` | Create symbolic link | `ln -s target link_name` |
| `file` | Determine file type | `file document.pdf` |

## 3. Directory Operations

| Command | Description | Example |
|---------|-------------|---------|
| `mkdir` | Create a directory | `mkdir new_dir` |
| `mkdir -p` | Create nested directories | `mkdir -p dir1/dir2/dir3` |
| `rmdir` | Remove empty directory | `rmdir empty_dir` |
| `tree` | Display directory tree | `tree -L 2` |

## 4. Text Viewing and Editing

| Command | Description | Example |
|---------|-------------|---------|
| `cat` | Display file contents | `cat file.txt` |
| `less` | View file with pagination | `less large_file.txt` |
| `more` | View file with pagination | `more large_file.txt` |
| `head` | Show first 10 lines | `head file.txt` |
| `head -n` | Show first n lines | `head -n 20 file.txt` |
| `tail` | Show last 10 lines | `tail file.txt` |
| `tail -n` | Show last n lines | `tail -n 20 file.txt` |
| `tail -f` | Follow file additions | `tail -f log_file` |
| `nano` | Simple text editor | `nano file.txt` |
| `vim` | Vi improved text editor | `vim file.txt` |
| `grep` | Search for patterns | `grep "pattern" file.txt` |
| `grep -i` | Case-insensitive search | `grep -i "pattern" file.txt` |
| `grep -r` | Recursive search | `grep -r "pattern" directory/` |
| `wc` | Count lines, words, chars | `wc file.txt` |
| `wc -l` | Count lines only | `wc -l file.txt` |

## 5. File Permissions

### Permission Format

```
drwxrwxrwx    user    group
↑│││││││││    │       │
││││││││││    │       └─ Group owner
││││││││││    └─ User owner
│└┴┴┘└┴┴┘└─ Permissions (r=read, w=write, x=execute)
└─ File type (d=directory, -=file, l=link)
```

### Numeric Permissions (chmod)

| Number | Permission | Description |
|--------|------------|-------------|
| 0 | `---` | No permissions |
| 1 | `--x` | Execute only |
| 2 | `-w-` | Write only |
| 3 | `-wx` | Write and execute |
| 4 | `r--` | Read only |
| 5 | `r-x` | Read and execute |
| 6 | `rw-` | Read and write |
| 7 | `rwx` | Read, write, and execute |

### Common Permission Commands

| Command | Description | Example |
|---------|-------------|---------|
| `chmod` | Change file permissions | `chmod 755 file.txt` |
| `chmod -R` | Recursive permission change | `chmod -R 755 directory/` |
| `chmod u+x` | Add execute for user | `chmod u+x script.sh` |
| `chmod g-w` | Remove write for group | `chmod g-w file.txt` |
| `chmod o=r` | Set other to read only | `chmod o=r file.txt` |
| `chown` | Change file owner | `chown user file.txt` |
| `chown user:group` | Change owner and group | `chown user:group file.txt` |
| `chown -R` | Recursive ownership change | `chown -R user directory/` |
| `chgrp` | Change group owner | `chgrp group file.txt` |
| `umask` | Set default permissions | `umask 022` |

### Special Permissions

| Permission | Octal Value | Effect on Files | Effect on Directories |
|------------|-------------|-----------------|------------------------|
| SUID | 4000 | Execute as owner | No effect |
| SGID | 2000 | Execute as group | New files inherit directory group |
| Sticky Bit | 1000 | No effect | Only owner can delete files |

Examples:
```bash
# Set SUID
chmod u+s file.txt   # or chmod 4755 file.txt

# Set SGID
chmod g+s directory/  # or chmod 2755 directory/

# Set sticky bit
chmod +t directory/   # or chmod 1755 directory/
```

### Common File Permission Examples

```bash
# Script Execution
# Make a script executable for owner
chmod u+x script.sh

# Make a script executable for everyone
chmod +x script.sh

# Run a script
./script.sh

# Web Server Files
# Set permissions for web files
chmod 644 /var/www/html/*.html  # rw-r--r--

# Set permissions for web directories
chmod 755 /var/www/html/        # rwxr-xr-x

# Configuration Files
# Secure config files - readable only by owner
chmod 600 config.conf  # rw-------

# Read-only config files for group access
chmod 640 config.conf  # rw-r-----

# SSH Keys
# Set proper permissions for SSH private keys
chmod 600 ~/.ssh/id_rsa  # rw-------

# Set permissions for SSH public keys
chmod 644 ~/.ssh/id_rsa.pub  # rw-r--r--

# Securing a Directory
# Only owner can access directory contents
chmod 700 ~/private/  # rwx------

# Setting Default Permissions with umask
# Files default to 644, directories to 755
umask 022

# Files default to 600, directories to 700 (more private)
umask 077

# Recursive Permission Changes
# Make all files in a directory readable
chmod -R a+r /path/to/files/

# Give owner full permissions recursively
chmod -R u+rwX /path/to/directory/
# Note: capital X only adds execute to directories, not files
```

## 6. Process Management

| Command | Description | Example |
|---------|-------------|---------|
| `ps` | Show current processes | `ps` |
| `ps aux` | Show all processes | `ps aux` |
| `ps aux \| grep name` | Find process by name | `ps aux \| grep nginx` |
| `top` | Real-time process monitoring | `top` |
| `htop` | Enhanced real-time monitoring | `htop` |
| `kill` | Terminate process by PID | `kill 1234` |
| `kill -9` | Force terminate process | `kill -9 1234` |
| `killall` | Kill process by name | `killall firefox` |
| `bg` | Send process to background | `bg` |
| `fg` | Bring process to foreground | `fg` |
| `jobs` | List background jobs | `jobs` |
| `nohup` | Run command immune to hangups | `nohup command &` |
| `&` | Run command in background | `command &` |
| `nice` | Run with modified priority | `nice -n 10 command` |
| `renice` | Modify process priority | `renice 10 -p 1234` |

## 7. System Information

| Command | Description | Example |
|---------|-------------|---------|
| `uname -a` | Show system information | `uname -a` |
| `hostname` | Show or set hostname | `hostname` |
| `uptime` | Show uptime and load | `uptime` |
| `who` | Show who is logged in | `who` |
| `whoami` | Display effective user ID | `whoami` |
| `id` | Show user and group info | `id` |
| `date` | Show or set system date | `date` |
| `cal` | Show calendar | `cal` |
| `free` | Show memory usage | `free -h` |
| `df` | Show disk usage | `df -h` |
| `du` | Show directory space usage | `du -sh directory/` |
| `lsblk` | List block devices | `lsblk` |
| `lsusb` | List USB devices | `lsusb` |
| `lspci` | List PCI devices | `lspci` |
| `dmidecode` | Display hardware info | `sudo dmidecode` |

## 8. Network Commands

| Command | Description | Example |
|---------|-------------|---------|
| `ifconfig` | Show network interfaces | `ifconfig` |
| `ip a` | Show IP addresses | `ip a` |
| `netstat` | Network statistics | `netstat -tuln` |
| `ss` | Socket statistics | `ss -tuln` |
| `ping` | Test network connectivity | `ping google.com` |
| `traceroute` | Trace route to host | `traceroute google.com` |
| `dig` | DNS lookup utility | `dig google.com` |
| `nslookup` | Query DNS records | `nslookup google.com` |
| `host` | DNS lookup | `host google.com` |
| `whois` | Query whois servers | `whois domain.com` |
| `curl` | Transfer data from/to URLs | `curl -O https://url/file` |
| `wget` | Download files from web | `wget https://url/file` |
| `ssh` | Secure shell client | `ssh user@host` |
| `scp` | Secure copy | `scp file user@host:/path` |
| `rsync` | Remote file sync | `rsync -av src/ dest/` |
| `telnet` | Connect to a port | `telnet host port` |
| `nc` | Netcat utility | `nc -zv host port` |
| `iptables` | IP packet filter admin | `sudo iptables -L` |

## 9. Package Management

### Debian/Ubuntu (apt)

| Command | Description | Example |
|---------|-------------|---------|
| `apt update` | Update package lists | `sudo apt update` |
| `apt upgrade` | Upgrade packages | `sudo apt upgrade` |
| `apt install` | Install packages | `sudo apt install package` |
| `apt remove` | Remove packages | `sudo apt remove package` |
| `apt purge` | Remove packages and configs | `sudo apt purge package` |
| `apt search` | Search for packages | `apt search keyword` |
| `apt list` | List packages | `apt list --installed` |
| `apt show` | Show package details | `apt show package` |
| `dpkg -i` | Install .deb file | `sudo dpkg -i file.deb` |
| `dpkg -l` | List installed packages | `dpkg -l` |

### Red Hat/CentOS/Fedora (yum/dnf)

| Command | Description | Example |
|---------|-------------|---------|
| `yum update` | Update packages | `sudo yum update` |
| `yum install` | Install packages | `sudo yum install package` |
| `yum remove` | Remove packages | `sudo yum remove package` |
| `yum search` | Search for packages | `yum search keyword` |
| `yum list` | List packages | `yum list installed` |
| `yum info` | Show package info | `yum info package` |
| `rpm -i` | Install .rpm file | `sudo rpm -i file.rpm` |
| `rpm -q` | Query installed packages | `rpm -q package` |
| `rpm -qa` | List all installed packages | `rpm -qa` |

## 10. Search Commands

| Command | Description | Example |
|---------|-------------|---------|
| `find` | Find files/directories | `find /path -name "file"` |
| `find -type` | Find by type (f=file, d=dir) | `find /path -type f` |
| `find -size` | Find by size | `find /path -size +10M` |
| `find -exec` | Find and execute command | `find /path -name "*.txt" -exec rm {} \;` |
| `locate` | Find files by name | `locate filename` |
| `updatedb` | Update locate database | `sudo updatedb` |
| `which` | Show command location | `which command` |
| `whereis` | Locate binary, source, manual | `whereis command` |

## 11. Compression and Archiving

| Command | Description | Example |
|---------|-------------|---------|
| `tar -cf` | Create tar archive | `tar -cf archive.tar files` |
| `tar -xf` | Extract tar archive | `tar -xf archive.tar` |
| `tar -czf` | Create gzipped tar | `tar -czf archive.tar.gz files` |
| `tar -xzf` | Extract gzipped tar | `tar -xzf archive.tar.gz` |
| `tar -cjf` | Create bzipped tar | `tar -cjf archive.tar.bz2 files` |
| `tar -xjf` | Extract bzipped tar | `tar -xjf archive.tar.bz2` |
| `tar -tvf` | List content of tar | `tar -tvf archive.tar` |
| `gzip` | Compress files | `gzip file` |
| `gunzip` | Decompress gzipped files | `gunzip file.gz` |
| `bzip2` | Compress files | `bzip2 file` |
| `bunzip2` | Decompress bzipped files | `bunzip2 file.bz2` |
| `zip` | Create zip archive | `zip archive.zip files` |
| `unzip` | Extract zip archive | `unzip archive.zip` |
| `7z` | 7-Zip archiver | `7z a archive.7z files` |

## 12. Disk Usage

| Command | Description | Example |
|---------|-------------|---------|
| `df` | Show disk usage | `df -h` |
| `df -i` | Show inode usage | `df -i` |
| `du` | Show directory size | `du -sh directory` |
| `du -a` | Show file and dir sizes | `du -a directory` |
| `ncdu` | NCurses disk usage viewer | `ncdu /path` |
| `lsblk` | List block devices | `lsblk` |
| `blkid` | Show block device attributes | `sudo blkid` |
| `fdisk -l` | List disk partitions | `sudo fdisk -l` |
| `mount` | Show mounted filesystems | `mount` |
| `umount` | Unmount a filesystem | `sudo umount /dev/sda1` |

## 13. User Management

| Command | Description | Example |
|---------|-------------|---------|
| `useradd` | Add a new user | `sudo useradd username` |
| `userdel` | Delete a user | `sudo userdel username` |
| `usermod` | Modify user account | `sudo usermod -aG group username` |
| `passwd` | Change user password | `sudo passwd username` |
| `groupadd` | Create a new group | `sudo groupadd groupname` |
| `groupdel` | Delete a group | `sudo groupdel groupname` |
| `groupmod` | Modify a group | `sudo groupmod -n newname oldname` |
| `groups` | Show user groups | `groups username` |
| `who` | Show logged in users | `who` |
| `w` | Show who is logged in and what they're doing | `w` |
| `last` | Show last logins | `last` |
| `su` | Switch user | `su username` |
| `sudo` | Execute command as another user | `sudo command` |
| `visudo` | Edit sudoers file | `sudo visudo` |

## 14. Environment Variables

| Command | Description | Example |
|---------|-------------|---------|
| `env` | Display environment variables | `env` |
| `echo $VAR` | Display value of a variable | `echo $PATH` |
| `export` | Set environment variable | `export VAR=value` |
| `unset` | Remove variable | `unset VAR` |
| `printenv` | Print environment variables | `printenv` |
| `set` | Display/set shell variables | `set` |
| `source` | Run commands from file | `source .bashrc` |
| `.` | Same as source | `. .bashrc` |

## 15. Shell Redirections and Pipes

| Operator | Description | Example |
|----------|-------------|---------|
| `>` | Redirect output to file (overwrite) | `ls > file.txt` |
| `>>` | Redirect output to file (append) | `ls >> file.txt` |
| `<` | Read input from file | `sort < file.txt` |
| `2>` | Redirect stderr to file | `command 2> errors.txt` |
| `2>&1` | Redirect stderr to stdout | `command > file.txt 2>&1` |
| `&>` | Redirect both stdout and stderr | `command &> file.txt` |
| `\|` | Pipe output to another command | `ls \| grep "pattern"` |
| `tee` | Read from stdin and write to stdout/files | `ls \| tee file.txt` |
| `/dev/null` | Discard output | `command > /dev/null` |

## 16. Docker Commands

| Command | Description | Example |
|---------|-------------|---------|
| `docker container run` | Run a container | `docker container run -d --name web nginx` |
| `docker container ls` | List running containers | `docker container ls` |
| `docker container ls -a` | List all containers | `docker container ls -a` |
| `docker image ls` | List images | `docker image ls` |
| `docker image pull` | Pull an image | `docker image pull nginx:latest` |
| `docker image build` | Build an image | `docker image build -t myapp:1.0 .` |
| `docker container exec` | Execute command in container | `docker container exec -it container_id bash` |
| `docker container logs` | View container logs | `docker container logs container_id` |
| `docker container stop` | Stop container | `docker container stop container_id` |
| `docker container start` | Start container | `docker container start container_id` |
| `docker container restart` | Restart container | `docker container restart container_id` |
| `docker container rm` | Remove container | `docker container rm container_id` |
| `docker image rm` | Remove image | `docker image rm image_id` |
| `docker network create` | Create a network | `docker network create mynet` |
| `docker network ls` | List networks | `docker network ls` |
| `docker network inspect` | Inspect a network | `docker network inspect mynet` |
| `docker volume create` | Create a volume | `docker volume create myvol` |
| `docker volume ls` | List volumes | `docker volume ls` |
| `docker-compose up` | Start services | `docker-compose up -d` |
| `docker-compose down` | Stop services | `docker-compose down` |
| `docker image tag` | Tag an image | `docker image tag myapp:1.0 registry/myapp:1.0` |
| `docker image push` | Push image to registry | `docker image push registry/myapp:1.0` |
| `docker container inspect` | Inspect container | `docker container inspect container_id` |
| `docker image inspect` | Inspect image | `docker image inspect image_id` |
| `docker container stats` | Container resource stats | `docker container stats` |
| `docker system prune` | Remove unused data | `docker system prune -a` |
| `docker login` | Log in to registry | `docker login registry.example.com` |
| `docker image save` | Save image to tar archive | `docker image save -o image.tar myimage` |
| `docker image load` | Load image from tar archive | `docker image load -i image.tar` |
| `docker container cp` | Copy files between container and local | `docker container cp container_id:/path/to/file local_path` |
| `docker container port` | Show port mappings | `docker container port container_id` |
| `docker container rename` | Rename a container | `docker container rename old_name new_name` |
| `docker container update` | Update container configuration | `docker container update --memory 512m container_id` |

### Common Docker Run Options

| Option | Description | Example |
|--------|-------------|---------|
| `-d` | Detached mode | `docker container run -d nginx` |
| `-p` | Port mapping | `docker container run -p 8080:80 nginx` |
| `-v` | Volume mount | `docker container run -v /host/path:/container/path nginx` |
| `--name` | Container name | `docker container run --name web nginx` |
| `-e` | Environment variable | `docker container run -e VAR=value nginx` |
| `--network` | Connect to network | `docker container run --network mynet nginx` |
| `--rm` | Remove on exit | `docker container run --rm nginx` |
| `-it` | Interactive with TTY | `docker container run -it ubuntu bash` |

### Docker Compose Example

```yaml
version: '3'
services:
  web:
    image: nginx:latest
    ports:
      - "8080:80"
    volumes:
      - ./html:/usr/share/nginx/html
    depends_on:
      - db
  db:
    image: postgres:13
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: mydb
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  db_data:
```

## 17. Kubernetes Commands

| Command | Description | Example |
|---------|-------------|---------|
| `kubectl get` | List resources | `kubectl get pods` |
| `kubectl describe` | Show details of a resource | `kubectl describe pod mypod` |
| `kubectl create` | Create a resource | `kubectl create -f yaml-file.yaml` |
| `kubectl apply` | Create/update resources | `kubectl apply -f yaml-file.yaml` |
| `kubectl delete` | Delete resources | `kubectl delete pod mypod` |
| `kubectl logs` | View container logs | `kubectl logs mypod` |
| `kubectl exec` | Execute command in container | `kubectl exec -it mypod -- /bin/bash` |
| `kubectl port-forward` | Forward ports | `kubectl port-forward mypod 8080:80` |
| `kubectl config` | Modify kubeconfig files | `kubectl config use-context my-context` |
| `kubectl expose` | Expose a resource as a service | `kubectl expose deployment nginx --port=80` |
| `kubectl scale` | Scale a resource | `kubectl scale deployment nginx --replicas=3` |
| `kubectl rollout` | Manage rollouts | `kubectl rollout restart deployment/nginx` |
| `kubectl cluster-info` | Display cluster info | `kubectl cluster-info` |
| `kubectl top` | Show resource usage | `kubectl top pods` |
| `kubectl auth` | Check authorization | `kubectl auth can-i create pods` |
| `kubectl label` | Add/update labels | `kubectl label pods mypod env=prod` |
| `kubectl annotate` | Add/update annotations | `kubectl annotate pods mypod note='important'` |
| `kubectl diff` | Diff live vs local config | `kubectl diff -f config.yaml` |
| `kubectl explain` | Documentation for resources | `kubectl explain pods.spec` |
| `kubectl api-resources` | List supported resources | `kubectl api-resources` |

### Common kubectl Options

| Option | Description | Example |
|--------|-------------|---------|
| `-n, --namespace` | Set namespace | `kubectl get pods -n kube-system` |
| `-o, --output` | Output format | `kubectl get pods -o wide` |
| `--all-namespaces` | All namespaces | `kubectl get pods --all-namespaces` |
| `-l, --selector` | Label selector | `kubectl get pods -l app=nginx` |
| `--field-selector` | Field selector | `kubectl get pods --field-selector status.phase=Running` |
| `-w, --watch` | Watch for changes | `kubectl get pods -w` |
| `--dry-run` | Test run | `kubectl create -f pod.yaml --dry-run=client` |

### kubectl Context Management Tools

| Command | Description | Example |
|---------|-------------|---------|
| `kubectx` | Switch between Kubernetes contexts | `kubectx prod-cluster` |
| `kubectx -` | Switch to previous context | `kubectx -` |
| `kubectx -c` | Show current context | `kubectx -c` |
| `kubens` | Switch between Kubernetes namespaces | `kubens kube-system` |
| `kubens -` | Switch to previous namespace | `kubens -` |
| `kubens -c` | Show current namespace | `kubens -c` |

### k9s - Kubernetes CLI Dashboard

| Command/Shortcut | Description | 
|---------|-------------|
| `k9s` | Launch k9s dashboard |
| `:namespace` | Switch namespace (in k9s) |
| `:pod` | View pods (in k9s) |
| `:deployment` | View deployments (in k9s) |
| `:service` | View services (in k9s) |
| `ctrl+d` | Delete resource (in k9s) |
| `d` | Describe resource (in k9s) |
| `l` | View logs (in k9s) |
| `s` | Shell into container (in k9s) |
| `?` | Show help (in k9s) |
| `ctrl+c` | Exit k9s |

## 18. Helm Commands

| Command | Description | Example |
|---------|-------------|---------|
| `helm create` | Create new chart | `helm create mychart` |
| `helm install` | Install a chart | `helm install myrelease mychart` |
| `helm upgrade` | Upgrade a release | `helm upgrade myrelease mychart` |
| `helm uninstall` | Uninstall a release | `helm uninstall myrelease` |
| `helm list` | List releases | `helm list` |
| `helm status` | Get release status | `helm status myrelease` |
| `helm repo add` | Add chart repository | `helm repo add stable https://charts.helm.sh/stable` |
| `helm repo update` | Update repositories | `helm repo update` |
| `helm repo list` | List repositories | `helm repo list` |
| `helm search repo` | Search repositories | `helm search repo nginx` |
| `helm search hub` | Search Helm Hub | `helm search hub prometheus` |
| `helm pull` | Download chart | `helm pull stable/mysql` |
| `helm show values` | Show chart values | `helm show values stable/mysql` |
| `helm show chart` | Show chart info | `helm show chart stable/mysql` |
| `helm get values` | Get release values | `helm get values myrelease` |

