#!/bin/bash

# Function to display usage
display_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -r, --rdpct <rdpct>           Set rdpct value (default: 100)"
    echo "  -x, --xfersize <xfersize>     Set xfersize value (default: 128k)"
    echo "  -s, --seekpct <seekpct>       Set seekpct value (default: EOF)"
    echo "  -t, --forthreads <forthreads> Set forthreads value (default: 20)"
    exit 1
}

# Default values
rdpct=0
xfersize=128k
seekpct=EOF
forthreads=20
compratio=3

# Parse arguments
while getopts ":r:x:s:t:" opt; do
    case $opt in
        r) rdpct="$OPTARG" ;;
        x) xfersize="$OPTARG" ;;
        s) seekpct="$OPTARG" ;;
        t) forthreads="$OPTARG" ;;
        *) display_usage ;;
    esac
done

# Shift the parsed arguments so that $1 becomes the first non-option argument (if any)
shift $((OPTIND - 1))

# Other parts of the script remain unchanged
sudo /usr/bin/scsi-rescan -r

# Set initial value for drive index
d=1

# Populate temp.txt with configuration parameters
echo debug=88 > temp.txt
echo compratio=$compratio >> temp.txt
echo data_errors=1 >> temp.txt

# Iterate through the output of multipath command, filter by certain criteria, and append to temp.txt
for i in $(multipath -ll | egrep 'SILK|KMNRIO' | grep -v 0000 | awk '{print $3}'); do
    echo sd=sd$d,lun=/dev/$i,openflags=o_direct >> temp.txt
    let "d=d+1"
done

# Append additional configuration parameters to temp.txt
echo "wd=wd1,sd=sd*,rdpct=$rdpct,rhpct=0,whpct=0,xfersize=$xfersize,seekpct=$seekpct" >> temp.txt
echo "rd=rd1,wd=wd*,interval=1,iorate=MAX,elapsed=2600000,forthreads=($forthreads)" >> temp.txt

# Execute vdbench with the generated configuration file using sudo
sudo /local_hd/vdbench50406/vdbench -f temp.txt