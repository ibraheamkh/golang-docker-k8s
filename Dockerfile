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
    #&& ls \
    #here we initiate the folder for go modules
    && go mod init github.com/ibraheamkh/golang-docker-k8s \
    #build the binary for linux, extra flags to produce "" 
    && GOOS=linux GOARCH=amd64 go build -a -tags netgo -ldflags '-w -extldflags "-static"' -o golang-app main.go  \
    #change the binary to be executable
    && chmod +x golang-app 

# run stage, we use minimal alpine image just enough to run the binary 
FROM alpine
LABEL maintainer="Ibrahim Alkhalifah ibraheam@akwad.co"
#setting the user directory to point to os binaries folder
WORKDIR /usr/local/bin
#copying the binary to the working environment 
COPY --from=build-env /app/golang-app . 
#expose the port that we want TODO: maybe expose more than one port 
EXPOSE 80
EXPOSE 8080
#run the code, TODO: maybe try with CMD command
ENTRYPOINT ["golang-app"]
