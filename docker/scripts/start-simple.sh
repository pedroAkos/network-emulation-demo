#!/bin/bash

exec=$1
ip=$2
i=$3
shift 3

port=$((10000 + $i))
host=$(hostname)

$exec -l $ip -p $port $@ &> logs/${host}-${port}.log &
