#!/bin/bash
docker kill client1 client2 cndp-frr1 cndp-frr2
docker rm client1 client2 cndp-frr1 cndp-frr2
docker network rm net1 net3

rm -rf /var/run/netns/*
