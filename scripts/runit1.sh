#!/bin/bash

LOG=logfile

set -xe

lxc profile create maas >> $LOG 2>&1

cat <<EOF | lxc profile edit maas  >> $LOG 2>&1
config:
  boot.autostart: "1"
  security.nesting: "true"
  security.privileged: "true"
description: maas
devices:
  eth0:
    ipv4.address: 192.168.110.2
    name: eth0
    nictype: bridged
    parent: maasbr0
    type: nic
  eth1:
    ipv4.address: 192.168.111.2
    name: eth1
    nictype: bridged
    parent: maasbr1
    type: nic
  eth2:
    ipv4.address: 192.168.112.2
    name: eth2
    nictype: bridged
    parent: maasbr2
    type: nic
  eth3:
    ipv4.address: 192.168.113.2
    name: eth3
    nictype: bridged
    parent: maasbr3
    type: nic
  eth4:
    ipv4.address: 192.168.100.2
    name: eth4
    nictype: bridged
    parent: lxdbr0
    type: nic
  loop0:
    path: /dev/loop0
    type: unix-block
  loop1:
    path: /dev/loop1
    type: unix-block
  loop2:
    path: /dev/loop2
    type: unix-block
  loop3:
    path: /dev/loop3
    type: unix-block
  loop4:
    path: /dev/loop4
    type: unix-block
  loop5:
    path: /dev/loop5
    type: unix-block
  loop6:
    path: /dev/loop6
    type: unix-block
  loop7:
    path: /dev/loop7
    type: unix-block
  root:
    path: /
    pool: default
    type: disk
name: maas
used_by: []
EOF



sudo brctl addbr maasbr0 >> $LOG 2>&1
sudo brctl addbr maasbr1 >> $LOG 2>&1
sudo brctl addbr maasbr2 >> $LOG 2>&1
sudo brctl addbr maasbr3 >> $LOG 2>&1

bash -c "printf \"auto maasbr0\niface maasbr0 inet static\n    address 192.168.110.1/24 \n    bridge_stp off \n\""|sudo tee /etc/network/interfaces.d/mg.cfg >> $LOG 2>&1
bash -c "printf \"auto maasbr1\niface maasbr1 inet static\n    address 192.168.111.1/24 \n    bridge_stp off \n\""|sudo tee -a /etc/network/interfaces.d/mg.cfg >> $LOG 2>&1
bash -c "printf \"auto maasbr2\niface maasbr2 inet static\n    address 192.168.112.1/24 \n    bridge_stp off \n\""|sudo tee -a /etc/network/interfaces.d/mg.cfg >> $LOG 2>&1
bash -c "printf \"auto maasbr3\niface maasbr3 inet static\n    address 192.168.113.1/24 \n    bridge_stp off \n\""|sudo tee -a /etc/network/interfaces.d/mg.cfg >> $LOG 2>&1

set +e
sudo /etc/init.d/networking restart >> $LOG 2>&1
set -e

sudo iptables -t nat -A POSTROUTING -s 192.168.110.0/24 ! -d 192.168.110.0/24 -m comment --comment "network maasbr0" -j MASQUERADE >> $LOG 2>&1
sudo iptables -t filter -A INPUT -i maasbr0 -p tcp -m tcp --dport 53 -m comment --comment "network maasbr0" -j ACCEPT >> $LOG 2>&1
sudo iptables -t filter -A INPUT -i maasbr0 -p udp -m udp --dport 53 -m comment --comment "network maasbr0" -j ACCEPT >> $LOG 2>&1
sudo iptables -t filter -A FORWARD -o maasbr0 -m comment --comment "network maasbr0" -j ACCEPT >> $LOG 2>&1
sudo iptables -t filter -A FORWARD -i maasbr0 -m comment --comment "network maasbr0" -j ACCEPT >> $LOG 2>&1

lxc config set core.proxy_http http://100.107.0.4:1080 >> $LOG 2>&1
lxc config set core.proxy_https http://100.107.0.4:1080 >> $LOG 2>&1

lxc launch ubuntu: --profile maas maas >> $LOG 2>&1

sleep 5

lxc exec maas -- bash -c "echo \"network: {config: disabled}\"| sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg" >> $LOG 2>&1

lxc exec maas -- bash -c "echo \"network:
  version: 2
  renderer: networkd
  ethernets:
    eth4:
      dhcp4: yes
      dhcp6: False
    eth0:
      dhcp4: False
      dhcp6: False
      addresses: [192.168.110.2/24]
    eth1:
      dhcp4: False
      dhcp6: False
      addresses: [192.168.111.2/24]
    eth2:
      dhcp4: False
      dhcp6: False
      addresses: [192.168.112.2/24]
    eth3:
      dhcp4: False
      dhcp6: False
      addresses: [192.168.113.2/24]
\"|sudo tee /etc/netplan/mg.yaml" >> $LOG 2>&1

lxc exec maas -- netplan apply >> $LOG 2>&1
lxc exec maas -- bash -c "echo \"
http_proxy=\"http://100.107.0.4:1080\"
https_proxy=\"http://100.107.0.4:1080\"
\" | sudo tee -a /etc/environment" >> $LOG 2>&1

lxc exec maas -- bash -c "export http_proxy=http://100.107.0.4:1080;  apt update && apt upgrade -y && apt install maas libvirt-bin -y; virsh net-destroy default;virsh net-undefine default" >> $LOG 2>&1
sleep 10
lxc exec maas -- maas createadmin --username=admin --email=m@m.com --password=admin  >> $LOG 2>&1
sleep 5
lxc exec maas -- bash -c "maas login maas-root http://localhost:5240/MAAS/api/2.0 \$(maas-region apikey --username=admin)" >> $LOG 2>&1
lxc exec maas -- maas maas-root maas set-config name=http_proxy value=http://100.107.0.4:1080 >> $LOG 2>&1
lxc exec maas -- maas maas-root maas set-config name=enable_http_proxy value=true >> $LOG 2>&1
lxc exec maas -- maas maas-root sshkeys import lp:marosg  >> $LOG 2>&1
lxc exec maas -- maas maas-root maas set-config name=completed_intro value=true >> $LOG 2>&1
lxc exec maas -- maas maas-root boot-source-selections create 1 os="ubuntu" release="xenial" arches="amd64" subarches="*" labels="*" >> $LOG 2>&1
lxc exec maas -- maas maas-root boot-resources import >> $LOG 2>&1
controller=$(lxc exec maas -- bash -c "maas maas-root  rack-controllers read|grep system_id|cut -d \\\" -f 4|head -n 1") >> $LOG 2>&1
lxc exec maas -- bash -c "rc=1;while  [ \$rc -ne 0 ] ; do  sleep 10;  maas maas-root rack-controller list-boot-images $controller |grep status |grep synced ; rc=\$?; done" >> $LOG 2>&1
lxc exec maas -- maas maas-root  maas set-config name=default_distro_series value=xenial >> $LOG 2>&1
lxc exec maas -- maas maas-root  maas set-config name=commissioning_distro_series value=xenial >> $LOG 2>&1
lxc exec maas -- maas maas-root subnet update 192.168.110.0/24 gateway_ip=192.168.110.1 >> $LOG 2>&1
fabric=$(lxc exec maas -- maas maas-root  subnet read 192.168.110.0/24|grep fabric|grep -v id|sed "s/\",//"|sed "s/.*\"//") >> $LOG 2>&1
lxc exec maas -- maas maas-root ipranges create type=dynamic start_ip=192.168.110.20 end_ip=192.168.110.99 >> $LOG 2>&1
lxc exec maas -- maas maas-root ipranges create type=reserved start_ip=192.168.110.10 end_ip=192.168.110.19 >> $LOG 2>&1
lxc exec maas -- maas maas-root vlan update ${fabric} untagged dhcp_on=true primary_rack=maas >> $LOG 2>&1
lxc exec maas -- sudo -u maas sh -c "printf 'y\n'|ssh-keygen -t rsa -f /var/lib/maas/.ssh/id_rsa -P \"\"" >> $LOG 2>&1
lxc exec maas -- sudo -u maas sh -c "cat /var/lib/maas/.ssh/id_rsa.pub" >> $LOG 2>&1

echo  $(lxc exec maas -- sudo -u maas sh -c "cat /var/lib/maas/.ssh/id_rsa.pub") >> ~ubuntu/.ssh/authorized_keys 2>>$LOG
lxc exec maas -- sudo -u maas sh -c "printf 'yes\n'|ssh -o StrictHostKeyChecking=no ubuntu@192.168.110.1 hostname" >> $LOG 2>&1
sudo snap install juju --classic >> $LOG 2>&1

sleep 5

echo "
clouds:
  maas-kvm:
    type: maas
    auth-types: [oauth1]
    endpoint: http://192.168.100.2:5240/MAAS/api/2.0
" > maas-kvm.yaml 2>>$LOG

juju add-cloud maas-kvm maas-kvm.yaml >> $LOG 2>&1

echo "
credentials:
  maas-kvm:
    admin:
      auth-type: oauth1
      maas-oauth: $(lxc exec maas -- maas-region apikey --username=admin)
" > cred.yaml 2>>$LOG

juju add-credential maas-kvm -f cred.yaml --replace >> $LOG 2>&1

sg libvirtd -c deploy-storage/scripts/define_juju.sh >> $LOG 2>&1

lxc exec maas -- maas maas-root machines add-chassis chassis_type=virsh hostname=qemu+ssh://ubuntu@192.168.100.1/system prefix_filter="juju-" >> $LOG 2>&1
lxc exec maas -- maas maas-root tags create name=juju >> $LOG 2>&1
lxc exec maas -- maas maas-root machines accept-all >> $LOG 2>&1
lxc exec maas -- bash -c "rc=1;while  [ \$rc -ne 0 ] ; do  sleep 10;  maas maas-root machines read| grep status_name|grep -v _status_name | grep Ready;rc=\$?; done" >> $LOG 2>&1
machine=$(lxc exec maas -- bash -c "maas maas-root machines read hostname=juju-1|grep system_id|cut -d \\\" -f 4|head -n 1") >> $LOG 2>&1
lxc exec maas -- maas maas-root tag update-nodes juju add=${machine} >> $LOG 2>&1
export no_proxy=${no_proxy},$(echo 192.168.110.{1..255} | sed 's/ /,/g'),192.168.100.2 >> $LOG 2>&1
juju bootstrap maas-kvm juju-kvm --config http-proxy="http://100.107.0.4:1080" --config https-proxy="http://100.107.0.4:1080" --config no-proxy=192.168.100.2,$(echo 192.168.110.{1..255} | sed 's/ /,/g') --bootstrap-series=bionic --bootstrap-constraints "tags=juju" >> $LOG 2>&1

sg libvirtd -c deploy-storage/scripts/define_machines.sh >> $LOG 2>&1

lxc exec maas -- maas maas-root tags create name=ceph >> $LOG 2>&1
lxc exec maas -- maas maas-root tags create name=swift >> $LOG 2>&1
lxc exec maas -- maas maas-root machines add-chassis chassis_type=virsh hostname=qemu+ssh://ubuntu@192.168.100.1/system prefix_filter="ceph" >> $LOG 2>&1
lxc exec maas -- maas maas-root machines add-chassis chassis_type=virsh hostname=qemu+ssh://ubuntu@192.168.100.1/system prefix_filter="swift" >> $LOG 2>&1
set +x
machines=$(for i in $(seq 1 9); do lxc exec maas -- bash -c "maas maas-root machines read hostname=ceph${i}|grep system_id|cut -d \\\" -f 4|head -n 1"; done) >> $LOG 2>&1
machines=$(for i in $(seq 1 9); do lxc exec maas -- bash -c "maas maas-root machines read hostname=swift${i}|grep system_id|cut -d \\\" -f 4|head -n 1"; done) >> $LOG 2>&1
set -x
for i in $machines; do lxc exec maas -- maas maas-root tag update-nodes ceph add=${i}; done >> $LOG 2>&1
for i in $machines; do lxc exec maas -- maas maas-root tag update-nodes swift add=${i}; done >> $LOG 2>&1

# commision all
lxc exec maas -- maas maas-root machines accept-all >> $LOG 2>&1
lxc exec maas -- bash -c "rc=0;while  [ \$rc -eq 0 ] ; do  sleep 30; maas maas-root machines read| grep status_name | grep -v _status_name | grep -v \"Deployed\|Ready\"; rc=\$?;echo;done " >> $LOG 2>&1

sleep 10

juju deploy deploy-storage/bundles/xenial-ceph.yaml >> $LOG 2>&1
juju deploy deploy-storage/bundles/xenial-swift.yaml >> $LOG 2>&1

set +x
watch -c -- juju status --color
