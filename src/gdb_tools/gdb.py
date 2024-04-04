import sys
import os
import subprocess
import pathlib
from glob import glob
from sysconfig import get_config_var
try:
    import ctypes
except ImportError:
    raise NotImplementedError('[error] python is static compiled')


here = pathlib.Path(__file__).parent.resolve()
gdb_path = here / pathlib.Path('_vendor/exe/gdb')


def parse_ld_conf_file(fn):
    paths = []
    for line in open(fn).read().splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("#"):
            continue
        if line.startswith("include "):
            for sub_fn in glob(line[len("include "):]):
                paths.extend(parse_ld_conf_file(sub_fn))
            continue
        paths.append(line)
    return paths


def get_ld_paths():
    # To be very correct, see man-page of ld.so.
    # And here: http://unix.stackexchange.com/questions/354295/what-is-the-default-value-of-ld-library-path/354296
    # Short version, not specific to an executable, in this order:
    # - LD_LIBRARY_PATH
    # - /etc/ld.so.cache (instead we will parse /etc/ld.so.conf)
    # - /lib, /usr/lib (or maybe /lib64, /usr/lib64)
    LDPATH = os.getenv("LD_LIBRARY_PATH")
    PREFIX = os.getenv("PREFIX")
    paths = []
    if LDPATH:
        paths.extend(LDPATH.split(":"))
    if os.path.exists("/etc/ld.so.conf"):
        paths.extend(parse_ld_conf_file("/etc/ld.so.conf"))
    else:
        raise ValueError('WARNING: file "/etc/ld.so.conf" not found.')

    if PREFIX:
        if os.path.exists(PREFIX + "/etc/ld.so.conf"):
            paths.extend(parse_ld_conf_file(PREFIX + "/etc/ld.so.conf"))
        else:
            raise ValueError('WARNING: file "' + PREFIX + '/etc/ld.so.conf" not found.')
        paths.extend([PREFIX + "/lib", PREFIX + "/usr/lib", PREFIX + "/lib64", PREFIX + "/usr/lib64"])

    paths.extend(["/lib", "/usr/lib", "/lib64", "/usr/lib64"])
    return paths


def check_lib_python():
    libpython_name = pathlib.Path(get_config_var("INSTSONAME"))
    libpython_dir = pathlib.Path(get_config_var("LIBDIR"))
    if (libpython_dir / libpython_name).exists():
        return True

    for path in get_ld_paths():
        if (pathlib.Path(path) / libpython_name).exists():
            return True

    raise NotImplementedError(f'[error] missing libpython. Please install python3-dev or python3-devel')


def main():
    check_lib_python()

    envs = os.environ.copy()
    envs['PYTHONPATH'] = ':'.join(sys.path)
    # envs['PYTHONHOME'] = sys.prefix + ':' + sys.exec_prefix # TODO: check pythonhome issues (site.main())
    envs['PYTHONHOME'] = '/usr' + ':' + '/usr'

    os.execve(str(gdb_path), [str(gdb_path)] + sys.argv[1:], env=envs)
