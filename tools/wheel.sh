#!/usr/bin/env bash
set -ex

strip /gdb-source/build/gdb/gdb
./tools/bundle-linux.sh "/vendor" /gdb-source/build/gdb/gdb
cp -rf /gdb-source/build/gdb/data-directory/python/gdb/* /module/

for file in /vendor/lib/*; do
  # Check if the file is a symbolic link
  if [ -L "$file" ]; then
    # Resolve the symlink and get the target file
    target=$(readlink -f "$file")

    # Check if the target file exists
    if [ -e "$target" ]; then
      rm $file
      mv "$target" "$file"
    fi
  fi
done

rm /vendor/lib/ld-linux-x86-64.so.2
rm /vendor/lib/libc.so*
rm /vendor/lib/libdl.so*
rm /vendor/lib/libm.so*
rm /vendor/lib/libpthread.so*
rm /vendor/lib/libutil.so*
rm /vendor/lib/libstdc*
rm /vendor/lib/libgcc_s*
rm /vendor/lib/libpython*

/root/.pyenv/versions/3.12.2/bin/pip install wheel
/root/.pyenv/versions/3.12.2/bin/pip install setuptools
/root/.pyenv/versions/3.12.2/bin/python3 setup.py bdist_wheel
#mv dist/pwndbg_gdb-14.2.1-py3-none-any.whl pwndbg_gdb-14.2.1-cp311-cp311-manylinux_2_28_x86_64.whl
