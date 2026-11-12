{
  lib,
  runCommand,
  zig,
  stdenv,
  makeWrapper,
}:
let
  targetPrefix = lib.optionalString (
    stdenv.hostPlatform != stdenv.targetPlatform
  ) "${stdenv.targetPlatform.config}-";
in
runCommand "zig-cc-${zig.version}"
  {
    pname = "zig-cc";
    inherit (zig) version meta;

    nativeBuildInputs = [
      makeWrapper
    ];

    passthru = {
      isZig = true;
      inherit targetPrefix;

      # Read by cc-wrapper (with the wrapper's targetPlatform) to drop hardening flags
      # zig's clang rejects for that target; same idea as nixpkgs' clang.
      hardeningUnsupportedFlagsByTargetPlatform =
        targetPlatform:
        lib.optional (!(targetPlatform.isx86_64 || targetPlatform.isAarch64)) "zerocallusedregs"
        ++ lib.optional (targetPlatform.isLoongArch64 || targetPlatform.isAarch32) "stackclashprotection";
    };

    inherit zig;
  }
  ''
    mkdir -p $out/bin
    for tool in cc c++ ld.lld; do
      makeWrapper "$zig/bin/zig" "$out/bin/$tool" \
        --add-flags "$tool" \
        --run "export ZIG_GLOBAL_CACHE_DIR=\$TMPDIR"
    done

    ln -s $out/bin/c++ $out/bin/clang++
    ln -s $out/bin/cc $out/bin/clang
    ln -s $out/bin/ld.lld $out/bin/ld
  ''
