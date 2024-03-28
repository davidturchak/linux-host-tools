#!/bin/bash

# Find the directory where the script resides
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Function to create multipath configuration
function create_multipath_conf() {
    echo "Creating multipath configuration..."
    cat << EOF > /etc/multipath.conf
defaults {
    find_multipaths              no
    user_friendly_names          yes
    polling_interval             1
    verbosity                    2
}

blacklist {
    devnode "^(ram|raw|loop|fd|md|dm-|sr|scd|st)[0-9]*"
    devnode "^hd[a-z]"
    devnode "^sda$"
    device {
        vendor  "NVME"
        product "Microsoft NVMe Direct Disk"
    }
    device {
        vendor  "Msft"
        product "Virtual Disk"
    }
}

devices {
    device {
        vendor                        "KMNRIO"
        product                       "KDP"
        path_grouping_policy          multibus
        path_checker                  tur
        path_selector                 "queue-length 0"
        no_path_retry                 fail
        hardware_handler              "0"
        failback                      immediate
        fast_io_fail_tmo              2
        dev_loss_tmo                  3
        max_sectors_kb                1024
    }
    device {
        vendor                        "SILK"
        product                       "KDP"
        path_grouping_policy          multibus
        path_checker                  tur
        path_selector                 "queue-length 0"
        no_path_retry                 fail
        hardware_handler              "0"
        failback                      immediate
        fast_io_fail_tmo              2
        dev_loss_tmo                  3
        max_sectors_kb                1024
    }
    device {
        vendor                        "SILK"
        product                       "SDP"
        path_grouping_policy          multibus
        path_checker                  tur
        path_selector                 "queue-length 0"
        no_path_retry                 fail
        hardware_handler              "0"
        failback                      immediate
        fast_io_fail_tmo              2
        dev_loss_tmo                  3
        max_sectors_kb                1024
    }
}
blacklist_exceptions {
    property "(ID_SCSI_VPD|ID_WWN|ID_SERIAL)"
}
EOF
    echo "Multipath configuration created."
}

# Function to restart multipath daemon
function restart_multipath() {
    echo "Restarting multipath daemon..."
    systemctl restart multipathd
    echo "Multipath daemon restarted."
}

# Function to apply udev rules
function apply_udev_rules() {
    echo "Applying udev rules..."
    udevadm trigger && udevadm settle
    echo "Udev rules applied."
}

# Function to create udev rules
function create_udev_rules() {
    echo "Creating udev rules..."
    cat << EOF > /usr/lib/udev/rules.d/98-sdp-io.rules
ACTION=="add|change", SUBSYSTEM=="block", ENV{ID_SERIAL}=="2002*", ATTR{queue/scheduler}="noop"
ACTION=="add|change", SUBSYSTEM=="block", ENV{ID_SERIAL}=="2002*", ATTR{device/timeout}="300"
ACTION=="add|change", SUBSYSTEM=="block", ENV{ID_SERIAL}=="2002*", ATTR{queue/scheduler}="none"
ACTION=="add|change", SUBSYSTEM=="block", ENV{DM_UUID}=="mpath-2002*", ATTR{queue/scheduler}="noop"
ACTION=="add|change", SUBSYSTEM=="block", ENV{DM_UUID}=="mpath-2002*", ATTR{queue/scheduler}="none"
ACTION=="add|change", SUBSYSTEM=="block", ENV{ID_SERIAL}=="280b*", ATTR{queue/scheduler}="noop"
ACTION=="add|change", SUBSYSTEM=="block", ENV{ID_SERIAL}=="280b*", ATTR{device/timeout}="300"
ACTION=="add|change", SUBSYSTEM=="block", ENV{ID_SERIAL}=="280b*", ATTR{queue/scheduler}="none"
ACTION=="add|change", SUBSYSTEM=="block", ENV{DM_UUID}=="mpath-280b*", ATTR{queue/scheduler}="noop"
ACTION=="add|change", SUBSYSTEM=="block", ENV{DM_UUID}=="mpath-280b*", ATTR{queue/scheduler}="none"
EOF
    echo "Udev rules created."
}

# Main script
create_udev_rules
apply_udev_rules
create_multipath_conf
restart_multipath

# Create a file to indicate completion
touch "/root/sdp_ready_$(date +"%Y%m%d_%H%M%S")"

echo "Setup completed successfully."
exit 0
