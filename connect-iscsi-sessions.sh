#!/bin/bash

# Check if both parameters are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <cnode_dataport_ip> <num_of_sessions per c-node>"
    exit 1
fi

cnode_external_ip="$1"
num_of_sessions="$2"

multipath -F
iscsiadm -m node -U all
rm -rf /var/lib/iscsi/nodes/*
rm -rf /etc/iscsi/nodes/*
tgt_iqn=$(iscsiadm -m discovery -o update -t st -p ${cnode_external_ip} | sed -e"s/:3260,1//g" | head -n 1 | awk '{print $2}')
tgt_ips=$(iscsiadm -m discovery -o update -t st -p ${cnode_external_ip} | sed -e"s/:3260,1//g" | awk '{print $1}')
for i in $tgt_ips; do iscsiadm -m node -T $tgt_iqn -p $i -o update -n node.session.nr_sessions -v ${num_of_sessions}; done
iscsiadm -m node -L all
