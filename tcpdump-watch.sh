#!/bin/bash

## tcpdump-watch
## Maintainer: Kyle Squizzato - ksquizza@redhat.com

## Simple tool to capture tcpdump until certain log message is matched.

## Fill in each of the variables in the SETUP section then invoke the script and wait
## for the issue to occur, the script will stop on it's own when the $match is seen
## in the $log file.

## -------- SETUP ---------

# File output location
output="/tmp/CASENUMBER-tcpdump.pcap"

# Logfile to watch.  Accepts wildcards to watch multiple logfiles at once.
log="/var/log/messages"

# Message to match from log
match="not responding"

# Amount of time in seconds to wait before the tcpdump is stopped following a match
wait="2"

## -------- END SETUP ---------

# The only required parameter is the IP address of the NFS server
if [ $# -ne 1 ]; then
        echo "Usage : $0 <ip_of_nfs_server>"
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
device=$(ip route get $nfs_server_ip | head -n1 | awk '{print $(NF-2)}')
interface=$(tcpdump -D | grep -e $device | colrm 3 | sed 's/\.//')

# The tcpdump command creates a circular buffer of -W X dump files -C YM in size (in MB).
# The default value is 1 file, 1024M in size, it is recommended to modify the buffer values
# depending on the capture window needed.
tcpdump="tcpdump -s0 -i $interface host $nfs_server_ip -W 1 -C 1024M -w $output -Z root"
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
                sleep $wait
                kill $!
                break 1
        fi
done
if [ -e /bin/gzip ]; then
        echo Gzipping $output
        gzip -f $output
        output=$output.gz
fi

echo "Please upload both $log and $output to Red Hat for analysis."
