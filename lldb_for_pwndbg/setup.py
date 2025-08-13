from setuptools import setup
from setuptools.command.install import install
import subprocess
import shutil
import os
from setuptools import setup, find_packages
import pathlib

here = pathlib.Path(__file__).parent.resolve()

setup(
    name="lldb-for-pwndbg",
    version="20.1.8",
    url="https://github.com/pwndbg/pypi-for-pwndbg",

    package_dir={"": "src"},  # Optional

    packages=find_packages(where="src"),  # Required
    include_package_data=True,

    python_requires=">=3.10, <4",
    entry_points={
        "console_scripts": [
            "lldb=lldb_for_pwndbg.lldb:main",
            "lldb-server=lldb_for_pwndbg.lldb_server:main",
        ],
    },
    project_urls={
        "Bug Reports": "https://github.com/pwndbg/pypi-for-pwndbg/issues",
        "Source": "https://github.com/pwndbg/pypi-for-pwndbg/",
    },
)
