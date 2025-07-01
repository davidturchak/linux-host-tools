#!/bin/bash

# Script to configure iSCSI connections with specified sessions

# Function to display help message
show_help() {
    cat << EOF
Usage: $0 [-h|--help] -t|--tgt_ip <ip_address> -n|--num_sessions <num_of_sessions>

Configure iSCSI connections with specified number of sessions per cnode target.

Options:
  -h, --help           Display this help message and exit
  -t, --tgt_ip         IP address of the iSCSI target
  -n, --num_sessions   Number of sessions per iSCSI target

Examples:
  $0 -t 192.168.1.100 -n 4
  $0 --tgt_ip 192.168.1.100 --num_sessions 4
  $0 --help

Note: This script requires root privileges to execute iSCSI commands.
EOF
    exit 0
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ ! $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Error: Invalid IP address format: $ip"
        exit 1
    fi
    # Check each octet
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [[ ! $octet =~ ^[0-9]+$ ]] || [ "$octet" -gt 255 ]; then
            echo "Error: Invalid IP address: $ip"
            exit 1
        fi
    done
}

# Function to validate number of sessions
validate_sessions() {
    local sessions=$1
    if [[ ! $sessions =~ ^[0-9]+$ ]] || [ "$sessions" -lt 1 ]; then
        echo "Error: Number of sessions must be a positive integer: $sessions"
        exit 1
    fi
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Parse command line options
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -t|--tgt_ip)
            shift
            cnode_external_ip="$1"
            ;;
        -n|--num_sessions)
            shift
            num_of_sessions="$1"
            ;;
        *)
            echo "Error: Unknown option: $1"
            show_help
            ;;
    esac
    shift
done

# Check if required parameters are provided
if [ -z "$cnode_external_ip" ] || [ -z "$num_of_sessions" ]; then
    echo "Error: Missing required arguments --tgt_ip and/or --num_sessions"
    show_help
fi

# Validate inputs
validate_ip "$cnode_external_ip"
validate_sessions "$num_of_sessions"

# Check if required commands are available
for cmd in multipath iscsiadm; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' not found"
        exit 1
    fi
done

# Main execution
echo "Starting iSCSI configuration for $cnode_external_ip with $num_of_sessions sessions..."

# Flush multipath and clean up existing sessions
multipath -F || { echo "Error: Failed to flush multipath"; exit 1; }
iscsiadm -m node -U all || { echo "Error: Failed to unload iSCSI sessions"; }

# Clean up node databases
rm -rf /var/lib/iscsi/nodes/* /etc/iscsi/nodes/* || { echo "Error: Failed to clean node databases"; exit 1; }

# Discover targets
tgt_iqn=$(iscsiadm -m discovery -o update -t st -p "${cnode_external_ip}" | sed -e"s/:3260,1//g" | head -n 1 | awk '{print $2}')
if [ -z "$tgt_iqn" ]; then
    echo "Error: Failed to discover iSCSI target IQN"
    exit 1
fi

tgt_ips=$(iscsiadm -m discovery -o update -t st -p "${cnode_external_ip}" | sed -e"s/:3260,1//g" | awk '{print $1}')
if [ -z "$tgt_ips" ]; then
    echo "Error: Failed to discover iSCSI target IPs"
    exit 1
fi

# Configure sessions for each target IP
for ip in $tgt_ips; do
    validate_ip "$ip"
    if ! iscsiadm -m node -T "$tgt_iqn" -p "$ip" -o update -n node.session.nr_sessions -v "${num_of_sessions}"; then
        echo "Error: Failed to configure sessions for IP $ip"
        exit 1
    fi
done

# Login to all targets
if ! iscsiadm -m node -L all; then
    echo "Error: Failed to login to iSCSI targets"
    exit 1
fi

echo "iSCSI configuration completed successfully"
exit 0