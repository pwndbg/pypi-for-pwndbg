import sys
import os
import subprocess
import pathlib
from glob import glob
from sysconfig import get_config_var


here = pathlib.Path(__file__).parent.resolve()
lldb_server_path = here / pathlib.Path('_vendor/bin/lldb-server')


def main():
    envs = os.environ.copy()
    os.execve(str(lldb_server_path), sys.argv, env=envs)

if __name__ == '__main__':
    main()
