# CNDP-FRR

This repo shows how to run a simple example of CNDP working with FRR. Two clients
reside in two different networks are interconnected via simple OSPF vRouters. One
running cndp-frr and the other running vanilla frr.

![CNDP FRR example](./images/cndp-frr-overview.png)

> **_NOTE:_** All container interfaces in this example are vEth interfaces.

This example loads a custom BPF program on the cndp-frr1 vEth interfaces
to filter UDP traffic to CNDP and all other traffic to the kernel. As the
ethtool filtering capability cannot be used with this type of interface.

> **_NOTE:_** CNDP was modified to allow the loading of this custom BPF program.

The flow of traffic is shown in the diagram below:

![CNDP FRR traffic flow](./images/cndp-frr-traffic-flow.png)

## Build cndp-frr image

In the top level directory of this repo run

```bash
make
```

## Setup docker networks and run docker containers

```bash
docker network create net1 --subnet=172.19.0.0/16
docker network create net2 --subnet=172.20.0.0/16
docker network create net3 --subnet=172.21.0.0/16
docker run -u root -dit --hostname client1 --privileged --net net1 quay.io/mtahhan/cndp-fedora-dev
docker run -u root -dit --hostname client2 --privileged --net net3 quay.io/mtahhan/cndp-fedora-dev
docker run -dit --name cndp-frr1 --privileged --net net1 quay.io/mtahhan/cndp-fedora-frr
docker run -dit --name cndp-frr2 --privileged --net net2 quay.io/mtahhan/cndp-fedora-frr
docker network connect net2 cndp-frr1
docker network connect net3 cndp-frr2
docker exec client1 route add default gw 172.19.0.3
docker exec client1 route del default gw 172.19.0.1
docker exec client2 route add default gw 172.21.0.3
docker exec client2 route del default gw 172.21.0.1
```

## check that clients can't ping one another

```bash
docker exec client2 ping 172.19.0.2
```

## start cnet-graph application on cndp-frr1

Connect to the docker container

```bash
docker exec -ti cndp-frr1 bash
```

Navigate to the cnet-graph directory and run the application

```bash
cd /cndp/builddir/examples/cnet-graph/
./cnet-graph -c cnetfwd-graph.jsonc
```

Output should be something like:

```bash
[root@4101efc2cfd2 cnet-graph]# ./cnet-graph -c cnetfwd-graph.jsonc
(xskdev_load_custom_xdp_prog: 861) INFO: Successfully loaded XDP program my_xdp_prog_kern.o with fd 6
(xskdev_load_custom_xdp_prog: 861) INFO: Successfully loaded XDP program my_xdp_prog_kern.o with fd 11

*** cnet-graph, PID: 48 lcore: 5
Graph Name: 'cnet_1', Thread name graph:0
  Patterns: 'ip4*' 'udp*' 'pkt_drop' 'chnl*' 'kernel_recv*'
Type:TUN  - 'krecv0      ' fd 16  Multi-queue: 1 queue
Type:TUN  - 'punt0       ' fd 19  Multi-queue: 1 queue
  Channels: graph:0-chnl
            'udp4:0:198.18.0.2:5678'(app_create_channel      : 169) ERR: chnl_bind() failed

** Version: CNDP 22.04.0, Command Line Interface
```

Check the routing information:

```bash
CNDP-cli:/> route
Route Table for CNET on lcore 5
  Nexthop           Mask               IF  Gateway           Metric Timeout   Netdev
  172.19.0.3        255.255.255.255     0  0.0.0.0               16       0   eth0:0
  172.20.0.3        255.255.255.255     1  0.0.0.0               16       0   eth1:0
  172.19.0.0        255.255.0.0         0  0.0.0.0               16       0   eth0:0
  172.20.0.0        255.255.0.0         1  0.0.0.0               16       0   eth1:0
```

Leave this application running!

## FRR Routing settings

## Running FRR in both cndp-frr containers

Connect to the cndp-frr1 container

```bash
docker exec -ti cndp-frr1 bash
```

Edit /etc/frr/daemons to enable ospf

```bash
# omitted start
bgpd=no
ospfd=yes
ospf6d=no
ripd=no
ripngd=no
# ... omitted the rest
```

Start FRR

``` bash
sysctl -p /etc/sysctl.d/90-routing-sysctl.conf
source logging.sh
source /usr/lib/frr/frrcommon.sh
daemon_list
all_start
all_status
/usr/lib/frr/watchfrr -d $(daemon_list)
```

Repeat the steps above on cndp-frr2

### cndp-frr1 settings

Enable ospf on vtysh.

```bash
# vtysh

Hello, this is FRRouting (version 7.5_git).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

frr1# conf t
frr1(config)# interface lo
frr1(config-if)# ip address 1.1.1.1/32
frr1(config-if)# exit
frr1(config)# router ospf
frr1(config-router)# router-info area 0.0.0.0
frr1(config-router)# network 172.19.0.0/16 area 0.0.0.0
frr1(config-router)# network 172.20.0.0/16 area 0.0.0.0
frr1(config-router)# end
```

```bash
frr1# # show run
Building configuration...

Current configuration:
!
frr version 8.3-dev-MyOwnFRRVersion
frr defaults traditional
hostname 4101efc2cfd2
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config
!
interface lo
 ip address 1.1.1.1/32
exit
!
router ospf
 network 172.19.0.0/16 area 0.0.0.0
 network 172.20.0.0/16 area 0.0.0.0
 router-info area
exit
!
end
```

### cndp-frr2 settings

Set frr2 in the same way

```bash
# vtysh

Hello, this is FRRouting (version 7.5_git).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

frr2# conf t
frr2(config)# interface lo
frr2(config-if)# ip address 2.2.2.2/32
frr2(config-if)# exit
frr2(config)# router ospf
frr2(config-router)# router-info area 0.0.0.0
frr2(config-router)# network 172.20.0.0/16 area 0.0.0.0
frr2(config-router)# network 172.21.0.0/16 area 0.0.0.0
frr2(config-router)# end
```

With the settings up to this point, if you enter frr1 and check the ip route, 172.21.0.0/16 is added in OSPF.

```bash
frr1# show ip route
Codes: K - kernel route, C - connected, S - static, R - RIP,
       O - OSPF, I - IS-IS, B - BGP, E - EIGRP, N - NHRP,
       T - Table, v - VNC, V - VNC-Direct, A - Babel, F - PBR,
       f - OpenFabric,
       > - selected route, * - FIB route, q - queued, r - rejected, b - backup
       t - trapped, o - offload failure

K>* 0.0.0.0/0 [0/0] via 172.19.0.1, eth0, 00:02:13
C>* 1.1.1.1/32 is directly connected, lo, 00:02:13
O   172.19.0.0/16 [110/10] is directly connected, eth0, weight 1, 00:00:47
C>* 172.19.0.0/16 is directly connected, eth0, 00:02:13
O   172.20.0.0/16 [110/10] is directly connected, eth1, weight 1, 00:00:42
C>* 172.20.0.0/16 is directly connected, eth1, 00:02:13
O>* 172.21.0.0/16 [110/20] via 172.20.0.2, eth1, weight 1, 00:00:36
The neighbour is also properly recognised.
```

```bash
frr1# show ip ospf neighbor

Neighbor ID     Pri State           Up Time         Dead Time Address         Interface                        RXmtL RqstL DBsmL
2.2.2.2           1 Full/DR         56.401s           38.597s 172.20.0.2      eth1:172.20.0.3                      0     0     0
```

Check the routes in the cnet-graph application on cndp-frr1

```bash
CNDP-cli:/> ip route
Route Table for CNET on lcore 5
  Nexthop           Mask               IF  Gateway           Metric Timeout   Netdev
  172.19.0.3        255.255.255.255     0  0.0.0.0               16       0   eth0:0
  172.20.0.3        255.255.255.255     1  0.0.0.0               16       0   eth1:0
  172.19.0.0        255.255.0.0         0  0.0.0.0               16       0   eth0:0
  172.20.0.0        255.255.0.0         1  0.0.0.0               16       0   eth1:0
  172.21.0.0        255.255.0.0         1  0.0.0.0               16       0   eth1:0
```

Check connectivity and run iperf between the clients from the host side

```bash
docker exec client2 ping 172.19.0.2
```

```bash
docker exec client1 iperf -s -u
```

```bash
docker exec client2 iperf -c 172.19.0.2 -u
------------------------------------------------------------
Client connecting to 172.19.0.2, UDP port 5001
Sending 1470 byte datagrams, IPG target: 11215.21 us (kalman adjust)
UDP buffer size:  208 KByte (default)
------------------------------------------------------------
[  1] local 172.21.0.2 port 60784 connected with 172.19.0.2 port 5001
[ ID] Interval       Transfer     Bandwidth
[  1] 0.00-10.02 sec  1.25 MBytes  1.05 Mbits/sec
[  1] Sent 896 datagrams
```

## References

[Simple FRR OSPF configuration](https://linuxtut.com/en/648e225d06085a0e2530/)
