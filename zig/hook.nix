{
  lib,
  makeSetupHook,
  zig,
  stdenv,
  xcbuild,
}:

makeSetupHook {
  name = "zig-hook";

  propagatedBuildInputs = [
    zig
  ]
  # while xcrun is already included in the darwin stdenv, Zig also needs
  # xcode-select (provided by xcbuild) for SDK detection
  ++ lib.optionals stdenv.hostPlatform.isDarwin [ xcbuild ];

  substitutions = {
    # This zig_default_flags below is meant to avoid CPU feature impurity in
    # Nixpkgs. However, this flagset is "unstable": it is specifically meant to
    # be controlled by the upstream development team - being up to that team
    # exposing or not that flags to the outside (especially the package manager
    # teams).

    # Because of this hurdle, @andrewrk from Zig Software Foundation proposed
    # some solutions for this issue. Hopefully they will be implemented in
    # future releases of Zig. When this happens, this flagset should be
    # revisited accordingly.

    # Below are some useful links describing the discovery process of this 'bug'
    # in Nixpkgs:

    # https://github.com/NixOS/nixpkgs/issues/169461
    # https://github.com/NixOS/nixpkgs/issues/185644
    # https://github.com/NixOS/nixpkgs/pull/197046
    # https://github.com/NixOS/nixpkgs/pull/241741#issuecomment-1624227485
    # https://github.com/ziglang/zig/issues/14281#issuecomment-1624220653

    zig_default_flags =
      let
        releaseType =
          if lib.versionAtLeast zig.version "0.12" then
            "--release=safe"
          else if lib.versionAtLeast zig.version "0.11" then
            "-Doptimize=ReleaseSafe"
          else
            "-Drelease-safe=true";

        glibcVersion = if stdenv.targetPlatform.isLoongArch64 then ".2.36" else ".2.28";
        muslVersion = if stdenv.targetPlatform.isLoongArch64 then "" else "";
        abiVersion =
          if stdenv.targetPlatform.isGnu then
            glibcVersion
          else if stdenv.targetPlatform.isMusl then
            muslVersion
          else
            (throw "not supported abi version ${stdenv.targetPlatform.parsed.abi.name}");

        target =
          if stdenv.targetPlatform.isLinux && stdenv.targetPlatform.is32bit then
            "-Dtarget=${stdenv.targetPlatform.parsed.cpu.family}-linux-${stdenv.targetPlatform.parsed.abi.name}${abiVersion}"
          else if stdenv.targetPlatform.isLinux then
            "-Dtarget=${stdenv.targetPlatform.parsed.cpu.name}-linux-${stdenv.targetPlatform.parsed.abi.name}${abiVersion}"
          else if stdenv.targetPlatform.isDarwin then
            "-Dtarget=${stdenv.targetPlatform.parsed.cpu.name}-macos.${stdenv.targetPlatform.darwinSdkVersion}"
          else
            (throw "not supported target");
      in
      [
        "-Dcpu=baseline"
        releaseType
        target
      ];
  };

  passthru = { inherit zig; };

  meta = {
    description = "Setup hook for using the Zig compiler in Nixpkgs";
    inherit (zig.meta) maintainers platforms broken;
  };
} ./setup-hook.sh
