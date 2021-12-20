#!/bin/bash


exec 1> /tmp/setupTc.$(hostname).log
exec 2>&1
set -x

idx=$1
nProc=$2
bandwith=$3
totalProc=$4

latencyMap="emu/classMat.txt"
ipsMap="emu/ips.txt"
classesF="emu/classes.txt"
rulesDir="rules"
host=$(hostname)
hostdir="${rulesDir}/${host}"
procdir="${rulesDir}/${host}/proc"

iplinks="${hostdir}/iplinks"
qdiscs="${hostdir}/qdiscs"

if [ -d $rulesDir ]; then
  :
else
  mkdir $rulesDir
fi

if [ -d $hostdir ]; then
  :
else
  mkdir $hostdir
fi


if [ -d $procdir ]; then
  :
else
  mkdir $procdir
fi



ifbs=$(cat $classesF | wc -l)
ifbs=$((ifbs +1))

off=$((idx * nProc))

if [ -z $bandwith ]; then
  bandwith=1000
fi

declare -a ips

i=0
while read -r ip port
do
  if [ -z "$totalProc" ]; then
    :
  else
    if [ $i -eq $totalProc ]; then
      break
    fi
  fi

  ips[$i]="${ip}:${port}"
  i=$((i +1))
done < "$ipsMap"


function cmd {
  echo "$1"
  eval $1
}

function append {
  echo "$1" >> $2
}

function setIfb {
  local id=$1
  local class=$2
  append "link add ifb${id} type ifb" $iplinks
  append "link set dev ifb${id} up" $iplinks
  append "qdisc add dev ifb${id} root netem delay ${class}ms" $qdiscs
}

function setupIpTc {
   local j=0
   local sourceIp=$1
   local sourcePort=$2
   local hii=$3
   local batchFile=$4
   if [ -f "$batchFile" ]; then
          return
   fi
   for n in $5
    do
      if [ $j -eq $totalProc ]; then
        break
      fi

      if [ $n -eq 0 ]; then
        local j=$((j +1))
        continue
      fi

      local target=${ips[$j]}
      local targetIp=$(echo $target | cut -d':' -f1 |tr -d '\r')
      local targetPort=$(echo $target | cut -d':' -f2 |tr -d '\r')

      if [ $targetIp = $sourceIp ]; then
          append "filter add dev lo protocol ip parent 1: prio 5 u32 \
          ht 2: sample ip sport ${sourcePort} 0x000f \
          match ip dport ${targetPort} 0xffff \
          flowid 1:${hii} \
          action mirred egress redirect dev ifb${n}" $batchFile
      else
            append "filter add dev eth0 protocol ip parent 1: prio 5 u32 \
            ht 2: sample ip sport ${sourcePort} 0x000f \
            match ip dst ${targetIp} \
            match ip dport ${targetPort} 0xffff \
            flowid 1:${hii} \
            action mirred egress redirect dev ifb${n}" $batchFile
      fi

      local j=$((j +1))
    done
}

function setuptc {

  Inbandwith=$((bandwith*2))
  cmd "modprobe ifb numifbs=${ifbs}"

  cmd "ip link add ifb0 type ifb"
  cmd "ip link set dev ifb0 up"
  cmd "tc qdisc add dev ifb0 root handle 1: htb default 1"
  cmd "tc class add dev ifb0 parent 1: classid 1:1 htb rate ${Inbandwith}mbit"

  #ingress eth0
  cmd "tc qdisc add dev eth0 handle ffff: ingress"
  cmd "tc filter add dev eth0 parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ifb0"

  #ingress lo
  cmd "tc qdisc add dev lo handle ffff: ingress"
  cmd "tc filter add dev lo parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev ifb0"


  #egress eth0 + default
  cmd "tc qdisc add dev eth0 root handle 1: htb default 1"
  cmd "tc class add dev eth0 parent 1: classid 1:1 htb rate ${bandwith}mbit"

  #root filter on eth0
  cmd "tc filter add dev eth0 parent 1: prio 5 protocol ip u32"
  cmd "tc filter add dev eth0 parent 1: prio 5 handle 2: protocol ip u32 divisor 256"

  #egress lo + default
  cmd "tc qdisc add dev lo root handle 1: htb default 1"
  cmd "tc class add dev lo parent 1: classid 1:1 htb rate ${bandwith}mbit"

  #root filter on lo
  cmd "tc filter add dev lo parent 1: prio 5 protocol ip u32"
  cmd "tc filter add dev lo parent 1: prio 5 handle 2: protocol ip u32 divisor 256"


  #ifb netem classes
  local id=1

  if [ -f $iplinks ] && [ -f $qdiscs ]; then
    :
  else
    while read -r class
    do
      setIfb $id $class
      local id=$((id +1))
    done < "$classesF"
  fi

  
  #wait

  local i=0
  #for each line
  for l in "$@"
  do
    # source -> dests
    local hii=$(printf "%X1" $((i +1)))
    local sourceIdx=$((off +i))
    local source=${ips[$sourceIdx]}
    local sourceIp=$(echo $source | cut -d':' -f1 |tr -d '\r')
    local sourcePort=$(echo $source | cut -d':' -f2 |tr -d '\r')

    #class for source port lo
    cmd "tc class add dev lo parent 1: classid 1:${hii} htb rate ${bandwith}mbit"

    cmd "tc filter add dev lo parent 1: prio 5 protocol ip u32 ht 800:: \
          match ip sport ${sourcePort} 0xffff \
          hashkey mask 0x000f0000 at 20 \
          link 2:"

    #class for source port eth0
    cmd "tc class add dev eth0 parent 1: classid 1:${hii} htb rate ${bandwith}mbit"

    cmd "tc filter add dev eth0 parent 1: prio 5 protocol ip u32 ht 800:: \
          match ip sport ${sourcePort} 0xffff \
          hashkey mask 0x000f0000 at 20 \
          link 2:"

    echo "off=$off sourceIdx=$sourceIdx idx=$idx nProc=$nProc sourceIp=$sourceIp sourcePort=$sourcePort hii=$hii"
    setupIpTc $sourceIp $sourcePort $hii "${procdir}/${sourcePort}.rules" "$l" &

    local i=$((i +1))
  done
  wait


  cmd "ip -batch $iplinks"
  cmd "tc -batch $qdiscs"

  local i=0
  for l in "$@"
  do
    # source -> dests
    sourceIdx=$((off +i))
    source=${ips[$sourceIdx]}
    sourceIp=$(echo $source | cut -d':' -f1 |tr -d '\r')
    sourcePort=$(echo $source | cut -d':' -f2 |tr -d '\r')
    batchFile="${procdir}/${sourcePort}.rules"
    cmd "tc -batch $batchFile"

    local i=$((i +1))
  done
}


echo "Setting up tc emulated network..."
i=0
j=0
add=0
exec=0
declare -a array
while read -r line
do
  if [ $off -eq $i ]; then
    add=1
  fi
  if [ $add -eq 1 ]; then
    array[$j]=$line
    j=$((j +1))
  fi
  if [ $j -eq $nProc ]; then
    j=0
    add=0
    exec=1
  fi
  if [ $exec -eq 1 ]; then
    setuptc "${array[@]}"
    break
  fi
  i=$((i+1))
done < "$latencyMap"

echo "Done."

/bin/bash

