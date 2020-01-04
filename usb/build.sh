#!/bin/bash

set -e

# check if vamos is installed
command -v vamos >/dev/null 2>&1 || { echo >&2 "vamos not installed! - see : https://github.com/cnvogelg/amitools/blob/master/doc/vamos.md"; exit 1; }

# create output and temprary dirs
mkdir -p Devs/USBHardware T

# vamos requires absolute path to current working dir
ABS_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAMOS_CWD="$ABS_PATH/Deneb-Device"

vamos -d $VAMOS_CWD smake $*

if [ "$1x" = "cleanx" ]; then
	rm -rf Devs T
fi
