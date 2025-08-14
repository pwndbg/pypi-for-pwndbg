
## Versioning
The package version follows the format:
`{upstream_version}.post{fix_number}`
where `post{fix_number}` indicates our patch or fix release.

**Examples:**
- **GDB**
  - Upstream: `GDB 16.3`
  - Package: `gdb-for-pwndbg==16.3.0.post1`  
    *(post1 = first custom fix)*
- **LLDB**
  - Upstream: `LLDB 20.1.8`
  - Package: `gdb-for-pwndbg==20.1.8.post1`  
    *(post1 = first custom fix)*


## What is supported:
- linux (glibc 2.28>=), x86_64, aarch64
- macos, x86_64, aarch64

## What is missing:
- debuginfod
- linux-musl is not supported
- windows is not supported
