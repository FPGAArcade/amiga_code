#!/bin/bash
romtool -v build -o replay.rom -t ext -s 64 -e f00000 -a f00010 -r 01.04 bootrom/bootrom.bin addmem/AddReplayMem rtc/battclock.resource usb/usb_eth.autoconfig usb/replayusb.device
printf "000001: 11" | xxd -r - replay.rom
#romtool info replay.rom
romtool scan replay.rom
#romtool dump replay.rom | less
