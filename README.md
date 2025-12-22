## Why?

This package provides **prebuilt GDB and LLDB binaries with full and reliable Python integration**, intended for use with **Pwndbg**.

System GDB/LLDB builds often struggle with modern Python environments — they may be compiled against a different ABI, 
miss Python development support, or behave inconsistently across distributions. 
This makes debugging with Pwndbg unreliable, especially in virtual environments and IDEs.

The debugger binaries shipped in these wheels are built specifically to ensure:

- predictable and stable Python interoperability
- smooth loading and runtime of Pwndbg
- IDE autocompletion and code-intelligence features that rely on Python symbols

The goal is simple: **a zero-friction debugging experience with Pwndbg**, without worrying about system debugger compatibility.

## How to use

If you're using **uv**, you can run the debuggers directly from the packages without installing anything system-wide:

```bash
uvx --from gdb-for-pwndbg gdb
```
or for LLDB:
```bash
uvx --from lldb-for-pwndbg lldb
```

## Versioning
The package version follows the format:
`{upstream_version}.post{fix_number}`
where `post{fix_number}` indicates our patch or fix release.

**Examples:**
- **GDB**
  - Upstream: `GDB 17.1`
  - Package: `gdb-for-pwndbg==17.1.0.post1`  
    *(post1 = first custom fix)*
- **LLDB**
  - Upstream: `LLDB 21.1.7`
  - Package: `lldb-for-pwndbg==21.1.7.post1`  
    *(post1 = first custom fix)*


## What is supported:
- linux (glibc 2.28>=), x86_64, aarch64, s390x, powerpc64le, i686
- linux (glibc 2.31>=), armv7l
- linux (glibc 2.36>=), loongarch64
- linux (glibc 2.39>=), riscv64
- macos, x86_64, aarch64


## What is missing:
- linux-musl is not supported
- windows is not supported
