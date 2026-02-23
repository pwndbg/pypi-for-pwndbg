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
   - On **Linux**: uses Zig as CC (via `zig/`) to enforce glibc 2.28 compatibility; links all dependencies statically except glibc itself.
   - On **macOS**: uses normal LLVM/clang; links libpython dynamically via `@executable_path`-relative rpath.

2. **`gdb_for_pwndbg/wheel.nix`** / **`lldb_for_pwndbg/wheel.nix`**: Wraps the built binary into a Python wheel.
   - Copies the binary into `src/<pkg>/_vendor/bin/`
   - Uses `patchelf` (Linux) or `install_name_tool` (macOS) to fix dynamic linker paths so `libpython` resolves from the venv's `lib/` directory (6 levels up in the wheel's installed path).
   - Strips Nix store references with `nuke-refs`.
   - Runs `verify.py` to assert no forbidden dynamic dependencies remain.
   - Calls `python3 setup.py bdist_wheel` to produce the `.whl`.

3. **`gdb_for_pwndbg/src/gdb_for_pwndbg/gdb.py`** / **`lldb_for_pwndbg/src/lldb_for_pwndbg/lldb.py`**: Python entry points (installed as `gdb`/`lldb` console scripts).
   - On startup: symlinks `libpython*.so/.dylib` into the venv's `lib/` if needed, sets `PYTHONPATH`/`PYTHONHOME`/`PYTHONNOUSERSITE`, then `os.execve`s the bundled binary.
   - On Linux: resolves the dynamic loader from `/proc/self/maps` and invokes it explicitly (needed for the patchelf'd binary to find the correct interpreter).

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