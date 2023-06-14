#!/bin/bash

docker network create net1 --subnet=172.19.0.0/16
#docker network create net2 --subnet=172.20.0.0/16
docker network create net3 --subnet=172.21.0.0/16
docker run -u root -dit --name client1 --privileged --net net1 quay.io/mtahhan/cndp-fedora-dev
docker run -u root -dit --name client2 --privileged --net net3 quay.io/mtahhan/cndp-fedora-dev
docker run -dit --name cndp-frr1 --privileged --net net1 quay.io/mtahhan/cndp-fedora-frr
docker run -dit --name cndp-frr2 --privileged --net net3 quay.io/mtahhan/cndp-fedora-frr
#docker network connect net2 cndp-frr1
#docker network connect net2 cndp-frr2


#####################################
# Expose NS
#####################################

echo "expose container cndp-frr1 netns"
NETNS1=`docker inspect -f '{{.State.Pid}}' cndp-frr1`

if [ ! -d /var/run/netns ]; then
    mkdir /var/run/netns
fi
if [ -f /var/run/netns/$NETNS1 ]; then
    rm -rf /var/run/netns/$NETNS1
fi

ln -s /proc/$NETNS1/ns/net /var/run/netns/$NETNS1
echo "done. netns: $NETNS1"

echo "expose container cndp-frr2 netns"
NETNS2=`docker inspect -f '{{.State.Pid}}' cndp-frr2`

if [ ! -d /var/run/netns ]; then
    mkdir /var/run/netns
fi
if [ -f /var/run/netns/$NETNS2 ]; then
    rm -rf /var/run/netns/$NETNS2
fi

ln -s /proc/$NETNS2/ns/net /var/run/netns/$NETNS2
echo "done. netns: $NETNS2"

echo "============================="
echo "current network namespaces: "
echo "============================="
ip netns

###############################################
# Setup phy interfaces
###############################################

ethtool -L eno1 combined 1
ethtool -L eno2 combined 1

echo "Moving phy interfaces to pods"

ip link set eno1 netns $NETNS1
ip link set eno2 netns $NETNS2

ip netns exec $NETNS1 ip addr add 172.20.0.2/16 dev eno1
ip netns exec $NETNS1 ip link set eno1 up

ip netns exec $NETNS2 ip addr add 172.20.0.3/16 dev eno2
ip netns exec $NETNS2 ip link set eno2 up

docker exec client1 route add default gw 172.19.0.3
docker exec client1 route del default gw 172.19.0.1
docker exec client2 route add default gw 172.21.0.3
docker exec client2 route del default gw 172.21.0.1
docker exec cndp-frr1 cp /frr1.cfg /etc/frr/frr.conf
docker exec cndp-frr2 cp /frr2.cfg /etc/frr/frr.conf
docker exec cndp-frr1 cp /my-filter-udp-to-xdp/my_xdp_prog_kern.o /cndp/builddir/examples/cnet-graph/
docker exec cndp-frr2 cp /my-filter-udp-to-xdp/my_xdp_prog_kern.o /cndp/builddir/examples/cnet-graph/

##########################################################
#### Fix for FRR not starting up in a VM #################
### fork(): Cannot allocate memory Failed to start zebra!#
##########################################################
#echo 1 > /proc/sys/vm/overcommit_memory
