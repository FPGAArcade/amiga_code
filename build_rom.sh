#!/bin/bash
set -e

romtool -v build -o replay.rom -t ext -s 128 -e f00000 -a f00010 -r 01.11 -f bootrom/bootrom.bin addmem/AddReplayMem poseidon/PoseidonLoader rtc/battclock.resource usb/usb_eth.autoconfig usb/replayusb.device eth/replayeth.device sdcard/replaysd.device rtg/Replay.card xaudio/Devs/AHI/replay.audio cpufreq/cpufreq.exe
printf "000001: 11" | xxd -r - replay.rom
romtool copy -c replay.rom replay.rom
romtool info replay.rom
romtool scan replay.rom
#romtool dump replay.rom | less

romtool -v build -o poseidon.rom -t ext -s 512 -e 3f80000 -a 3f80000 -r 01.00 -f  poseidon/hid.class poseidon/hub.class poseidon/input.device poseidon/massstorage.class poseidon/poseidon.library poseidon/PsdStackloader
romtool scan poseidon.rom
romtool info poseidon.rom

echo -n > RELEASE.md
echo "Changes:" >> RELEASE.md
echo "- [??] ???." >> RELEASE.md
echo "" >> RELEASE.md
echo -n "REPLAY.ROM " >> RELEASE.md
romtool info replay.rom | grep rom_rev | awk '{print $2}' >> RELEASE.md
echo "\`\`\`" >> RELEASE.md
romtool scan replay.rom >> RELEASE.md
echo "\`\`\`" >> RELEASE.md
echo -n "POSEIDON.ROM " >> RELEASE.md
romtool info poseidon.rom | grep rom_rev | awk '{print $2}' >> RELEASE.md
echo "\`\`\`" >> RELEASE.md
romtool scan poseidon.rom >> RELEASE.md
echo "\`\`\`" >> RELEASE.md
