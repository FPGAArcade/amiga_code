#!/bin/bash

set -e

# check if vamos is installed
command -v vamos >/dev/null 2>&1 || { echo >&2 "vamos not installed! - see : https://github.com/cnvogelg/amitools/blob/master/doc/vamos.md"; exit 1; }

vamos smake $*
