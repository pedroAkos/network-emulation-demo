package host

import (
	"crypto/rand"
	"fmt"
	"github.com/libp2p/go-libp2p"
	"github.com/libp2p/go-libp2p-core/crypto"
	"github.com/libp2p/go-libp2p-core/host"
	quic "github.com/libp2p/go-libp2p-quic-transport"
	"github.com/multiformats/go-multiaddr"
	"io"
	mrand "math/rand"
)

func MakeBasicHost(seed int64, listenAddr string, listenPort int) (host.Host, error) {
	var r io.Reader
	if seed == 0 {
		r = rand.Reader
	} else {
		r = mrand.New(mrand.NewSource(seed))
	}

	priv, _, err := crypto.GenerateKeyPairWithReader(crypto.ECDSA, 2048, r)
	if err != nil {
		return nil, err
	}

	madrr, err := multiaddr.NewMultiaddr(fmt.Sprintf("/ip4/%s/udp/%d/quic", listenAddr, listenPort))
	if err != nil {
		return nil, err
	}

	host, err := libp2p.New(
		libp2p.Identity(priv), //the key to provide the nodes identity
		libp2p.Transport(quic.NewTransport), //we want to use QUIC
		//libp2p.ListenAddrStrings(fmt.Sprintf("/ipv4/%s/udp/%d/quic", listenAddr, listenPort)), //we are going to listen here for incoming connections
		libp2p.ListenAddrs(madrr), //we are going to listen here for incoming connections
	)
	if err != nil {
		return nil, err
	}

	return host, nil
}
