#!/bin/bash

function help {
    echo "usage: $0 <setupScript>  location of the launchContainer.sh \
                    <dockerImage>  docker image \
                    <nProc> number of processes to run per container \
                    <totalProc> number of total processes \
                    <maxcontainers> max number of containers to launch \
                    <containerConfig> path to container configfile \
                    <path/to/log/folder/> path to log folder \
                    <path/to/emu/config/> path to emulation configurations \
                    <path/to/config/>  path to common configurations folder \
                    [bandwidth] optional: bandwidth to emulation (default 1000mbits)"
}

setupScript=$(pwd)/$1 #Expected to be launchContainer
image=$2
nProc=$3
totalProc=$4
nContainers=$5
config=$6
logs=$(pwd)/$7
emu=$(pwd)/$8
conf=$(pwd)/$9
rules=${10}
bandwidth=${11}

if [ "$#" -lt 10 ]; then
  help
  exit
fi

if [ -z $bandwidth ]; then
  bandwidth=1000
fi

net=$DOCKER_NET

if [ -z $net ]; then
  echo "Docker net is not setup, pls run setup first"
  help
  exit
fi

if [ -z $DOCKER_HOSTS ]; then
  echo "Pls set env DOCKER_HOSTS"
  help
  exit
fi

n_nodes=0
for n in $DOCKER_HOST; do
  n_nodes=$((n_nodes +1))
done

function nextnode {
  local idx=$(($1 % n_nodes))
  local i=0
  for host in $DOCKER_HOST; do
    if [ $i -eq $idx ]; then
      echo $host
      break;
    fi
    i=$(($i +1))
  done
}

i=0
while read -r ip name
do
  n=$(nextnode $i)
  eval "$setupScript $image $name $ip $net $i $nProc $bandwidth $totalProc $logs $conf $emu $rules"
  i=$((i+1))
  if [ $i -eq $nContainers ]; then
    break
  fi
done < "$config"

wait