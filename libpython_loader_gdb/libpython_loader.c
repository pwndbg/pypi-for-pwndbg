/*
 * libpython_loader.so / libpython_loader.dylib
 *
 * A tiny shim that reads PYTHONLOADER_LIBPYTHON from the environment and dlopen's the
 * real libpython with RTLD_GLOBAL before any Python C API is called.
 *
 * This allows a single gdb binary to work with any Python version (3.10,
 * 3.11, 3.12, 3.13, 3.14t, 3.13d, ...) without being linked to a specific
 * libpython at build time.
 *
 * The gdb-for-pwndbg Python wrapper (gdb.py) sets PYTHONLOADER_LIBPYTHON to the
 * exact path of the system libpython before exec'ing the gdb binary.
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

__attribute__((constructor))
static void libpython_loader_init(void) {
     fprintf(stderr, "start loading...");

    const char *path = getenv("PYTHONLOADER_LIBPYTHON");
    if (!path) {
        fprintf(stderr,
            "[gdb-for-pwndbg] ERROR: PYTHONLOADER_LIBPYTHON is not set.\n"
            "  Run gdb via the Python wrapper (pip-installed 'gdb' command),\n"
            "  not by invoking the bundled binary directly.\n");
        _exit(1);
    }

    void *handle = dlopen(path, RTLD_GLOBAL | RTLD_LAZY);
    if (!handle) {
        fprintf(stderr,
            "[gdb-for-pwndbg] ERROR: failed to load libpython from '%s': %s\n",
            path, dlerror());
        _exit(1);
    }
}
