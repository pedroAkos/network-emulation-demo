package main

import (
	"context"
	"encoding/binary"
	"flag"
	"fmt"
	golog "github.com/ipfs/go-log"
	"github.com/libp2p/go-libp2p-core/peer"
	dht "github.com/libp2p/go-libp2p-kad-dht"
	"github.com/multiformats/go-multiaddr"
	"github.com/pedroAkos/go-lip2p-simple/pkg/host"
	gologging "github.com/whyrusleeping/go-logging"
	"log"
	"net"
	"time"
)

func main() {

	golog.SetAllLoggers(golog.LogLevel(gologging.DEBUG))

	listenA := flag.String("l", "", "wait for incoming connection")
	listenP := flag.Int("p", 0, "wait for incoming connection")
	dest := flag.String("d", "", "target peer to dial")
	flag.Parse()

	if *listenP == 0 {
		panic("Please provide a port to bind on with -p")
	}

	salt := binary.BigEndian.Uint32(net.ParseIP(*listenA)[12:16])
	h,err := host.MakeBasicHost(int64(*listenP)+int64(salt), *listenA, *listenP)
	if err != nil {
		panic(err)
	}
	fmt.Printf("Run './dht -d /ip4/%v/udp/%v/quic/p2p/%s' on another console.\n", *listenA, *listenP, h.ID().Pretty())
	fmt.Printf("\nWaiting for incoming connection\n\n")

	bootstraps := dht.BootstrapPeers()
	alpha := dht.Concurrency(4)
	beta := dht.Resiliency(2)
	k := dht.BucketSize(5)
	mode := dht.Mode(dht.ModeServer)

	if *dest != "" {
		// Turn the destination into a multiaddr.
		maddr, err := multiaddr.NewMultiaddr(*dest)
		if err != nil {
			panic(err)
		}
		if info, err := peer.AddrInfoFromP2pAddr(maddr); err != nil {
			log.Println(err)
		} else {
			bootstraps = dht.BootstrapPeers(*info)
		}
	}

	kad, err := dht.New(context.Background(), h, bootstraps, alpha, beta, k, mode)
	if err != nil {
		panic(err)
	}
	if err := kad.Bootstrap(context.Background()); err != nil {
		panic(err)
	}

	select {
		case <- time.After(time.Minute*5):
			startWorkload()
	}



}

func startWorkload() {
	populateKeys()
	select {
		case <- time.After(time.Minute*5):
			getKeys()
	}
}

func populateKeys() {
	//TODO implement
	// populate the dht with keys
	// auto generated or from a file
}

func getKeys() {
	//TODO implement
	// get the keys from the dht
	// different access patterns can be specified here
}


