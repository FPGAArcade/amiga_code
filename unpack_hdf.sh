#!/bin/bash
set -e
rm -rf unpack
mkdir unpack
pushd unpack

xdftool -f ../amiga_tools.hdf unpack .
cp -r amiga_tools/* ..

popd
rm -rf unpack
