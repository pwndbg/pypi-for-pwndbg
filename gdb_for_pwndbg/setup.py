from setuptools import setup
from setuptools.command.install import install
import subprocess
import shutil
import os
from setuptools import setup, find_packages
import pathlib

here = pathlib.Path(__file__).parent.resolve()

setup(
    name="gdb-for-pwndbg",
    version="@version@",
    url="https://github.com/pwndbg/pypi-for-pwndbg",
    description="Prebuilt GDB binaries for Pwndbg, ensuring reliable debugger integration, autocompletion, and IDE support.",

    package_dir={"": "src"},  # Optional

    packages=find_packages(where="src"),  # Required
    include_package_data=True,

    python_requires=">=3.10, <4",

    entry_points={
        "console_scripts": [
            "gdb=gdb_for_pwndbg.gdb:main",
            "gdbserver=gdb_for_pwndbg.gdbserver:main",
        ],
    },
    project_urls={
        "Bug Reports": "https://github.com/pwndbg/pypi-for-pwndbg/issues",
        "Source": "https://github.com/pwndbg/pypi-for-pwndbg/",
    },
)
