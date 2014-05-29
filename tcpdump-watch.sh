#!/bin/bash

## tcpdump-watch
## Part of a series of tcpdump watch scripts for stopping tcpdump based on certain conditions.
## Maintainer: Kyle Squizzato - ksquizza@redhat.com

## This script captures a tcpdump until certain log message is matched.

## Fill in each of the variables in the SETUP section then invoke the script and wait
## for the issue to occur, the script will stop on it's own when the $match is seen
## in the $log file.

## -------- SETUP ---------

# File output location
output="/tmp/tcpdump.pcap"

# Logfile to watch.  Accepts wildcards to watch multiple logfiles at once.
log="/var/log/messages"

# Message to match from log
match="message to match"

# Amount of time in seconds to wait before the tcpdump is stopped following a match
wait="3"

# Interface to filter
# It's best to filter the results based on the interface and server (if applicable) that
# is problematic.  If you do not know what interface to use specify 'any'.
interface="eth0"

# Server IP or hostname to filter
# If server filtering is not required simply remove the 'host $server' section from the
# tcpdump command below.  More complicated host filtering can be used if desired, check 
# 'man tcpdump'.
server="192.168.122.1"

# The tcpdump command creates a circular buffer of -W X dump files -C YM in size (in MB).
# The default value is 1 file, 1024M in size, it is recommended to modify the buffer values
# depending on the capture window needed.
tcpdump="tcpdump -s0 -i $interface host $server -W 1 -C 1024M -w $output -Z root"

## -------- END SETUP ---------

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
fi


