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

If you wish to build the CNDP-FRR docker images locally then in the top level directory of this repo run:

```bash
make
```

## Setup docker networks and run docker containers

```bash
# ./scripts/setupdemo.sh
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
cd /cndp/builddir/examples/cnet-graph/;./cnet-graph -c cnetfwd-graph.jsonc
```

Output should be something like:
=======

*** CNET-GRAPH Application, Mode: Drop, Burst Size: 128

*** cnet-graph, PID: 57 lcore: 1

** Version: CNDP 22.08.0, Command Line Interface
CNDP-cli:/> route
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

### Running FRR in both cndp-frr containers

Connect to the cndp-frr1 container

```bash
docker exec -ti cndp-frr1 bash
```

Start FRR

``` bash
source startup.sh
```

Repeat the steps above on cndp-frr2

### cndp-frr1 settings

Check configuration with vtysh.

```bash
# vtysh

Hello, this is FRRouting (version 7.5_git).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

frr1# show run
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

Setup frr2 in the same way

```bash
# vtysh

Hello, this is FRRouting (version 7.5_git).
Copyright 1996-2005 Kunihiro Ishiguro, et al.

frr1# show run

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
