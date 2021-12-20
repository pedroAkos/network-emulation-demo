#!/bin/bash

name=$1 #name to give to the docker network
subnet=$2 #subnet of the network, this should be in tune with your ips config (e.g., 10.10.0.0/16)

docker network create --attachable --subnet $subnet $name