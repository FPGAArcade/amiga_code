#!/bin/bash
set -e

romtool -v build -o replay.rom -t ext -s 64 -e f00000 -a f00010 -r 01.06 -f bootrom/bootrom.bin addmem/AddReplayMem poseidon/PoseidonLoader rtc/battclock.resource usb/usb_eth.autoconfig usb/replayusb.device eth/replayeth.device
printf "000001: 11" | xxd -r - replay.rom
romtool copy -c replay.rom replay.rom
romtool info replay.rom
romtool scan replay.rom
#romtool dump replay.rom | less

romtool -v build -o poseidon.rom -t ext -s 512 -e 3f80000 -a 3f80000 -r 01.00 -f  poseidon/hid.class poseidon/hub.class poseidon/input.device poseidon/massstorage.class poseidon/poseidon.library poseidon/PsdStackloader
romtool scan poseidon.rom
romtool info poseidon.rom

echo -n RELEASE.md
echo "Changes:" >> RELEASE.md
echo "- [??] ???." >> RELEASE.md
echo "" >> RELEASE.md
echo "REPLAY.ROM" >> RELEASE.md
echo "\`\`\`" >> RELEASE.md
romtool scan replay.rom >> RELEASE.md
echo "\`\`\`" >> RELEASE.md
echo "POSEIDON.ROM" >> RELEASE.md
echo "\`\`\`" >> RELEASE.md
romtool scan poseidon.rom >> RELEASE.md
echo "\`\`\`" >> RELEASE.md
