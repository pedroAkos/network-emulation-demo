#!/bin/bash

function help {
    echo -e "usage: $0 \n\
          <containerConfig> path to container configfile \n\
          <maxcontainers> max number of containers to launch \n\
          <executable> path to executable in container"
}

if [ "$#" -lt 2 ]; then
  help
  exit 1
fi

config=$1
nContainers=$2
exec=$3

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

function remotecmd {
    echo "ssh $1 -n '$2'"
    eval ssh $1 -n "$2"
}

function killapp {
  local name=$1
  local node=$(nextnode $2)
  remotecmd $node "docker exec $name pkill $exec"
}

i=0
echo "Killing apps..."
while read -r ip name
do
  killapp $name $i
  i=$((i+1))
  if [ $i -eq $nContainers ]; then
      break
  fi
done < "$config"
