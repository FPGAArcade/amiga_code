#!/bin/bash
set -e
rm -rf unpack
mkdir unpack
pushd unpack

xdftool -f ../drivers.hdf unpack .
cp -r drivers/* ..

popd
rm -rf unpack
