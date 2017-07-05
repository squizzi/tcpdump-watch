#!/bin/bash

## tcpdump-watch-net
## Maintainer: Kyle Squizzato - ksquizz@gmail.com

## Simple tool to capture tcpdump until certain nfs.status is seen over the wire and
## execute commands both locally and remotely based on that output.

## Fill in each of the variables in the SETUP section then invoke the script and wait
## for the issue to occur.

## -------- SETUP ---------

# File output location
output="/tmp/tcpdump.pcap"

# Amount of time in seconds to wait before the tcpdump is stopped following a match
wait="2"

# FIXME: Since tshark doesn't allow variables in its filter arguments we need to specify
# the NFS.SERVER.IP, NFS.CLIENT.IP and INTERFACE to capture on throughout the script manually.  Please
# edit the section below and fill in each.

# NOTE: For the ssh portion of this script to work you will need to configure keyless authentication
# on the target NFS server.

## -------- END SETUP ---------

# Trigger tshark capture to temp file and kill if any lines are generated.
# FIXME: What if we want to specify a different nfs.status?

if [ -e /usr/sbin/tshark ]; then
        echo "Starting tshark capture to monitor on the wire traffic."
        tshark -l -i INTERFACE -s0 -f 'dst net NFS.SERVER.IP or dst net NFS.CLIENT.IP' -R '(nfs.status == 10025)' > /tmp/tshark.tmp 2> /dev/null &
else
        echo "No tshark found.  Please install wireshark to use this script."
        exit 1

# The tcpdump command creates a circular buffer of -W X dump files -C YM in size (in MB).
# The default value is 1 file, 1024M in size, it is recommended to modify the buffer values
# depending on the capture window needed.
tcpdump="tcpdump -s0 -i INTERFACE host NFS.SERVER.IP -W 1 -C 2048M -w $output -Z root"
echo $tcpdump

$tcpdump &
pid=$!

tail -fn 1 /tmp/tshark.tmp |
while read line
do
        ret=`echo $line`

        if [[ -n $ret ]]
        then
                echo 'Match found, waiting $wait seconds then stopping tcpdump on client and server.'
                sleep $wait
                kill $!
                ssh -t root@NFS.SERVER.IP <commands to run on NFS server>
                rm /tmp/tshark.tmp
                break 1
        fi

done

if [ -e /bin/gzip ]; then
        echo Gzipping $output
        gzip -f $output
        output=$output.gz
fi

echo "Please upload $output to Red Hat for analysis."
