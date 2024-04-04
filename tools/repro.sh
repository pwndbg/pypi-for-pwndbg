#!/usr/bin/env bash
set -ex

DEBIAN_FRONTEND=noninteractive apt update -y || true
DEBIAN_FRONTEND=noninteractive apt install -y curl git python3 python3-dev python3-venv || true
dnf install -y git python3 python3-devel || true
dnf install -y curl || true

PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}{sys.version_info.minor}', end='')")

python3 -m venv /tmp/venv/
/tmp/venv/bin/pip install -U pip

WHEEL_FILE=pwndbg_gdb-14.2.1-cp$PY_VER-cp$PY_VER-manylinux_2_28_x86_64.whl
curl --output /tmp/venv/$WHEEL_FILE -L https://github.com/pwndbg/pwndbg-gdb/raw/main/pypidist/$WHEEL_FILE
/tmp/venv/bin/pip install --force-reinstall /tmp/venv/$WHEEL_FILE
/tmp/venv/bin/pip install git+https://github.com/pwndbg/pwndbg

touch /tmp/venv/.skip-venv

curl --output /tmp/venv/gdbinit.py -L https://raw.githubusercontent.com/pwndbg/pwndbg/dev/gdbinit.py
/tmp/venv/bin/gdb -q -ex 'source /tmp/venv/gdbinit.py'
