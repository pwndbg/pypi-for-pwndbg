# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repo builds **prebuilt GDB and LLDB binaries** packaged as Python wheels (`gdb-for-pwndbg`, `lldb-for-pwndbg`) for use with Pwndbg. The wheels bundle the debugger binaries with reliable Python integration across a wide range of Linux distros and macOS.

## Build System

All builds are driven by **Nix flakes** (`flake.nix`). You need Nix with flakes enabled.

### Key Nix attributes

```
# Stable builds
wheel-gdb-for-pwndbg.<py_version>        # e.g. .312
wheel-lldb-for-pwndbg.<py_version>

# Dev builds (from upstream git)
wheel-gdb_dev-for-pwndbg.<py_version>
wheel-lldb_dev-for-pwndbg.<py_version>
```

`<py_version>` is one of `310 311 312 313 314 315` (see `pythonVersions` in `flake.nix`).

**Important — GDB is per-Python, LLDB is not.** GDB wheels are tagged for a specific CPython ABI (`cp312-...`), so you build one wheel per Python version. LLDB wheels are built as a single **`abi3`** wheel that works across all Python versions at runtime (see the loader-shim mechanism below). The LLDB attributes still take a `<py_version>` because the *build* links against a concrete libpython, but the produced wheel is Python-version-agnostic.

### Build commands

```bash
# Build a GDB wheel for Python 3.12
nix build '.#wheel-gdb-for-pwndbg.312'

# Build with a debug tarball (includes unstripped binary)
nix build '.#wheel-gdb-for-pwndbg.312.debug'

# Build LLDB wheel for Python 3.13
nix build '.#wheel-lldb-for-pwndbg.313'

# Build a GDB for Python 3.12
nix build '.#gdb-for-pwndbg.312'

# Build a LLDB for Python 3.12
nix build '.#lldb-for-pwndbg.312'

# Format Nix files
nix fmt
```

For cross-compilation (Linux targets built on aarch64):
```bash
nix build '.#packages.aarch64-linux.pkgsCross.gnu64.wheel-gdb-for-pwndbg.312'
```

## Tests

Tests use pytest + Docker to verify installed wheels on real distro images:

```bash
pytest -vvv tests/test_images.py
# Run single distro test:
pytest -vvv tests/test_images.py -k "ubuntu_22.04"
```

## Versioning and Releases

Version format: `{upstream_version}.post{N}` (stable) or `{upstream_version}.dev{YYMMDD}` (dev).

Releases are triggered by pushing git tags:
- `gdb-*` → publishes `gdb-for-pwndbg` stable
- `lldb-*` → publishes `lldb-for-pwndbg` stable
- `gdb_dev-*` → publishes `gdb-for-pwndbg` dev build
- `lldb_dev-*` → publishes `lldb-for-pwndbg` dev build

## Architecture

### Build pipeline per package

1. **`gdb_for_pwndbg/gdb.nix`** / **`lldb_for_pwndbg/lldb.nix`**: Builds the debugger binary from source.
   - On **Linux**: uses Zig as CC (via `zig/`) to enforce glibc 2.28 compatibility; links all dependencies statically except glibc itself. All the `*-static` dependencies (ncurses, libxml2, openssl, curl, expat, libedit, …) are defined in the `overlay` in `flake.nix`, each rebuilt with the zig glibc 2.28 stdenv.
   - On **macOS**: uses normal LLVM/clang.
   - **LLDB** is built so libpython is *not* hard-linked: on Linux it links with `-Wl,-z,lazy` and replaces the `liblldb.so` NEEDED entry, on macOS it links against `libpython_stub` with `-flat_namespace -undefined dynamic_lookup`. The real libpython is supplied at runtime by the loader shim (see below). This is what makes the single `abi3` wheel work across Python versions.

2. **`gdb_for_pwndbg/wheel.nix`** / **`lldb_for_pwndbg/wheel.nix`**: Wraps the built binary into a Python wheel.
   - Copies the binary into `src/<pkg>/_vendor/bin/`.
   - **GDB**: uses `patchelf`/`install_name_tool` to point at `libpython` resolved from the venv's `lib/` directory (`$ORIGIN/../../../../../../lib`, 6 levels up in the installed wheel path).
   - **LLDB**: bundles `libpython_loader_lldb` + `liblldb_stub` (Linux) or `libpython_stub` (macOS) into `_vendor/lib/` and patches the binary to `--add-needed`/replace-needed the loader shim instead of a concrete libpython. Emits an `abi3` wheel (`...-<minpy>-abi3-...`).
   - Strips Nix store references with `nuke-refs`.
   - Runs `verify.py` to assert no forbidden dynamic dependencies remain.
   - Calls `python3 setup.py bdist_wheel` to produce the `.whl`.

3. **Entry points** (console scripts declared in each `setup.py`):
   - `gdb` → `gdb_for_pwndbg/src/gdb_for_pwndbg/gdb.py`, `gdbserver` → `gdbserver.py`
   - `lldb` → `lldb_for_pwndbg/src/lldb_for_pwndbg/lldb.py`, `lldb-server` → `lldb_server.py`
   - All set `PYTHONPATH`/`PYTHONHOME`/`PYTHONNOUSERSITE` from the current interpreter, then `os.execve` the bundled binary. On Linux they resolve the dynamic loader from `/proc/self/maps` (per-arch table) and invoke it explicitly, because the binary's interpreter was patched out.
   - **GDB** (`gdb.py`): symlinks `libpython*.so/.dylib` into the venv's `lib/` if missing (`check_lib_python`), and injects `--data-directory`.
   - **LLDB** (`lldb.py`): finds the current `libpython` and exports its path as `PYTHONLOADER_LIBPYTHON`, which the loader shim reads to `dlopen` it with `RTLD_GLOBAL` before any Python C API call. On Linux it also points `LLDB_DEBUGSERVER_PATH` at the bundled `lldb-server`.

### Loader-shim / stub directories (LLDB version-agnostic mechanism)

These tiny single-`.c` derivations (each with a `default.nix`) implement the "one LLDB binary, any Python" design:

- **`libpython_loader_lldb/`** / **`libpython_loader_gdb/`**: a shim with a `__attribute__((constructor))` that reads `PYTHONLOADER_LIBPYTHON` from the env and `dlopen`s the real libpython with `RTLD_GLOBAL` before Python is used. On Linux it then `dlopen`s `_lldb.abi3.so` with `RTLD_NOW` so its Python relocations resolve against that libpython.
- **`liblldb_stub/`**: an empty stub `.so`/`.dylib` (with a `version.map` matching the LLVM version) substituted in place of the real `liblldb` at link time so the `lldb` executable links without pulling in a concrete libpython transitively.
- **`libpython_stub/`**: an empty stub libpython used on macOS at link time (resolved later via `-flat_namespace`).

### `zig/` directory

Custom Nix derivations that create a Zig-based cross-compilation toolchain. Used as a drop-in stdenv to compile all static dependencies with glibc 2.28 as minimum.

### `verify.py` (in each package)

Sanity-checks the built binary's dynamic dependencies against a strict allowlist (only glibc system libraries + the correct `libpython`). Fails the Nix build if any unexpected `.so`/`.dylib` dependency is found.

### `gdb_for_pwndbg/patches/` / `lldb_for_pwndbg/patches/`

Source-level patches applied during the Nix build (cross-compilation fixes, color fixes, etc.).

## Updating Versions

To update upstream versions, edit `flake.nix`:
- `fun_gdb` / `fun_gdb_dev` for GDB
- `fun_lldb` / `fun_lldb_dev` for LLDB

Update `version`, `pypiVersion`, and the `src` hash (use `nix-prefetch-url` or `nix-prefetch-git`).

## Supported targets

- Linux glibc ≥ 2.28: x86_64, aarch64, s390x, powerpc64le, i686
- Linux glibc ≥ 2.31: armv7l · ≥ 2.36: loongarch64 · ≥ 2.39: riscv64
- macOS: x86_64, aarch64
- **Not** supported: linux-musl, Windows