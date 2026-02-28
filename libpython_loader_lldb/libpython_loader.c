/*
 * libpython_loader.so / libpython_loader.dylib
 *
 * A tiny shim that reads LLDB_LIBPYTHON from the environment and dlopen's the
 * real libpython with RTLD_GLOBAL before any Python C API is called.
 *
 * This allows a single lldb binary to work with any Python version (3.10,
 * 3.11, 3.12, 3.13, 3.14t, 3.13d, ...) without being linked to a specific
 * libpython at build time.
 *
 * The lldb-for-pwndbg Python wrapper (lldb.py) sets PYTHONLOADER_LIBPYTHON to the
 * exact path of the system libpython before exec'ing the lldb binary.
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

__attribute__((constructor))
static void libpython_loader_init(void) {
    const char *path = getenv("PYTHONLOADER_LIBPYTHON");
    if (!path) {
        fprintf(stderr,
            "[lldb-for-pwndbg] ERROR: PYTHONLOADER_LIBPYTHON is not set.\n"
            "  Run lldb via the Python wrapper (pip-installed 'lldb' command),\n"
            "  not by invoking the bundled binary directly.\n");
        _exit(1);
    }

    void *handle = dlopen(path, RTLD_GLOBAL | RTLD_LAZY);
    if (!handle) {
        fprintf(stderr,
            "[lldb-for-pwndbg] ERROR: failed to load libpython from '%s': %s\n",
            path, dlerror());
        _exit(1);
    }

    // TODO: dlopen path
    /* Now load _lldb.abi3.so (= liblldb) with RTLD_NOW so its Python
     * GLOB_DAT relocations (_Py_NoneStruct etc.) are resolved eagerly
     * against the libpython we just loaded into RTLD_GLOBAL. */
    void *lldb_handle = dlopen("_lldb.abi3.so", RTLD_GLOBAL | RTLD_NOW);
    if (!lldb_handle) {
        fprintf(stderr,
            "[lldb-for-pwndbg] ERROR: failed to load _lldb.abi3.so: %s\n",
            dlerror());
        _exit(1);
    }
}
