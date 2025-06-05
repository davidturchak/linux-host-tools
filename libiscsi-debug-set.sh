#!/bin/bash

# iscsi_debug.sh - Enable, disable, or show iSCSI kernel debug parameters

show_help() {
  cat <<EOF
Usage: $0 --action enable|disable|show

Options:
  --action    Specify one of:
                enable  - Turn ON all iSCSI debug parameters
                disable - Turn OFF all iSCSI debug parameters
                show    - Display current values of all debug parameters
  --help      Show this help message and exit

Examples:
  $0 --action enable
  $0 --action disable
  $0 --action show
EOF
}

PARAMS=(
  "/sys/module/libiscsi/parameters/debug_libiscsi_session"
  "/sys/module/libiscsi/parameters/debug_libiscsi_eh"
  "/sys/module/libiscsi/parameters/debug_libiscsi_conn"
  "/sys/module/libiscsi_tcp/parameters/debug_libiscsi_tcp"
  "/sys/module/iscsi_tcp/parameters/debug_iscsi_tcp"
)

# Parse arguments
ACTION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="$2"
      shift 2
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Validate action
if [[ -z "$ACTION" ]]; then
  echo "Error: --action is required"
  show_help
  exit 1
fi

case "$ACTION" in
  enable|disable)
    VALUE=0
    [[ "$ACTION" == "enable" ]] && VALUE=1
    for f in "${PARAMS[@]}"; do
      if [[ -w "$f" ]]; then
        echo $VALUE > "$f"
      else
        echo "Warning: Cannot write to $f (missing or permission denied)"
      fi
    done
    echo "iSCSI debug parameters set to $VALUE ($ACTION)"
    ;;
  show)
    echo "Current iSCSI debug parameter values:"
    for f in "${PARAMS[@]}"; do
      if [[ -r "$f" ]]; then
        echo "$f: $(cat $f)"
      else
        echo "$f: Not readable or missing"
      fi
    done
    ;;
  *)
    echo "Error: Invalid --action value: $ACTION"
    show_help
    exit 1
    ;;
esac
