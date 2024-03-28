#!/bin/bash

# Help function
function show_help {
    echo "Usage: ./script.sh [options]"
    echo "Options:"
    echo "  -n, --testname <name>       Test name (randread or randwrite)"
    echo "  -r, --testruntime <time>    Test runtime"
    echo "  -b, --bs <size>             Block size"
    echo "  -s, --step <size>           Step size"
    echo "  -j, --jobs <num>            Number of jobs"
    echo "  -e, --stopthread <num>      Stop thread"
    echo "  -t, --startthread <num>     Start thread"
    echo "  -i, --sdpip <ip>            SDP IP address"
    echo "  -p, --sdppass <password>    SDP password"
    echo "  -h, --help                  Show help"
    exit 1
}

# Default parameter values
TestName=""
TestRuntime=""
bs=""
Step=""
Jobs=""
StopThread=""
StartThread=""
SdpIP=""
SdpPass=""
username="admin"
datapoints=1000

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--testname)
            TestName=$2
            shift 2;;
        -r|--testruntime)
            TestRuntime=$2
            shift 2;;
        -b|--bs)
            bs=$2
            shift 2;;
        -s|--step)
            Step=$2
            shift 2;;
        -j|--jobs)
            Jobs=$2
            shift 2;;
        -e|--stopthread)
            StopThread=$2
            shift 2;;
        -t|--startthread)
            StartThread=$2
            shift 2;;
        -i|--sdpip)
            SdpIP=$2
            shift 2;;
        -p|--sdppass)
            SdpPass=$2
            shift 2;;
        -h|--help)
            show_help;;
        *)
            echo "Invalid option: $1"
            show_help;;
    esac
done

# Check if required parameters are provided
if [[ -z $TestName || -z $TestRuntime || -z $bs || -z $Step || -z $Jobs || -z $StopThread || -z $StartThread || -z $SdpIP || -z $SdpPass ]]; then
    echo "Missing required parameters."
    show_help
fi

if [[ $TestName != "randread" && $TestName != "randwrite" ]]; then
    echo "Invalid TestName specified. Please provide 'randread' or 'randwrite'."
    exit 1
fi

yum install epel-release -y
yum install jq zip fio -y

# Create a working folder for the test
folderName="${TestName}_${bs}k"
relativePath="./${folderName}"

if [[ -d $relativePath ]]; then
    read -p "The folder '$relativePath' already exists. Do you want to overwrite it? (Y/N)" confirmation
    if [[ $confirmation != "Y" && $confirmation != "y" ]]; then
        echo "Operation aborted. Folder will not be overwritten. Exiting script."
        exit 1
    fi
    rm -rf $relativePath
fi

mkdir $relativePath
fullPath=$(realpath $relativePath)
echo "Full path of the test run: $fullPath"

function Get-VM-Size {
    if lsmod | grep -q "hyperv"; then
        #Running on an Azure VM. Going to retrieve the VM size
        vmSize=$(curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2021-02-01&format=text")
    elif lsmod | grep -q "virtio"; then
        #Running on a GCP VM. Going to retrieve the VM shape
        vmSize=$(echo $(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/machine-type -s) | awk -F '/' '{print $NF}')
    else
        #Not running on an Azure or GCP VM. Going to use the CPU core count
        vmSize=$(nproc)
    fi
    echo $vmSize
}


function Get-Sdp-Time {
float_time=`curl -k -s "https://${SdpIP}/api/v2/system/state" --user "${username}:${SdpPass}" --max-time 5 | jq -r '.hits[0].system_time'`
if [ $? -eq 0 ]; then
   integer_time=$(printf "%.0f" "$float_time")
   echo $integer_time
else
    echo "[ERROR]: Failed to retrieve time from SDP ."
    exit 1
fi
}

function Get-Sdp-Disks {
    SdpDrives=$(multipath -ll | egrep 'SILK' | grep -v 0000 | awk '{print "/dev/" $3}' | paste -sd ":")

    if [[ -z $SdpDrives ]]; then
        echo "No SILK drives found. Exiting script."
        exit 1
    fi

    echo $SdpDrives
}

function Get-Sdp-Statistics {
    SdpStart=$1
    SdpEnd=$2
    SummaryJson="${relativePath}/${TestName}_${bs}k_SDPstart_${SdpStart}_SDPend_${SdpEnd}.json"

    curl -k -s "https://${SdpIP}/api/v2/stats/system?__datapoints=${datapoints}&__pretty&__from_time=${SdpEnd}&__resolution=5s" --user "${username}:${SdpPass}" --max-time 5 -o $SummaryJson
    if [ $? -eq 0 ]; then
        echo "[INFO]: The SDP statistics file is $SummaryJson"
    else
        echo "[ERROR]: Failed to retrieve SDP statistics."
        exit 1
    fi
}

fioPath=$(which fio)
if [[ ! -f $fioPath ]]; then
    echo "The file $fioPath does not exist. Exiting script."
    exit 1
fi

SdpDisks=$(Get-Sdp-Disks)
SdpTestsStartTime=$(Get-Sdp-Time)

for (( t = StartThread; t <= StopThread; t += Step )); do
        SdpTestStartTime=$(Get-Sdp-Time)
        $fioPath \
        --filename=$SdpDisks \
        --direct=1 \
        --thread \
        --rw=$TestName \
        --numjobs=$Jobs \
        --ioengine=libaio \
        --buffer_compress_percentage=75 \
        --refill_buffers \
        --buffer_pattern=0xdeadbeef \
        --time_based \
        --group_reporting \
        --name=${TestName}-test-job-name \
        --runtime="${TestRuntime}" \
        --bs="${bs}k" \
        --iodepth=$t \
        --log_avg_msec=1000 \
        --write_lat_log=${relativePath}/fio_latency_histogram_${SdpTestStartTime}_${TestName}_${bs}k_threads_$t \
        --write_iops_log=${relativePath}/fio_iops_histogram_${SdpTestStartTime}_${TestName}_${bs}k_threads_$t \
        --write_bw_log=${relativePath}/fio_bw_histogram_${SdpTestStartTime}_${TestName}_${bs}k_threads_$t
done

echo "[INFO]: Going to extract a statistics from SDP:"

SdpTestsEndTime=$(Get-Sdp-Time)
Get-Sdp-Statistics $SdpTestsStartTime $SdpTestsEndTime
echo "SDP tests End Epoch Time: $SdpTestsEndTime"

vmSize=$(Get-VM-Size)

zip -j "${relativePath}/${TestName}_CPU_${vmSize}_jobs${Jobs}_Start_${SdpTestsStartTime}_End_${SdpTestsEndTime}.zip" "${relativePath:?}/"* -x "*.zip"
rm -rf "${relativePath:?}/"*.log
rm -rf "${relativePath:?}/"*.json

exit 0