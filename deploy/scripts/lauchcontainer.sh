#!/bin/bash

image=$1  #docker image to run
name=$2   #name of the container
ip=$3     #ip of the container
net=$4    #docker network to use
i=$5      #index of the container
nProc=$6  #how many processes will container host/emulate
band=$7   #max network bandwidth of container
tProc=$8  #total number of processes will be run on the exp
###  Mount paths: if absolute path on host, then bind mount, else will create a vol
logs=$9   #path to logs folder
conf=${10}   #path to common config folder
emu=${11}    #path to emulation configuration folder
rules=${12}  #path to emulation rules folder (to be able to reuse rules)

function cmd {
    echo $1
    eval $1
}

cmd "docker run --rm \
    -v /lib/modules:/lib/modules \
    -v ${logs}:/logs \
    -v ${conf}:/config \
    -v ${emu}:/emu \
    -v ${rules}:/rules \
    -d -t --cap-add=NET_ADMIN --net $net --ip $ip --name $name -h $name $image \
    $i $nProc $band $tProc"