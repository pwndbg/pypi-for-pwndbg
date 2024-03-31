from setuptools import setup
from setuptools.command.install import install
import subprocess
import shutil
import os
from setuptools import setup, find_packages
import pathlib

here = pathlib.Path(__file__).parent.resolve()

# python setup.py bdist_wheel

# class CustomInstall(install):
#     def run(self):
#         # Download and build GDB
#         # Customize this part according to where GDB source is hosted, and build steps
#         subprocess.run(["wget", "http://path/to/gdb/source.tar.gz"])
#         subprocess.run(["tar", "-xzf", "source.tar.gz"])
#         os.chdir("gdb-source-directory")
#         subprocess.run(["./configure"])
#         subprocess.run(["make"])
#
#         # Vendor GDB installation
#         shutil.copytree("gdb-source-directory", "your_package/gdb")
#
#         # Continue with the installation
#         install.run(self)
#

# setup(
#     name='your_package_name',
#     version='1.0.0',
#     packages=find_packages(),
#     package_data={'': ['vendor/gdb/*']},
#     include_package_data=True,
#     install_requires=[
#         # list your dependencies here
#     ],
# )
# setup(
#     cmdclass = {'install': CustomInstall},
#     install_requires = [
#         # Include any other dependencies your package has
#         # "gdb",
#     ],
# )

setup(
    name="pwndbg-gdb",
    version="14.2.1",
    url="https://github.com/pwndbg/pwndbg-gdb",

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

    python_requires=">=3.8, <4",
    # If there are data files included in your packages that need to be
    # installed, specify them here.
    # package_data={
    #     "vendor": ["src/gdb_tools/vendor/"],
    # },
    # Entry points. The following would provide a command called `sample` which
    # executes the function `main` from this package when invoked:
    entry_points={
        "console_scripts": [
            "gdb=gdb_tools.gdb:main",
        ],
    },
    project_urls={
        "Bug Reports": "https://github.com/pwndbg/pwndbg/issues",
        "Source": "https://github.com/pwndbg/pwndbg-gdb/",
    },
)
