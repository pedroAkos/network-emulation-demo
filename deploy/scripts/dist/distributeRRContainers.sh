#!/bin/bash

function help {
    echo -e "usage: $0 \n\
            <setupScript>  location of the launchContainer.sh \n\
            <dockerImage>  docker image \n\
            <nProc> number of processes to run per container \n\
            <totalProc> number of total processes \n\
            <maxcontainers> max number of containers to launch \n\
            <containerConfig> path to container configfile \n\
            <path/to/log/folder/> path to log folder \n\
            <path/to/emu/config/> path to emulation configurations \n\
            <path/to/config/>  path to common configurations folder \n\
            <path/to/rules/folder/>  path to tc rules folder \n\
            [bandwidth] optional: bandwidth to emulation (default 1000mbits)"
}

setupScript=$(pwd)/$1 #Expected to be launchContainer
image=$2
nProc=$3
totalProc=$4
nContainers=$5
config=$6
logs=$7
emu=$8
conf=$9
rules=${10}
bandwidth=${11}

if [ "$#" -lt 10 ]; then
  help
  exit 1
fi

if [ -z $bandwidth ]; then
  bandwidth=1000
fi

net=$DOCKER_NET

if [ -z $net ]; then
  echo "Docker net is not setup, pls run setup first"
  help
  exit 1
fi

if [ -z $DOCKER_HOSTS ]; then
  echo "Pls set env DOCKER_HOSTS"
  help
  exit 1
fi

n_nodes=$DOCKER_N_HOSTS

function nextnode {
  local idx=$(($1 % n_nodes))
  local i=0
  for host in $DOCKER_HOSTS; do
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
  ssh $n -n "$setupScript $image $name $ip $net $i $nProc $bandwidth $totalProc $logs $conf $emu $rules"
  i=$(($i+1))
  if [ $i -eq $nContainers ]; then
    break
  fi
done < "$config"

wait