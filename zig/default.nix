# Zig toolchain (cc/bintools wrappers + stdenv) around a prebuilt `zig` binary
# (from zig-overlay, see flake.nix). Called from `buildPackages`, so `stdenv.targetPlatform`
# is the platform the wrapped compiler emits code for.
{
  lib,
  stdenv,
  callPackage,
  wrapCCWith,
  wrapBintoolsWith,
  overrideCC,
  zig,
}:
let
  inherit (stdenv) targetPlatform;

  glibcVersion =
    if targetPlatform.isLoongArch64 then
      ".2.36"
    # zig >= 0.16 forces IEEE 128-bit `long double` on PowerPC (`-mabi=ieeelongdouble`), whose
    # `__*ieee128` functions (printf & co.) glibc only has since 2.32
    else if targetPlatform.isPower64 then
      ".2.32"
    else
      ".2.28";
  abiVersion =
    if targetPlatform.isGnu then
      glibcVersion
    else if targetPlatform.isMusl then
      ""
    else
      throw "not supported abi version ${targetPlatform.parsed.abi.name}";

  target =
    if targetPlatform.isLinux && targetPlatform.is32bit then
      "${targetPlatform.parsed.cpu.family}-linux-${targetPlatform.parsed.abi.name}${abiVersion}"
    else if targetPlatform.isLinux then
      "${targetPlatform.parsed.cpu.name}-linux-${targetPlatform.parsed.abi.name}${abiVersion}"
    else if targetPlatform.isDarwin then
      "${targetPlatform.parsed.cpu.name}-macos.${targetPlatform.darwinSdkVersion}"
    else
      throw "not supported target";

  bintools = wrapBintoolsWith { bintools = callPackage ./bintools.nix { inherit zig; }; };

  cc = wrapCCWith {
    cc = callPackage ./cc.nix { inherit zig; };
    inherit bintools;
    extraPackages = [ ];
    nixSupport.cc-cflags = [
      "-target"
      target
    ];
  };
in
{
  inherit zig bintools cc;
  stdenv = overrideCC stdenv cc;
}
