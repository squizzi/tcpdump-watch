#!/bin/sh
# Checks df periodically for use percentage and stops tcpdump when the percentage is less than (or greater than 
# by modifiying -le to -ge) then a certain percentage.  In the example below that percentage value is 50.
# WIP: Needs better documentation 

tcpdump -s0 -i eth0 -W 2 -C 1024M -w /tmp/$(hostname).pcap -Z root &
while :; do
  percentage=$(df -h | grep '/nfs/mount' | awk '{ print $5 }' | cut -d'%' -f1)
  if [ $percentage -le 50 ]; then
        echo "$(date +%m-%d-%y@%H:%M): Detected deleted files on NFS export, killing rolling tcpdump now."
        pkill tcpdump
        break
  else
       	# Percentage not low enough, check again in 15 seconds
        sleep 15
  fi
done
