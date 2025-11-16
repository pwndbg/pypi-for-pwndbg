{
  lib,
  runCommand,
  zig,
  stdenv,
  makeWrapper,
  python3,
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
    ]
    ++ lib.optionals stdenv.targetPlatform.isLoongArch64 [
      python3
    ];

    passthru = {
      isZig = true;
      inherit targetPrefix;
    };

    inherit zig;
  }
  (
    if stdenv.targetPlatform.isLoongArch64 then
      ''
        mkdir -p $out/bin

        cp ${./zig_wrapper.py} $out/bin/.zig-wrapper
        chmod +x $out/bin/.zig-wrapper
        patchShebangs $out/bin/.zig-wrapper
        substituteInPlace $out/bin/.zig-wrapper \
          --replace-fail '@zig@' "$zig/bin/zig"

        for tool in ld.lld; do
          makeWrapper "$zig/bin/zig" "$out/bin/$tool" \
            --add-flags "$tool" \
            --run "export ZIG_GLOBAL_CACHE_DIR=\$TMPDIR"
        done

        for tool in cc c++; do
          makeWrapper "$out/bin/.zig-wrapper" "$out/bin/$tool" \
            --add-flags "$tool" \
            --run "export ZIG_GLOBAL_CACHE_DIR=\$TMPDIR"
        done

        ln -s $out/bin/c++ $out/bin/clang++
        ln -s $out/bin/cc $out/bin/clang
        ln -s $out/bin/ld.lld $out/bin/ld
      ''
    else
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
  )
