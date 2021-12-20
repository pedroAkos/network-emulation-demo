#!/bin/bash

function help {
    echo -e "usage: $0 \n\
          <containerConfig> path to container configfile \n\
          <nProc> number of processes to run per container \n\
          <maxcontainers> max number of containers to launch \n\
          <executable> path to executable in container \n\
          <bootstrapArg> bootstrap argument to pass \n\
          [args] remaining arguments of executable"
}

config=$1
nProc=$2
nContainers=$3
exec=$4
bootstrap=$5

if [ "$#" -lt 4 ]; then
  help
  exit 1
fi

shift 4

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

i=0
echo "Lauching apps..."
while read -r ip name
do
  node=$(nextnode $i)
  for n in $(seq 0 $((nProc-1))); do
    if [ $i -eq 0 ] && [ $n -eq 0 ]
    then
      remotecmd $node "docker exec -d $name ./start.sh $exec $ip $n $@"
    else
      remotecmd $node "docker exec -d $name ./start.sh $exec $ip $n $bootstrap $@"
    fi
    sleep 1
  done
  i=$(($i +1))
  if [ $i -eq $nContainers ]; then
      break
    fi
done < "$config"
