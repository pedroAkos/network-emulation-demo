package main

import (
	"bufio"
	"context"
	"encoding/binary"
	"flag"
	"fmt"
	golog "github.com/ipfs/go-log"
	"github.com/libp2p/go-libp2p-core/network"
	"github.com/libp2p/go-libp2p-core/peer"
	"github.com/libp2p/go-libp2p-core/peerstore"
	"github.com/multiformats/go-multiaddr"
	"github.com/pedroAkos/go-lip2p-simple/pkg/host"
	gologging "github.com/whyrusleeping/go-logging"
	"log"
	"net"
	"os"
)

func handleStream(s network.Stream) {
	log.Println("Got a new stream from " + s.Conn().RemoteMultiaddr().String())

	// Create a buffer stream for non blocking read and write.
	rw := bufio.NewReadWriter(bufio.NewReader(s), bufio.NewWriter(s))

	go readData(rw)
	go writeData(rw)

	// stream 's' will stay open until you close it (or the other side closes it).
}
func readData(rw *bufio.ReadWriter) {
	for {
		str, _ := rw.ReadString('\n')

		if str == "" {
			return
		}
		if str != "\n" {
			// Green console colour: 	\x1b[32m
			// Reset console colour: 	\x1b[0m
			fmt.Printf("\x1b[32m%s\x1b[0m> ", str)
		}

	}
}

func writeData(rw *bufio.ReadWriter) {
	stdReader := bufio.NewReader(os.Stdin)

	for {
		fmt.Print("> ")
		sendData, err := stdReader.ReadString('\n')

		if err != nil {
			panic(err)
		}

		rw.WriteString(fmt.Sprintf("%s\n", sendData))
		rw.Flush()
	}

}

func main() {

	golog.SetAllLoggers(golog.LogLevel(gologging.DEBUG))

	listenA := flag.String("l", "", "wait for incoming connection")
	listenP := flag.Int("p", 0, "wait for incoming connection")
	dest := flag.String("d", "", "target peer to dial")
	flag.Parse()

	if *listenP == 0 {
		log.Fatal("Please provide a port to bind on with -p")
	}

	salt := binary.BigEndian.Uint32(net.ParseIP(*listenA)[12:16])
	h,err := host.MakeBasicHost(int64(*listenP)+int64(salt), *listenA, *listenP)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Run './simple -d /ip4/%v/udp/%v/quic/p2p/%s' on another console.\n", *listenA, *listenP, h.ID().Pretty())
	fmt.Printf("\nWaiting for incoming connection\n\n")

	if *dest == "" {
		h.SetStreamHandler("/chat/1.0.0", handleStream)
		select {}
	} else {
		// Turn the destination into a multiaddr.
		maddr, err := multiaddr.NewMultiaddr(*dest)
		if err != nil {
			log.Fatalln(err)
		}
		info, err := peer.AddrInfoFromP2pAddr(maddr)
		h.Peerstore().AddAddrs(info.ID, info.Addrs, peerstore.PermanentAddrTTL)
		s, err := h.NewStream(context.Background(), info.ID, "/chat/1.0.0")
		if err != nil {
			panic(err)
		}

		// Create a buffered stream so that read and writes are non blocking.
		rw := bufio.NewReadWriter(bufio.NewReader(s), bufio.NewWriter(s))

		// Create a thread to read and write data.
		go writeData(rw)
		go readData(rw)

		// Hang forever.
		select {}
	}

}
