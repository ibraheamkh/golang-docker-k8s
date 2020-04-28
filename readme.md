
# Dockerize Golang App, Deploy to K8s


In this post I will write a simple Golang app, build a docker container and deploy it to local k8s cluster, all the files are in [this repo](https://github.com/ibraheamkh/golang-docker-k8s) 

## First

Lets install pre requsite

1. Golang 
2. Docker
4. Install `kubectl` Kubernetes Client
3. Kubernetes Cluster, We will use k3d,  a small k8s running in docker contaners

### Golang Installation

First we need to install `golang` version `1.13` or above:

1. You can check the golang official [docs](https://golang.org) for your operating system, follow the instructions to install it
2. Simpler way
   - On a MacOS yoo can simply type `brew install go` if you use `homebrew`
   - On a Windows you can simply type `choco install golang` on `PowerShell` or `cmd` if you use `choco`, if you do not use `choco` on windows you should check choco [homepage](https://chocolatey.org)

After installing you can verify your installation by typing `go version` it should display something like this

```cmd
❯ go version
go version go1.13.8 darwin/amd64 
```

### Docker installation

Install docker from [Docker Official Docs](https://docs.docker.com/get-docker/)

To verficy docker is installed type 

```bash
❯ docker version
Client: Docker Engine - Community
 Version:           19.03.8
 API version:       1.40
 Go version:        go1.12.17
 Git commit:        afacb8b
 Built:             Wed Mar 11 01:21:11 2020
 OS/Arch:           darwin/amd64
 Experimental:      false

Server: Docker Engine - Community
 Engine:
  Version:          19.03.8
  API version:      1.40 (minimum version 1.12)
  Go version:       go1.12.17
  Git commit:       afacb8b
  Built:            Wed Mar 11 01:29:16 2020
  OS/Arch:          linux/amd64
  Experimental:     true
 containerd:
  Version:          v1.2.13
  GitCommit:        7ad184331fa3e55e52b890ea95e65ba581ae3429
 runc:
  Version:          1.0.0-rc10
  GitCommit:        dc9208a3303feef5b3839f4323d9beb36df0a9dd
 docker-init:
  Version:          0.18.0
  GitCommit:        fec3683
```
### Kubectl Installation

Install the tool
```bash
❯ brew install kubectl
```

Verify installation
```bash
❯ kubectl version
Client Version: version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.2", GitCommit:"52c56ce7a8272c798dbc29846288d7cd9fbae032", GitTreeState:"clean", BuildDate:"2020-04-16T23:35:15Z", GoVersion:"go1.14.2", Compiler:"gc", Platform:"darwin/amd64"}
Server Version: version.Info{Major:"1", Minor:"17", GitVersion:"v1.17.4+k3s1", GitCommit:"3eee8ac3a1cf0a216c8a660571329d4bda3bdf77", GitTreeState:"clean", BuildDate:"2020-03-25T16:13:25Z", GoVersion:"go1.13.8", Compiler:"gc", Platform:"linux/amd64"}
```
### Local Kubernetes installation, on Docker contaners

Install `k3d` a cli helper tool to spin kubenetes using docker containers, for more details check [k3d Github Repo](https://github.com/rancher/k3d)

```bash
❯ brew install k3d
```

Create the local kubernetes cluster with two workers exposing some node ports  

```bash
❯ k3d create --publish 8080:30080@k3d-k3s-default-worker-0 --workers 2
INFO[0000] Created cluster network with ID 345410a9543b38caec04dd53a21621b1c64f21cde56b00f83cf2301b36fff91a
INFO[0000] Created docker volume  k3d-k3s-default-images
INFO[0000] Creating cluster [k3s-default]
INFO[0000] Creating server using docker.io/rancher/k3s:latest...
INFO[0000] Booting 2 workers for cluster k3s-default
INFO[0000] Created worker with ID 0758c98bc213ed7786b07355bebd917821b7c334d2cae17745de595bfc7f0551
INFO[0001] Created worker with ID 499f1cf4b6f91761979f2d563137d14569c9a3a57dbbd4db9ff76474a6a0256a
INFO[0001] SUCCESS: created cluster [k3s-default]
INFO[0001] You can now use the cluster with:

export KUBECONFIG="$(k3d get-kubeconfig --name='k3s-default')"
kubectl cluster-info
```
Configure the `kubectl` tool to use the newly created cluster
``` bash
❯ export KUBECONFIG="$(k3d get-kubeconfig --name='k3s-default')"
```

Verify you connected to the right cluster
```bash
❯ kubectl cluster-info
Kubernetes master is running at https://localhost:6443
CoreDNS is running at https://localhost:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://localhost:6443/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

```

## Lets code it in Golang

Lets create app 

- Type `mkdir golang-docker-k8s && cd golang-docker-k8s`
- Type `touch main.go`
- Open `main.go` in any editor you like
- Copy and paste the following

    ```go
    package main

    import "log"

    func main() {
            log.Println("Hello Golang")
    }
    ```

- You can try to run it by typing `go run main.go` you should see something like this

```bash
~/Development/golang/golang-docker-k8s
❯ go run main.go
Hello Golang
```

Nice, so we are done from the setup, let's head to creating our HTTP server, the cool thing is that you can run a HTTP server in Golang with one line of code

```go
  package main

import (
	"net/http"
)

func main() {
	//handler func, in golang functions are first class citizens, cool
	//also dynamic kind of dynamic typing but the langauge is actually statically typed
	helloHandler := func(w http.ResponseWriter, r *http.Request) {

		w.Write([]byte("Hello Golang"))
	}
	//map endpoint with handler
	http.HandleFunc("/", helloHandler)
	//run server on given port
	http.ListenAndServe(":8080", nil)
}
```

Type `go run main.go` and visit `127.0.0.1:8080` to check the server

## Lets Dockerize it, (Create a docker image for your app, you can skip this and just use any public image)

Content of `Dockerfile`

```Dockerfile
# build stage, we use alpine image as it is small image
FROM golang:alpine AS build-env
LABEL maintainer="Ibrahim Alkhalifah ibraheam@akwad.co"
#Adding files to specific directory
COPY . /app
#Changing working directory to /app, same as "cd" command in linux
WORKDIR /app
## install the needed deps for golang, we install them all at once because we do not want to  add more layers to docker 
RUN apk --update --no-cache add \
    #install git because alpine does not have git and we need git to use the command 'go get'
    git \
    gcc \
    musl-dev \
    util-linux-dev \
    #here we initiate the folder for go modules
    && go mod init github.com/ibraheamkh/golang-docker-k8s \
    #build the binary for linux, extra flags to produce statically linked binary
    && GOOS=linux GOARCH=amd64 go build -a -tags netgo -ldflags '-w -extldflags "-static"' -o golang-app main.go  \
    #change the binary to be executable
    && chmod +x golang-app 

# run stage, we use minimal alpine image just enough to run the binary 
FROM alpine
LABEL maintainer="Ibrahim Alkhalifah ibraheam@akwad.co"
#cd to /usr/local/bin
WORKDIR /usr/local/bin
#copying the binary to the current working directory
COPY --from=build-env /app/golang-app . 
#expose the port that we want 
EXPOSE 8080
#run the code, TODO: maybe try with CMD command
ENTRYPOINT ["golang-app"]

```

build the image, you may specify the image name as you want, I used my [Docker Hub repo](https://hub.docker.com/r/ibraheamkh/golang-docker-k8s)

```bash
~/Development/golang/golang-docker-k8s
❯ docker build -t ibraheamkh/golang-docker-k8s .
```

Push the image 

```bash
~/Development/golang/golang-docker-k8s
❯ docker push ibraheamkh/golang-docker-k8s

```


## Deploy to kubernetes

First we need to create our kuberntes manifists in `k8s-manifists/` folder

Content of `k8s-manifists/deployment.yml`

```yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: golang-docker-k8s 
  name: golang-docker-k8s 
spec:
  replicas: 2
  selector:
    matchLabels:
      app: golang-docker-k8s 
  template:
    metadata:
      labels:
        app: golang-docker-k8s 
    spec:
      containers:
        - image: docker.io/ibreaheamkh/golang-docker-k8s # you can use any public image here
          name: golang-app 
          imagePullPolicy: Always
          resources:
            requests:
              cpu: "250m"
              memory: "64Mi"
            limits:
              cpu: "500m"
              memory: "128Mi"

```

Content of `k8s-manifists/service.yml`

```yaml

apiVersion: v1
kind: Service
metadata:
  labels:
    app: golang-docker-k8s
  name: golang-docker-k8s
spec:
  ports:
  - nodePort: 30080 # We need to use this node port specifically because we exposed this port with k3d
    port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: golang-docker-k8s
  type: NodePort

```

Now we will use `kubectl` to deploy to k8s

1. Apply K8s Deplyment

```bash
~/Development/golang/golang-docker-k8s
❯ kubectl apply -f k8s-manifists/deployment.yml
deployment.apps/golang-docker-k8s created
```

2. Apply K8s Service

```bash
~/Development/golang/golang-docker-k8s
❯ kubectl apply -f k8s-manifists/service.yml
service/golang-docker-k8s created
```

3. Make sure everything is deployed

```bash
❯ kubectl get all
NAME                                     READY   STATUS    RESTARTS   AGE
pod/golang-docker-k8s-569db68b46-6jqz6   1/1     Running   0          8m49s
pod/golang-docker-k8s-569db68b46-fkgdf   1/1     Running   0          8m49s

NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
service/kubernetes          ClusterIP   10.43.0.1       <none>        443/TCP          48m
service/golang-docker-k8s   NodePort    10.43.142.246   <none>        8080:30080/TCP   8m19s

NAME                                READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/golang-docker-k8s   2/2     2            2           8m49s

NAME                                           DESIRED   CURRENT   READY   AGE
replicaset.apps/golang-docker-k8s-569db68b46   2         2         2       8m49s

```

## Lets test it

```bash
❯ curl localhost:8080
Hello Golang%
```