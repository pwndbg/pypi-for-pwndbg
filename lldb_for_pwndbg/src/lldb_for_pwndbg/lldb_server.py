import sys
import os
import subprocess
import pathlib
from glob import glob
from sysconfig import get_config_var


here = pathlib.Path(__file__).parent.resolve()
lldb_server_path = here / pathlib.Path('_vendor/bin/lldb-server')


def main():
    if sys.platform == "darwin":
        print("lldb-server is not supported on macOS. Use Apple's 'debugserver' instead.")
        os._exit(1)

    envs = os.environ.copy()
    os.execve(str(lldb_server_path), sys.argv, env=envs)

if __name__ == '__main__':
    main()
