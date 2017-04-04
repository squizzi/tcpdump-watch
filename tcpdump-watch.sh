#!/bin/bash

## tcpdump-watch
## Maintainer: Kyle Squizzato - ksquizza@redhat.com

## Simple tool to capture tcpdump until certain log message is matched.

## Fill in each of the variables in the SETUP section then invoke the script and wait
## for the issue to occur, the script will stop on it's own when the $match is seen
## in the $log file.

## -------- SETUP ---------

# File output location
output="/tmp/$(hostname)-$(date +"%Y-%m-%d-%H-%M-%S").pcap"

# Logfile to watch.  Accepts wildcards to watch multiple logfiles at once.
log="/var/log/messages"

# Message to match from log
match="not responding"

# Amount of time in seconds to wait before the tcpdump is stopped following a match
wait="2"

## -------- END SETUP ---------

# Required parameters are the target IP address and, optionally, a device to capture
# on if supplied as an argument
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        echo "Usage : $0 <ip_of_nfs_server>"
	echo "      : $0 <ip_of_nfs_server> <optional_capture_device>"
        exit 1
fi
nfs_server=$1
if [[ $nfs_server =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Found valid IP address $nfs_server for NFS server"
	nfs_server_ip=$nfs_server
else
	# Attempt a host based lookup of the name
	which host >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		nfs_server_ip=$(host $nfs_server | awk '/has address/ { print $NF }')
	fi
fi
if [ -z "$nfs_server_ip" ]; then
	echo "Could not validate $nfs_server as an IP or DNS name of NFS server"
	echo "Please enter a valid IP of NFS server"
	exit 1
fi

# Interface to gather tcpdump, derived based on the IP address of the NFS server
# NOTE: To prevent BZ 972396 we need to specify the interface by interface number
# If this is set as the second argument, then automatic assignment is skipped
if [ ! -z $2 ] && tcpdump -D | grep $2 >/dev/null 2>&1; then
	interface=$2
elif [ ! -z $2 ] && ! tcpdump -D | grep $2 >/dev/null 2>&1; then
	echo "Interface $2 does not exist."
	echo "Please select a valid interface to capture on."
	exit 1
else
	device=$(ip route get $nfs_server_ip | head -n1 | awk '{print $(NF-2)}')
	interface=$(tcpdump -D | grep -e $device | colrm 3 | sed 's/\.//')
fi

# The tcpdump command creates a circular buffer of -W X dump files -C YM in size (in MB).
# The default value is 4 files, 256M in size, it is recommended to modify the buffer values
# depending on the capture window needed.
tcpdump="tcpdump -s0 -i $interface host $nfs_server_ip -W 4 -C 256 -w $output -Z root"
echo $tcpdump
echo "Waiting for '$match' to show up in $log"

$tcpdump &
pid=$!

tail -fn 1 $log |
while read line
do
        ret=`echo $line | grep "$match"`
        if [[ -n $ret ]]
        then
                echo -e '\E[1;32m'"Match found, waiting" $wait "seconds then killing tcpdump."; tput sgr0
                sleep $wait
                kill $!
                break 1
        fi
done

# Gzip the tcpdumps 
if [ -e /bin/gzip ]; then
        echo Gzipping $output
        gzip -f $output*
fi

# Tar everything together 
if [ -e /bin/tar ]; then 
        echo "Creating a tarball of $log and $output."
        tar czvf $output.tar.gz $log $output* 
fi

echo -e "\n "
echo -e '\E[1;31m'"Please upload" $output.tar.gz "to Red Hat for analysis."; tput sgr0
