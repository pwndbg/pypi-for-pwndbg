#! /usr/bin/env nix-shell
#! nix-shell -i bash -p python3.pkgs.wheel python3.pkgs.setuptools uv patchelf nukeReferences

set -ex

PY_VERSION=$1

nix build .#gdb_$PY_VERSION -L
GDB_DIR="./result"

rm -rf ./dist
rm -rf ./src/gdb
rm -rf ./src/gdb_for_pwndbg/_vendor

mkdir -p ./src/gdb_for_pwndbg/_vendor/bin
mkdir -p ./src/gdb_for_pwndbg/_vendor/share

cp $GDB_DIR/bin/gdb ./src/gdb_for_pwndbg/_vendor/bin/
chmod -R +w ./src/gdb_for_pwndbg/_vendor

patchelf --set-interpreter /lib/ld-linux-aarch64.so.1 ./src/gdb_for_pwndbg/_vendor/bin/gdb
patchelf --set-rpath '$ORIGIN/../../../../../../lib' ./src/gdb_for_pwndbg/_vendor/bin/gdb
strip ./src/gdb_for_pwndbg/_vendor/bin/gdb
nuke-refs ./src/gdb_for_pwndbg/_vendor/bin/gdb

#cp -rf $GDB_DIR/share/gdb/ ./src/gdb_for_pwndbg/_vendor/share/
#mkdir -p ./src/gdb_for_pwndbg/
#chmod -R +w ./src/gdb_for_pwndbg/_vendor
cp -rf $GDB_DIR/share/gdb/python/gdb/ ./src/
chmod -R +w ./src/

python3 setup.py bdist_wheel
mv dist/*.whl dist/gdb_for_pwndbg-16.2.0-cp$PY_VERSION-cp$PY_VERSION-manylinux_2_28_aarch64.whl

# auditwheel usuwa libpythona z zaleznosci
#uvx auditwheel repair dist/*.whl --plat manylinux_2_28_aarch64 -w dist/
# uvx twine upload dist/gdb_for_pwndbg-16.2.0-cp312-cp312-manylinux_2_28_aarch64.whl