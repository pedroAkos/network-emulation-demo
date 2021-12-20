#!/bin/bash

target=$1
tag=$2

docker build -t $tag -f docker/dockerfiles/${target}.dockerfile ..
docker save -o deploy/${target}.tar $tag



