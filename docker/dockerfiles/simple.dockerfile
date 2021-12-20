FROM golang:1.17-bullseye AS build
WORKDIR /go/src/github.com/pedroAkos/go-libp2p-simple
ENV CGO_ENABLED=0
COPY go-libp2p-simple/go.mod .
RUN go mod download
COPY go-libp2p-simple .
RUN go build -o /out/simple cmd/simple.go
FROM debian:buster-slim as app
COPY dht/docker/pkg/install-packages.sh .

RUN ./install-packages.sh

COPY --from=build /out/simple /

ADD go-libp2p-simple/docker/emulation/setupClassTcBatch.sh setupTc.sh
ADD go-libp2p-simple/docker/scripts/start-simple.sh start.sh

ENTRYPOINT ["./setupTc.sh"]