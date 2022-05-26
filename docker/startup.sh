#!/bin/bash

sysctl -p /etc/sysctl.d/90-routing-sysctl.conf
source logging.sh
source /usr/lib/frr/frrcommon.sh