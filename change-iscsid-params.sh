#!/bin/bash

# Script to manage iSCSI configuration
# Version: 1.0.0

# Exit on error, undefined variables, and pipe failures
set -euo pipefail
IFS=$'\n\t'

# Help function with detailed usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

This script manages iSCSI configuration by updating parameters in iscsid.conf,
handling session disconnection/reconnection, and restarting necessary services.

Options:
  -p, --param <parameter>    iSCSI parameter to modify (e.g., login_timeout)
  -v, --value <value>         Value to set for the specified parameter (positive integer)
  -h, --help                 Display this help message and exit

Examples:
  $0 -p login_timeout -v 30
  $0 --param logout_timeout --value 15

Notes:
- Requires root privileges
- Parameter names must match valid iscsid.conf node.conn[0].timeo.* settings
- Values must be positive integers
- Backup of iscsid.conf is created before modification

Exit Codes:
  0: Success
  1: General error
  2: Invalid parameters
  3: No root privileges
  4: iSCSI configuration file not found
EOF
    exit 0
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: This script must be run as root" >&2
        exit 3
    fi
}

# Function to validate input parameters
validate_inputs() {
    local param_name=$1
    local param_val=$2
    
    # Check if parameter name is non-empty
    if [[ -z "$param_name" ]]; then
        echo "Error: Parameter name cannot be empty" >&2
        exit 2
    fi
    
    # Validate parameter value is a positive integer
    if ! [[ "$param_val" =~ ^[0-9]+$ ]]; then
        echo "Error: Parameter value must be a positive integer" >&2
        exit 2
    fi
}

# Function to get the IP of the first connected iSCSI session
get_first_iscsi_ip() {
    iscsiadm -m session -P 3 2>/dev/null | grep 'Current Portal' | head -n 1 | tr ':' ' ' | awk '{print $3}'
}

# Function to disconnect all iSCSI targets and sessions
disconnect_iscsi() {
    echo "Disconnecting all iSCSI targets and sessions..."
    iscsiadm -m node -U all 2>/dev/null || true
    rm -rf /var/lib/iscsi/nodes/* 2>/dev/null || true
    rm -rf /var/lib/iscsi/send_targets/* 2>/dev/null || true
}

# Function to change the parameter in iscsid.conf
change_iscsid_param() {
    local param_name=$1
    local param_val=$2
    local config_file="/etc/iscsi/iscsid.conf"
    
    # Check if config file exists
    if [[ ! -f "$config_file" ]]; then
        echo "Error: iSCSI configuration file not found at $config_file" >&2
        exit 4
    fi
    
    # Backup config file
    cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Update parameter
    if grep -q "^node\.conn\[0\]\.timeo\.$param_name = " "$config_file"; then
        sed -i "s/^\(node\.conn\[0\]\.timeo\.$param_name = \)[0-9]\+/\1$param_val/" "$config_file"
    else
        echo "Error: Parameter node.conn[0].timeo.$param_name not found in $config_file" >&2
        exit 1
    fi
}

# Function to restart the iscsid service
restart_iscsid_service() {
    echo "Restarting iSCSI services..."
    systemctl restart iscsi iscsid 2>/dev/null || {
        echo "Warning: Failed to restart iSCSI services" >&2
        return 1
    }
}

# Function to discover targets portals using stored IP and connect all
discover_and_connect_targets() {
    local ip=$1
    echo "Discovering and connecting to iSCSI targets at $ip..."
    iscsiadm -m discovery -t sendtargets -p "$ip" 2>/dev/null || {
        echo "Warning: Failed to discover targets at $ip" >&2
        return 1
    }
    iscsiadm -m node -L all 2>/dev/null || {
        echo "Warning: Failed to connect to all targets" >&2
        return 1
    }
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--param)
            ParamName="$2"
            shift 2 ;;
        -v|--value)
            ParamVal="$2"
            shift 2 ;;
        -h|--help)
            usage ;;
        *)
            echo "Error: Invalid option: $1" >&2
            usage ;;
    esac
done

# Check if required parameters are provided
if [[ -z ${ParamName:-} || -z ${ParamVal:-} ]]; then
    echo "Error: Missing required parameters" >&2
    usage
fi

# Main execution
check_root
validate_inputs "$ParamName" "$ParamVal"

# Get the IP of the first connected iSCSI session
first_iscsi_ip=$(get_first_iscsi_ip)

if [[ -n "$first_iscsi_ip" ]]; then
    disconnect_iscsi
    change_iscsid_param "$ParamName" "$ParamVal"
    restart_iscsid_service
    discover_and_connect_targets "$first_iscsi_ip"
else
    echo "No active iSCSI session found. Updating parameter only."
    change_iscsid_param "$ParamName" "$ParamVal"
    restart_iscsid_service
fi

echo "iSCSI configuration updated successfully"
exit 0