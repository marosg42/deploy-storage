# Deploy-storage using MaaS and Juju in one server using virtual machines and containers

Step by step instructions how to deploy ceph or swift testing environment in VMs. All backend disks are emulated on qcow2 devices This setup is great for learning how to work with ceph and swift, but of course it is not performant. Great flexibility because it is very easy to add a node(VM) or disk(qcow2).

Starting point is a fresh unmodified Ubuntu 16.04 install. There are steps provided which will install MaaS and juju and allow to deploy ceph and swift using juju charms in bundles.

HW setup 
- more is better :)
- at least 64 GB memory
- 500 GB disk space, it is quite slow on HDDs, but usable, SSD or NVMe would of course help a lot
- 8+ CPU cores
