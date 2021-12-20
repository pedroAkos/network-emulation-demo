package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/binary"
	"flag"
	"fmt"
	golog "github.com/ipfs/go-log"
	host2 "github.com/libp2p/go-libp2p-core/host"
	"github.com/libp2p/go-libp2p-core/network"
	"github.com/libp2p/go-libp2p-core/peer"
	"github.com/libp2p/go-libp2p-core/peerstore"
	"github.com/multiformats/go-multiaddr"
	"github.com/pedroAkos/go-lip2p-simple/pkg/host"
	gologging "github.com/whyrusleeping/go-logging"
	"log"
	"math/rand"
	"net"
	"time"
)




type msg struct {
	maddrs []multiaddr.Multiaddr
}

func (m msg) String() string {
	return fmt.Sprintf("msg{%v}", m.maddrs)
}

func (m msg) serialize() []byte {
	b := new(bytes.Buffer)
	size := int8(len(m.maddrs))
	_ = binary.Write(b, binary.BigEndian, size)
	for _, maddr := range m.maddrs {
		maddrbytes := maddr.Bytes()
		maddrSize := int16(len(maddrbytes))
		_  = binary.Write(b, binary.BigEndian, maddrSize)
		b.Write(maddrbytes)
	}
	return b.Bytes()
}

func (m msg) deserialize(b []byte) msg {
	buff := bytes.NewBuffer(b)
	var err error
	var size int8
	_ = binary.Read(buff, binary.BigEndian, &size)
	m.maddrs = make([]multiaddr.Multiaddr, size)
	for i := 0; i < int(size); i ++ {
		var maddrSize int16
		_  = binary.Read(buff, binary.BigEndian, &maddrSize)
		maddrbytes := make([]byte, maddrSize)
		_,_ = buff.Read(maddrbytes)
		if m.maddrs[i], err = multiaddr.NewMultiaddrBytes(maddrbytes); err != nil {
			panic(err)
		}

	}
	return m
}

var emptyMsg = msg{}


type pinger struct {
	h host2.Host
	encodedId string
	msgCh chan msg
	peers map[string]multiaddr.Multiaddr
}

func (p * pinger) handlePingerStream(s network.Stream) {
	log.Println(fmt.Sprintf("Handling stream from %v with addr %v", s.Conn().RemotePeer(), s.Conn().RemoteMultiaddr()))
	closeStream := func() {
		if err := s.Close(); err != nil {
			log.Print(err)
		}
	}
	defer closeStream()
	r := bufio.NewReader(s); w := bufio.NewWriter(s)

	var mgsz int16
	err := binary.Read(r, binary.BigEndian, &mgsz)
	if err != nil {
		log.Println(err)
		return
	}
	log.Println("To read: ", mgsz)
	b := make([]byte,mgsz)
	n, err := r.Read(b)
	if err != nil {
		log.Println(err)
		return
	} else {
		log.Println("MessageRead: ", n)
	}
	if n, err := w.Write([]byte{1}); err != nil {
		log.Println(err)
		return
	} else {
		log.Println("Wrote: ", n)
	}
	if err := w.Flush(); err != nil {
		log.Println(err)
		return
	}
	m := emptyMsg.deserialize(b[:n])
	id, _ := multiaddr.NewMultiaddr(fmt.Sprintf("/p2p/%v", s.Conn().RemotePeer().Pretty()))
	p.addToPeerStore(s.Conn().RemoteMultiaddr().Encapsulate(id))
	p.msgCh <- m

}

func (p *pinger) handleMsg(m msg) {
	log.Println(fmt.Sprintf("Handling message %v",m))
	for _, addr := range m.maddrs {
		p.addToPeerStore(addr)
	}
}

func (p *pinger) sendMsg(m msg, id peer.ID) {
	s, err := p.h.NewStream(context.Background(), id, "/pinger/1.0.0")
	closeStream := func() {
		if s != nil {
			if err := s.Close(); err != nil {
				log.Print(err)
			}
		}
	}
	defer closeStream()
	b := make([]byte, 1)
	if err != nil {
		log.Println(err)
		return
	}

	log.Println(fmt.Sprintf("Opened stream to %v with addr %v", id, p.h.Peerstore().PeerInfo(id).Addrs[0].String()))
	log.Println(fmt.Sprintf("Sending message %v",m))
	w := bufio.NewWriter(s);  r := bufio.NewReader(s)
	mbytes := m.serialize()
	log.Println("To write: ", len(mbytes))
	start := time.Now()
	err = binary.Write(w, binary.BigEndian, int16(len(mbytes)))
	if err != nil {
		log.Println(err)
		return
	}
	if n, err := w.Write(mbytes); err != nil {
		log.Print(err)
		return
	} else {
		log.Println("MessageWritten: ", n)
	}
	if err := w.Flush(); err != nil {
		log.Println(err)
		return
	}

	if n, err := r.Read(b); err != nil {
		log.Print(err)
		return
	} else {
		log.Println("Read: ", n)
	}
	end := time.Now()
	log.Println(fmt.Sprintf("RTT: %v", end.Sub(start)))
}

func (p *pinger) chooseTarget() peer.ID {
	idx := rand.Perm(len(p.peers))
	if len(idx) > 0 {
		i := idx[0]
		for k, _ := range p.peers {
			if i == 0 {
				pid, _ := peer.Decode(k)
				return pid
			}
			i--
		}
	}
	return ""
}

func (p *pinger) genMessage() msg {
	perm := rand.Perm(len(p.peers))
	m := msg{maddrs: make([]multiaddr.Multiaddr, 0, 5)}
	i := 0; j := 0
	for k, v := range  p.peers {
		if len(m.maddrs) == cap(m.maddrs) {
			break
		}
		idx := perm[j]
		if i == idx  {
			pid, err := multiaddr.NewMultiaddr(fmt.Sprintf("/p2p/%v", k))
			if err != nil {
				panic(err)
			}
			log.Println("Peer to add: ", k)
			m.maddrs = append(m.maddrs,v.Encapsulate(pid))
			j++
		}
		i++
	}
	return m
}

func (p * pinger) addToPeerStore(maddr multiaddr.Multiaddr) {
	if info, err := peer.AddrInfoFromP2pAddr(maddr); err != nil {
		log.Println(err)
	} else {
		sid := peer.Encode(info.ID)
		if _, ok := p.peers[sid]; !ok && sid != p.encodedId {
			log.Println(fmt.Sprintf("Adding %v to peerstore", maddr))
			p.peers[sid] = info.Addrs[0]
			p.h.Peerstore().AddAddrs(info.ID, info.Addrs, peerstore.PermanentAddrTTL)
		}
	}
}

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
	fmt.Printf("Run './pinger -d /ip4/%v/udp/%v/quic/p2p/%s' on another console.\n", *listenA, *listenP, h.ID().Pretty())
	fmt.Printf("\nWaiting for incoming connection\n\n")

	p := pinger{h: h, encodedId: peer.Encode(h.ID()), msgCh: make(chan msg), peers: make(map[string]multiaddr.Multiaddr)}

	h.SetStreamHandler("/pinger/1.0.0", p.handlePingerStream)
	if *dest != "" {
		// Turn the destination into a multiaddr.
		maddr, err := multiaddr.NewMultiaddr(*dest)
		if err != nil {
			panic(err)
		}
		p.addToPeerStore(maddr)
		p.sendMsg(p.genMessage(), p.chooseTarget())

	}

	timer := time.Tick(time.Second*5)
	for {
		select {
		case m := <-p.msgCh:
			p.handleMsg(m)
		case <- timer:
			if len(p.h.Peerstore().Peers()) > 1 {
				if id := p.chooseTarget(); id != "" {
					m := p.genMessage()
					p.sendMsg(m, id)
				}
			}
		}
	}

}
