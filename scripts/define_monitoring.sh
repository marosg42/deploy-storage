#!/bin/bash
define() {
# $1 name
# $2 id
# $3 memory
# $4 - $8 unique MAC

set -x

echo $1 $2 $3 $4 $5 $6 $7 $8

sleep 3

CPUOPTS="--cpu host"
GRAPHICS="--graphics vnc --video=cirrus"
CONTROLLER="--controller scsi,model=virtio-scsi,index=0"
DISKOPTS="format=qcow2,bus=scsi,cache=writeback"
export CPUOPTS GRAPHICS CONTROLLER DISKOPTS

qemu-img create -f qcow2 ${1}${2}d1.qcow2 40G

virt-install --noautoconsole --print-xml --boot network,hd,menu=on \
$GRAPHICS $CONTROLLER --name ${1}${2} --ram $3 --vcpus 2 $CPUOPTS \
--disk path=${1}${2}d1.qcow2,size=40,$DISKOPTS \
--network=bridge=maasbr0,mac=${4}:${5}:${6}:${7}:${8}:1${2},model=virtio \
--network=bridge=maasbr1,mac=${4}:${5}:${6}:${7}:${8}:2${2},model=virtio \
> ${1}${2}.xml

virsh define ${1}${2}.xml

set +x

}

for i in $(seq 1 3); do
  define monitoring ${i} 4096 $(date +"%y %m %H %M %S")
done
