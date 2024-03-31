#!/usr/bin/env bash
set -ex

PY_PATH=$1

wget https://ftp.gnu.org/gnu/gdb/gdb-14.2.tar.gz
tar -xf gdb-14.2.tar.gz
rm gdb-14.2.tar.gz
mv gdb-14.2 gdb-source

cd gdb-source
mkdir build
cd build

../configure \
  --disable-nls \
  --disable-sim \
  --disable-werror \
  --without-guile \
  --without-libunwind-ia64 \
  --disable-source-highlight \
  --disable-threading \
  --disable-tui \
  --with-python=$PY_PATH \
  --without-intel-pt \
  --without-babeltrace \
  --without-debuginfod \
  --without-xxhash \
  --with-lzma \
  --with-expat \
  --with-zstd \
  --with-zlib \
  --with-curses \
  --with-system-gdbinit=/etc/gdb/gdbinit \
  --enable-targets=all

make -j $(nproc)
