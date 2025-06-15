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
    version="16.2.0",
    url="https://github.com/pwndbg/gdb-for-pwndbg",

    # When your source code is in a subdirectory under the project root, e.g.
    # `src/`, it is necessary to specify the `package_dir` argument.
    package_dir={"": "src"},  # Optional
    # You can just specify package directories manually here if your project is
    # simple. Or you can use find_packages().
    #
    # Alternatively, if you just want to distribute a single Python file, use
    # the `py_modules` argument instead as follows, which will expect a file
    # called `my_module.py` to exist:
    #
    #   py_modules=["my_module"],
    #
    packages=find_packages(where="src"),  # Required
    include_package_data=True,

    python_requires=">=3.10, <4",
    # If there are data files included in your packages that need to be
    # installed, specify them here.
    # package_data={
    #     "vendor": ["src/gdb_tools/vendor/"],
    # },
    # Entry points. The following would provide a command called `sample` which
    # executes the function `main` from this package when invoked:
    entry_points={
        "console_scripts": [
            "gdb=gdb_for_pwndbg.gdb:main",
        ],
    },
    project_urls={
        "Bug Reports": "https://github.com/pwndbg/gdb-for-pwndbg/issues",
        "Source": "https://github.com/pwndbg/gdb-for-pwndbg/",
    },
)
