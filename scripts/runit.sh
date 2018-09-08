#!/bin/bash

LOG=logfile

set -xe

cat <<EOF | sudo tee -a /etc/environment > $LOG 2>&1
http_proxy="http://100.107.0.4:1080"
https_proxy="http://100.107.0.4:1080"
EOF

sudo systemctl restart snapd >> $LOG 2>&1
sudo apt update >> $LOG 2>&1
sudo apt install libvirt-bin qemu-kvm virtinst -y >> $LOG 2>&1
sudo systemctl restart libvirt-bin >> $LOG 2>&1
sudo apt remove lxd lxd-client --purge -y >> $LOG 2>&1
sudo snap install lxd >> $LOG 2>&1
sleep 10

cat <<EOF | sudo lxd init --preseed >> $LOG 2>&1
config: {}
networks:
 - config:
     ipv4.address: 192.168.100.1/24
     ipv4.nat: "true"
     ipv6.address: none
   description: ""
   managed: false
   name: lxdbr0
   type: ""
storage_pools:
 - config:
     size: 100GB
   description: ""
   name: default
   driver: zfs
profiles:
 - config: {}
   description: ""
   devices:
     eth0:
       name: eth0
       nictype: bridged
       parent: lxdbr0
       type: nic
     root:
       path: /
       pool: default
       type: disk
   name: default
cluster: null
EOF

sleep 10

sudo adduser ubuntu lxd >> $LOG 2>&1

sg lxd -c "deploy-storage/scripts/runit1.sh"

