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
#include <string.h>
#include <limits.h>

__attribute__((constructor))
static void libpython_loader_init(void) {
    Dl_info info;
    if (!dladdr((void*)libpython_loader_init, &info) || !info.dli_fname) {
        fprintf(stderr, "[lldb-for-pwndbg] ERROR: dladdr failed\n");
        _exit(1);
    }
    char loader_dir[PATH_MAX];
    strncpy(loader_dir, info.dli_fname, PATH_MAX - 1);
    loader_dir[PATH_MAX - 1] = '\0';

    char *slash = strrchr(loader_dir, '/');
    if (slash) {
        *slash = '\0';
    } else {
        strncpy(loader_dir, ".", PATH_MAX - 1);
    }

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

    /* Now load _lldb.abi3.so (= liblldb) with RTLD_NOW so its Python
     * GLOB_DAT relocations (_Py_NoneStruct etc.) are resolved eagerly
     * against the libpython we just loaded into RTLD_GLOBAL.
    */
    char lldb_so_path[PATH_MAX];
    int written = snprintf(lldb_so_path, PATH_MAX, "%s/../../../lldb/native/_lldb.abi3.so", loader_dir);
    if (written < 0 || written >= PATH_MAX) {
        fprintf(stderr, "[lldb-for-pwndbg] ERROR: path too long\n");
        _exit(1);
    }

    void *lldb_handle = dlopen(lldb_so_path, RTLD_GLOBAL | RTLD_NOW);
    if (!lldb_handle) {
        fprintf(stderr,
            "[lldb-for-pwndbg] ERROR: failed to load _lldb.abi3.so: %s\n",
            dlerror());
        _exit(1);
    }
}
