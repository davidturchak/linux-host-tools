#!/bin/bash

# Help function
function show_help {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -p, --param <name> iscsid param to change"
    echo "  -v, --value <time> param value to set"
    echo "  -h, --help    script help"
    exit 1
}

# Function to get the IP of the first connected iSCSI session
get_first_iscsi_ip() {
    iscsiadm -m session -P 3 | grep 'Current Portal' | head -n 1 |tr ':' ' ' | awk '{print $3}'
}

# Function to disconnect all iSCSI targets and sessions
disconnect_iscsi() {
    iscsiadm -m node -U all
    rm -rf /var/lib/iscsi/nodes/*
    rm -rf /var/lib/iscsi/send_targets/*
}

# Function to change the parameter in iscsid.conf
change_iscsid_param() {
    local param_name=$1
    local param_val=$2
    sed -i "s/^\(node\.conn\[0\]\.timeo\.$param_name = \)[0-9]\+/\1$param_val/" /etc/iscsi/iscsid.conf
}

# Function to restart the iscsid service
restart_iscsid_service() {
    systemctl restart iscsi iscsid
}

# Function to discover targets portals using stored IP and connect all
discover_and_connect_targets() {
    local ip=$1
    iscsiadm -m discovery -t sendtargets -p $ip
    iscsiadm -m node -L all
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--param)
            ParamName=$2
            shift 2;;
        -v|--value)
            ParamVal=$2
            shift 2;;
        -h|--help)
            show_help;;
        *)
            echo "Invalid option: $1"
            show_help;;
    esac
done

# Check if required parameters are provided
if [[ -z $ParamName || -z $ParamVal ]]; then
    echo "Missing required parameters."
    show_help
fi

# Get the IP of the first connected iSCSI session
first_iscsi_ip=$(get_first_iscsi_ip)

if [ -n "$first_iscsi_ip" ]; then
    # Disconnect all iSCSI targets and sessions
    disconnect_iscsi
    
    # Change the parameter in iscsid.conf
    change_iscsid_param $ParamName $ParamVal
    
    # Restart iscsid service
    restart_iscsid_service
    
    # Discover targets portals using stored IP and connect all
    discover_and_connect_targets $first_iscsi_ip
else
    echo "No iSCSI session found. But i will change the param anyway."
    # Change the parameter in iscsid.conf
    change_iscsid_param $ParamName $ParamVal
    
    # Restart iscsid service
    restart_iscsid_service
fi
