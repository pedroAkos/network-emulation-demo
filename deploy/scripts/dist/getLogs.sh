#!/bin/bash

function help {
    echo -e "usage: $0 \n\
            <logs> path to logs mount point \n\
            <tostore> path to store logs"
}

if [ "$#" -lt 2 ]; then
  help
  exit 1
fi

logs=$1
tostore=$2

if [ "$#" -lt 2 ]; then
  help
  exit
fi

function remotecmd {
    echo "ssh $1 -n '$2'"
    eval ssh $1 -n "$2"
}

for n in $DOCKER_HOSTS
do
  remotecmd $n "docker run --rm -dt -v ${logs}:/logs --name copier alpine"
  remotecmd $n "docker cp copier:logs $tostore"
  remotecmd $n "docker kill copier"
done
