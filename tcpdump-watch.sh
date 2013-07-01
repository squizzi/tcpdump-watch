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

# Logfile to watch
log="/var/log/messages"

# Message to match from log
match="message to match"

# Amount of time in seconds to wait before the tcpdump is stopped following a match
wait="3"

# Interface to filter
# It's best to filter the results based on the interface and server (if applicable) that
# is problematic.  If you do not know what interface to use specify 'any'.
interface="eth0"

# Server IP to filter
# If server filtering is not required simply remove the 'host $serverip' section from the
# tcpdump command below.
serverip="192.168.122.1"

# The tcpdump command creates a circular buffer of -W X dump files -C YM in size (in MB).
# The default value is 1 file, 1024M in size, it is recommended to modify the buffer values
# depending on the capture window needed.
tcpdump="tcpdump -s0 -i $interface host $serverip -W 1 -C 1024M -w $output"

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
                pkill tcpdump
                break 1
        fi
done
