#!/bin/bash

# Help function
function show_help {
    echo "Usage: ./script.sh [options]"
    echo "Options:"
    echo "  -n, --testname <name>       Test name (randread or randwrite)"
    echo "  -r, --testruntime <time>    Test runtime"
    echo "  -b, --bs <size>             Block size in Kilobyte"
    echo "  -s, --step <size>           Step size"
    echo "  -j, --jobs <num>            Number of jobs"
    echo "  -e, --stopthread <num>      Stop thread"
    echo "  -t, --startthread <num>     Start thread"
    echo "  -d, --diskslist <num>       Target Disks list separated by ':' Example: '/dev/sda:/dev/sdb:...'"
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
        -d|--disks)
            DisksList=$2
            shift 2;;
        -h|--help)
            show_help;;
        *)
            echo "Invalid option: $1"
            show_help;;
    esac
done

# Check if required parameters are provided
if [[ -z $TestName || -z $TestRuntime || -z $bs || -z $Step || -z $Jobs || -z $StopThread || -z $DisksList || -z $StartThread ]]; then
    echo "Missing required parameters."
    show_help
fi

if [[ $TestName != "randread" && $TestName != "randwrite" ]]; then
    echo "Invalid TestName specified. Please provide 'randread' or 'randwrite'."
    exit 1
fi


# Check if fio is installed
if command -v fio &> /dev/null
then
    echo "fio is already installed."
else
    # Install fio using yum
    echo "Installing fio..."
    yum install epel-release -y
    yum install jq zip fio -y

    # Check if the installation was successful
    if [ $? -eq 0 ]
    then
        echo "fio has been successfully installed."
    else
        echo "Failed to install fio. Please check your yum configuration and try again."
        exit 1
    fi
fi

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



fioPath=$(which fio)
if [[ ! -f $fioPath ]]; then
    echo "The file $fioPath does not exist. Exiting script."
    exit 1
fi

TestsStartTime=$(date +%s)

for (( t = StartThread; t <= StopThread; t += Step )); do
        TestStartTime=$(date +%s)
        $fioPath \
        --filename=$DisksList \
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
        --write_lat_log=${relativePath}/fio_latency_histogram_${TestStartTime}_${TestName}_${bs}k_threads_$t \
        --write_iops_log=${relativePath}/fio_iops_histogram_${TestStartTime}_${TestName}_${bs}k_threads_$t \
        --write_bw_log=${relativePath}/fio_bw_histogram_${TestStartTime}_${TestName}_${bs}k_threads_$t
done

TestsEndTime=$(date +%s)

echo "Tests End Epoch Time: $TestsEndTime"

vmSize=$(Get-VM-Size)

zip -j "${relativePath}/${TestName}_CPU_${vmSize}_jobs${Jobs}_Start_${TestsStartTime}_End_${TestsEndTime}.zip" "${relativePath:?}/"* -x "*.zip"
rm -rf "${relativePath:?}/"*.log
rm -rf "${relativePath:?}/"*.json

exit 0