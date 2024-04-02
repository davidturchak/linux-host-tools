#!/bin/bash
#title          :km-create_multiplete_iscsi_initiators.sh
#description    :This script can create multiple initiators with different IQNs from a single Linux box
#author         :David Turchak
#date           :17/09/2017
#version        :1.0
#============================================================================

print_log() {
    local now
    now="$(date +%d/%m-%H:%M:%S)"
    case $1 in
        e)
            printf "%s [ERROR] %s \n" "$now" "$2"; exit 1 ;;
        i)
            printf "%s [INFO] %s \n" "$now" "$2" ;;
        *)
            ;;
    esac
}

if [ "$#" -lt 3 ]; then
    print_log e "Illegal number of parameters \n Parameters: \n\t \
                -n  [number_of_initiators_to create] \n\t \
                -t  [target_portal_ip] \n\t \
         -c  [COMMAND: connect | disconnect] \n"
fi

while getopts ":n:t:c:" option; do
    case "${option}" in
        n) INUM=${OPTARG} ;;
        t) TP=${OPTARG} ;;
        c) CMD=${OPTARG} ;;
        *)
            print_log e "Unknown option provided"
            ;;
    esac
done

get_target_iqn() {
    ping -c 1 "$TP" &> /dev/null && print_log i "$TP is alive" || print_log e  "$TP is a dead host."
    TIQN=$(iscsiadm -m discovery -t st -p "$TP" -P 1 | grep Target | awk '{print $2}')
}

create_ifaces() {
    for i in $(seq 1 "$INUM"); do
        iscsiadm -m iface -I "iface$i" -o new
        iscsiadm -m iface -I "iface$i" -o update -n iface.initiatorname -v "${iface_iqn}_iface$i"
    done
}

remove_ifaces() {
    for i in $(seq 1 "$INUM"); do
        iscsiadm -m iface -I "iface$i" -o delete
    done
}

# Get current host IQN
initiator_name_file="/etc/iscsi/initiatorname.iscsi"
iqn_str=$(head -n 1 "$initiator_name_file")
iface_iqn="${iqn_str/InitiatorName=/}"
echo "$iface_iqn"

# Parsing action
if [ "$CMD" == "connect" ]; then
    get_target_iqn
    create_ifaces
    iscsiadm -m discovery -t st -p "$TP"
    iscsiadm --mode node --targetname "$TIQN" --login
elif [ "$CMD" == "disconnect" ]; then
    get_target_iqn
    iscsiadm --mode node --targetname "$TIQN" --logout
    remove_ifaces
else
    print_log e  "Unknown command!"
fi