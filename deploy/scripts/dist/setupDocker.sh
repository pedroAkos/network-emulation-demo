#!/bin/bash

function help {
    echo -e "usage: $0 \n\
             <netName> docker network name \n\
             <subnet> docker network subnet \n\
             <hosts> list of hosts separated by white spaces"
}

name=$1 #name to give to the docker network
subnet=$2 #subnet of the network, this should be in tune with your ips config (e.g., 10.10.0.0/16)

if [ "$#" -lt 3 ]; then
  help
  return
fi

shift 2
hosts=$@ #server hostnames that will belong to the docker swarm


## Init docker swarm
docker swarm init
JOIN_TOKEN=$(docker swarm join-token manager -q)

host=$(hostname)
for node in $hosts; do
  ssh $node -n "docker swarm join --token $JOIN_TOKEN $host:2377"
done

hosts="$host $hosts"

docker network create -d overlay --attachable --subnet $subnet $name

n_nodes=0
for n in $hosts; do
  n_nodes=$((n_nodes +1))
done

export DOCKER_NET=$name
export DOCKER_HOSTS=$hosts
export DOCKER_N_HOSTS=$n_nodes