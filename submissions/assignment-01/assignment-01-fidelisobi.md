Part 1
which CLI command - docker container exec - this was new to me. I used it for executing command in my docker container. 

docker comtainer inspect  - this is used to run json commands about the container.

docker container prune - this is use to clear unused container.

Part 2

3.19: Pulling from library/alpine
17a39c0ba978: Pull complete
fd18d7b2aa35: Download complete
ef1614f30685: Download complete
Digest: sha256:6baf43584bcb78f2e5847d1de515f23499913ac9f12bdf834811a3145eb11ca1
Status: Downloaded newer image for alpine:3.19
docker.io/library/alpine:3.19


IMAGE                  ID             DISK USAGE   CONTENT SIZE   EXTRA
alpine:3.19            6baf43584bcb       11.6MB         3.51MB        
mongo-express:latest   1b23d7976f02        287MB         59.8MB        
mongo:latest           7abfba0d07c9        1.3GB          341MB        
my-app:1.0             46f2828b87a0       1.45GB          583MB        
postgres:14.22         e493b5ef86b5        628MB          163MB        
postgres:17.9          7b405451d054        645MB          167MB

- from my own environment, I have 5 images

- no container is running at the moment 

Docker Exec -it is used to run commands inside a container while while - docker run -it is used to start a container in an interactive shell



PART 3 -

CONTAINER ID   IMAGE        COMMAND                  CREATED          STATUS          PORTS                                     NAMES
b420112ca037   nginx:1.25   "/docker-entrypoint.…"   27 seconds ago   Up 26 seconds   0.0.0.0:8081->80/tcp, [::]:8081->80/tcp   practice-web
fidelis@workstation:~$


The browser page after step 8 showing your custom message - Hello from Fidelis

fidelis@workstation:~$ docker container inspect -f '{{.NetworkSettings.IPAddress}}' practice-web

template parsing error: template: :1:18: executing "" at <.NetworkSettings.IPAddress>: map has no entry for key "IPAddress"


PART 4 - Docker behaves like a whole operating system. but in a minute form.. 



