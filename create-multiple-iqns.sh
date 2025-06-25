#!/bin/bash
#title          :km-create_multiple_iscsi_initiators.sh
#description    :This script creates and manages multiple iSCSI initiators with different IQNs from a single Linux box
#author         :David Turchak
#date           :17/09/2017
#version        :1.1
#usage          :./km-create_multiple_iscsi_initiators.sh [-h|--help] -n <number> -t <target_ip> -c <connect|disconnect>
#============================================================================

# Function to print usage information
print_usage() {
    cat << EOF
Usage: $0 [-h|--help] -n <number> -t <target_ip> -c <connect|disconnect>

This script manages multiple iSCSI initiators on a Linux system.

Options:
  -h, --help                Display this help message and exit
  -n <number>               Number of initiators to create (positive integer)
  -t <target_ip>            Target portal IP address
  -c <connect|disconnect>   Action to perform (connect or disconnect)

Examples:
  $0 -n 3 -t 192.168.1.100 -c connect
  $0 -n 3 -t 192.168.1.100 -c disconnect
EOF
    exit 0
}

# Function to print log messages
print_log() {
    local now
    now="$(date +%d/%m-%H:%M:%S)"
    case $1 in
        e)
            printf "%s [ERROR] %s\n" "$now" "$2" >&2
            exit 1
            ;;
        i)
            printf "%s [INFO] %s\n" "$now" "$2"
            ;;
        *)
            ;;
    esac
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ ! $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        print_log e "Invalid IP address format: $ip"
    fi
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [[ ! $octet =~ ^[0-9]+$ ]] || [ "$octet" -gt 255 ]; then
            print_log e "Invalid IP address: $ip"
        fi
    done
}

# Function to validate number of initiators
validate_number() {
    local num=$1
    if [[ ! $num =~ ^[0-9]+$ ]] || [ "$num" -le 0 ]; then
        print_log e "Number of initiators must be a positive integer: $num"
    fi
}

# Check for iscsiadm availability
if ! command -v iscsiadm &> /dev/null; then
    print_log e "iscsiadm command not found. Please install open-iscsi package."
fi

# Check for required files
initiator_name_file="/etc/iscsi/initiatorname.iscsi"
if [ ! -f "$initiator_name_file" ]; then
    print_log e "Initiator name file not found: $initiator_name_file"
fi

# Parse command line options
while getopts ":n:t:c:h-:" option; do
    case "${option}" in
        h) print_usage ;;
        -) [ "${OPTARG}" = "help" ] && print_usage ;;
        n) INUM=${OPTARG} ;;
        t) TP=${OPTARG} ;;
        c) CMD=${OPTARG} ;;
        *) print_log e "Unknown option: -$OPTARG" ;;
    esac
done

# Check for required parameters
if [ -z "$INUM" ] || [ -z "$TP" ] || [ -z "$CMD" ]; then
    print_log e "Missing required parameters. Use -h or --help for usage information."
fi

# Validate inputs
validate_number "$INUM"
validate_ip "$TP"
if [[ "$CMD" != "connect" && "$CMD" != "disconnect" ]]; then
    print_log e "Invalid command: $CMD. Must be 'connect' or 'disconnect'."
fi

get_target_iqn() {
    TIQN=$(iscsiadm -m discovery -t st -p "$TP" -P 1 | grep Target | awk '{print $2}')
    if [ -z "$TIQN" ]; then
        print_log e "Failed to discover target IQN for $TP"
    fi
    print_log i "Discovered target IQN: $TIQN"
}

create_ifaces() {
    for i in $(seq 1 "$INUM"); do
        if ! iscsiadm -m iface -I "iface$i" -o new; then
            print_log e "Failed to create interface iface$i"
        fi
        if ! iscsiadm -m iface -I "iface$i" -o update -n iface.initiatorname -v "${iface_iqn}_iface$i"; then
            print_log e "Failed to update initiator name for iface$i"
        fi
        print_log i "Created interface iface$i"
    done
}

remove_ifaces() {
    for i in $(seq 1 "$INUM"); do
        if ! iscsiadm -m iface -I "iface$i" -o delete; then
            print_log e "Failed to delete interface iface$i"
        fi
        print_log i "Removed interface iface$i"
    done
}

# Get current host IQN
iqn_str=$(head -n 1 "$initiator_name_file")
iface_iqn="${iqn_str/InitiatorName=/}"
if [ -z "$iface_iqn" ]; then
    print_log e "Failed to read initiator IQN from $initiator_name_file"
fi
print_log i "Using base IQN: $iface_iqn"

# Execute requested action
case "$CMD" in
    connect)
        get_target_iqn
        create_ifaces
        if ! iscsiadm -m discovery -t st -p "$TP"; then
            print_log e "Discovery failed for $TP"
        fi
        if ! iscsiadm --mode node --targetname "$TIQN" --login; then
            print_log e "Login failed for target $TIQN"
        fi
        print_log i "Successfully connected to $TIQN"
        ;;
    disconnect)
        get_target_iqn
        if ! iscsiadm --mode node --targetname "$TIQN" --logout; then
            print_log e "Logout failed for target $TIQN"
        fi
        remove_ifaces
        print_log i "Successfully disconnected from $TIQN"
        ;;
esac