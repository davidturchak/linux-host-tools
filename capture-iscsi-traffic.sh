#!/bin/bash

# Help message function
show_help() {
    echo "Usage: $0 --ip1 <IP1> --ip2 <IP2> --nic <interface>"
    echo
    echo "Parameters:"
    echo "  --ip1     First IP address (required)"
    echo "  --ip2     Second IP address (required)"
    echo "  --nic     Network interface name (required)"
    echo "  --help    Show this help message and exit"
    exit 0
}

# Check for dependencies
missing_tools=()
command -v tcpdump >/dev/null 2>&1 || missing_tools+=("tcpdump")
command -v tshark  >/dev/null 2>&1 || missing_tools+=("tshark")

if [[ ${#missing_tools[@]} -gt 0 ]]; then
    echo "Missing required tool(s): ${missing_tools[*]}"
    echo "Please install them using your package manager. For example:"
    echo "  sudo yum install ${missing_tools[*] }"
    exit 1
fi

# Default values
ip1=""
ip2=""
nic=""

# Parse parameters
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --ip1) ip1="$2"; shift ;;
        --ip2) ip2="$2"; shift ;;
        --nic) nic="$2"; shift ;;
        --help) show_help ;;
        *) echo "Unknown parameter: $1"; show_help ;;
    esac
    shift
done

# Check for required parameters
if [[ -z "$ip1" || -z "$ip2" || -z "$nic" ]]; then
    echo "Missing required parameters."
    show_help
fi

# Construct and run the command
cmd="stdbuf -oL tcpdump -i $nic -nn -w - '(host $ip1 and host $ip2) and port 3260' | stdbuf -oL tshark -i - -l -o tcp.desegment_tcp_streams:TRUE -o iscsi.desegment_iscsi_messages:TRUE -Y iscsi -t ad"

echo "Running command:"
echo "$cmd"
eval "$cmd"
