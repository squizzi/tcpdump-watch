#!/bin/bash

## tcpdump-fs
## Part of a series of tcpdump watch scripts for stopping tcpdump based on certain conditions.
## Maintainer: Kyle Squizzato - ksquizza@redhat.com

## This script captures a tcpdump until a Usage% value is either too high or too low.

## Fill in each of the variables in the SETUP section then invoke the script and wait for
## the issue to occur, the script will stop on it's own when the %Usage in df is either greater
## than or less than the $value specified, depending on the $delim chosen.

## -------- SETUP ---------

# File output location
output="/tmp/CASENUMBER-tcpdump.pcap"

# Usage percentage value to check for
value=50

# Check interval
interval=15

# NFS mount to periodically check
nfsmount=/mnt/nfs

## ------- UNCOMMENT ONE VALUE BELOW ----------

# Uncomment the delim variable in this section if you wish to stop the script when the usage percentage is # GREATER THAN OR EQUAL TO the value above
#delim=ge

# Uncomment the delim variable in this section if you wish to stop the script when the usage percentage is # LESS THAN OR EQUAL TO the value above
#delim=le

## ------- UNCOMMENT ONE VALUE ABOVE ----------

# Interface to filter
# It's best to filter the results based on the interface and server (if applicable) that
# is problematic.  Do not use 'any' as it may create erroneous data.
interface="eth0"

# The tcpdump command creates a circular buffer of -W X dump files -C YM in size (in MB).
# The default value is 2 files, 1024M in size, it is recommended to modify the buffer values
# depending on the capture window needed.
tcpdump="tcpdump -s0 -i $interface -W 2 -C 1024M -w $output -Z root"

## -------- END SETUP ---------


$tcpdump &
pid=$!

while :; do
  percentage=$(df -h | grep $nfsmount | awk '{ print $5 }' | cut -d'%' -f1)
  if [ $percentage -$delim $value ]; then
        echo "$(date +%m-%d-%y@%H:%M): Detected deleted files on NFS export, killing rolling tcpdump now."
        kill $!
        break 1
  else
        # Percentage not low enough, check again in 15 seconds
        sleep $interval
  fi
done

if [ -e /bin/gzip ]; then
        echo Gzipping $output
        gzip -f $output
fi
