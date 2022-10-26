#!/bin/bash

docker network create net1 --subnet=172.19.0.0/16
docker network create net2 --subnet=172.20.0.0/16
docker network create net3 --subnet=172.21.0.0/16
docker run -u root -dit --name client1 --privileged --net net1 quay.io/mtahhan/cndp-fedora-dev
docker run -u root -dit --name client2 --privileged --net net3 quay.io/mtahhan/cndp-fedora-dev
docker run -dit --name cndp-frr1 --privileged --net net1 quay.io/mtahhan/cndp-fedora-frr
docker run -dit --name cndp-frr2 --privileged --net net2 quay.io/mtahhan/cndp-fedora-frr
docker network connect net2 cndp-frr1
docker network connect net3 cndp-frr2
docker exec client1 route add default gw 172.19.0.3
docker exec client1 route del default gw 172.19.0.1
docker exec client2 route add default gw 172.21.0.3
docker exec client2 route del default gw 172.21.0.1
docker exec cndp-frr1 cp /frr1.cfg /etc/frr/frr.conf
docker exec cndp-frr2 cp /frr2.cfg /etc/frr/frr.conf
docker exec cndp-frr1 cp /my-filter-udp-to-xdp/my_xdp_prog_kern.o /cndp/builddir/examples/cnet-graph/
docker exec cndp-frr2 cp /my-filter-udp-to-xdp/my_xdp_prog_kern.o /cndp/builddir/examples/cnet-graph/
