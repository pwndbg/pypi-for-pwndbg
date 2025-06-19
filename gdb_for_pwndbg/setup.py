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
    version="16.2.5",
    url="https://github.com/pwndbg/pypi-for-pwndbg",

    package_dir={"": "src"},  # Optional

    packages=find_packages(where="src"),  # Required
    include_package_data=True,

    python_requires=">=3.10, <4",

    entry_points={
        "console_scripts": [
            "gdb=gdb_for_pwndbg.gdb:main",
        ],
    },
    project_urls={
        "Bug Reports": "https://github.com/pwndbg/pypi-for-pwndbg/issues",
        "Source": "https://github.com/pwndbg/pypi-for-pwndbg/",
    },
)
