#!/usr/bin/env bash

#docker buildx build --progress=plain -t pwndbg-gdb -f ./Dockerfile .
#
#exit 1
for ver in ""39 312 311 310 38""; do
  rm -rf $(pwd)/src/gdb_tools/_vendor
  mkdir -p $(pwd)/src/gdb_tools/_vendor

  rm -rf $(pwd)/src/gdb
  mkdir -p $(pwd)/src/gdb

  rm -rf $(pwd)/build
  mkdir -p $(pwd)/build

  rm -rf $(pwd)/dist
  mkdir -p $(pwd)/dist

  rm -rf $(pwd)/src/pwndbg_gdb.egg-info

  docker run --rm -it \
    -v $(pwd):/code:ro \
    -v $(pwd)/src/gdb_tools/_vendor:/vendor \
    -v $(pwd)/src/gdb:/module \
    -v $(pwd)/src/pwndbg_gdb.egg-info:/code/src/pwndbg_gdb.egg-info \
    -v $(pwd)/build:/code/build \
    -v $(pwd)/dist:/code/dist \
    -w /code pwndbg-gdb:$ver /bin/bash -c './tools/wheel.sh'
  mv -f ./dist/pwndbg_gdb-14.2.1-py3-none-any.whl ./pypidist/pwndbg_gdb-14.2.1-cp$ver-cp$ver-manylinux_2_28_x86_64.whl
done;
