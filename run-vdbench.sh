#!/bin/bash

# Function to display usage
display_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -r, --rdpct <rdpct>           Set rdpct value (default: 100)"
    echo "  -x, --xfersize <xfersize>     Set xfersize value (default: 128k)"
    echo "  -s, --seekpct <seekpct>       Set seekpct value (default: EOF)"
    echo "  -t, --forthreads <forthreads> Set forthreads value (default: 20)"
    echo "  --skip-rescan                Skip SCSI rescan"
    exit 1
}

# Default values
rdpct=0
xfersize=128k
seekpct=EOF
forthreads=20
compratio=3
skip_rescan=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--rdpct) rdpct="$2"; shift 2 ;;
        -x|--xfersize) xfersize="$2"; shift 2 ;;
        -s|--seekpct) seekpct="$2"; shift 2 ;;
        -t|--forthreads) forthreads="$2"; shift 2 ;;
        --skip-rescan) skip_rescan=true; shift ;;
        *) display_usage ;;
    esac
done

# Perform SCSI rescan unless skip_rescan is true
if [ "$skip_rescan" != "true" ]; then
    sudo /usr/bin/scsi-rescan -r
fi

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