{
  lib,
  stdenv,
  stdenvNoCC,
  buildPackages,

  version,
  monorepoSrc ? null,

  cmake,
  ninja,
  which,
  swig,

  python3,

  pkgsBuildHost,
}:
let
  tblgen = pkgsBuildHost.callPackage ./tblgen.nix {
    inherit version monorepoSrc;
  };

  # For macos we use normal llvm compiler
  # For linux we need zig + forced glibc==2.28
  stdenvOver = if stdenv.hostPlatform.isLinux then buildPackages.zig_glibc_2_28.stdenv else stdenv;
in
stdenvOver.mkDerivation (finalAttrs: {
  pname = "lldb";
  inherit version;

  src = monorepoSrc;
  sourceRoot = "${finalAttrs.src.name}/llvm";
  enableParallelBuilding = true;
  strictDeps = true;

  passthru = {
    pythonVersion = python3.pythonVersion;
    python = python3;
  };

  # See: https://github.com/ziglang/zig-bootstrap/commit/451966c163c7a2e9769d62fd77585af1bc9aca4b
  # See: https://github.com/ziglang/zig/issues/18804#issue-2116892765
  postPatch = ''
    chmod +w ./../clang/tools/CMakeLists.txt
    chmod +w ./../clang/tools/
    sed -i 's@add_clang_subdirectory(clang-shlib)@@g' ./../clang/tools/CMakeLists.txt
  '';

  nativeBuildInputs =
    [
      cmake
      which
      swig
      ninja
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
    ];

  env.LDFLAGS = builtins.concatStringsSep " " (
    lib.optionals stdenv.hostPlatform.isDarwin [
      # Force static linking libc++ on Darwin, see: https://github.com/llvm/llvm-project/issues/76945#issuecomment-2002557889
      "-nostdlib++"
      "-Wl,${stdenv.cc.libcxx}/lib/libc++.a,${stdenv.cc.libcxx}/lib/libc++abi.a"
    ]
  );

  buildInputs = [
  ];

  cmakeFlags =
    [
      (lib.cmakeFeature "LLVM_TABLEGEN" "${tblgen}/bin/llvm-tblgen")
      (lib.cmakeFeature "CLANG_TABLEGEN" "${tblgen}/bin/clang-tblgen")
      (lib.cmakeFeature "LLDB_TABLEGEN_EXE" "${tblgen}/bin/lldb-tblgen")

      (lib.cmakeFeature "LLVM_ENABLE_PROJECTS" "clang;lldb")
      #    (lib.cmakeFeature "LLVM_TARGETS_TO_BUILD" "AArch64")
      # AArch64;AMDGPU;ARM;AVR;BPF;Hexagon;Lanai;LoongArch;Mips;MSP430;NVPTX;PowerPC;RISCV;Sparc;SPIRV;SystemZ;VE;WebAssembly;X86;XCore
      (lib.cmakeFeature "LLVM_EXPERIMENTAL_TARGETS_TO_BUILD" "M68k;Xtensa")
      # ARC;CSKY;DirectX;M68k;SPIRV;Xtensa

      (lib.cmakeBool "LLDB_INCLUDE_TESTS" false)
      (lib.cmakeBool "LLVM_INCLUDE_TESTS" false)
      (lib.cmakeBool "CLANG_INCLUDE_TESTS" false)
      (lib.cmakeBool "LLVM_INCLUDE_EXAMPLES" false)
      (lib.cmakeBool "LLVM_INCLUDE_BENCHMARKS" false)
      (lib.cmakeBool "LLVM_INCLUDE_DOCS" false)
      (lib.cmakeBool "LLVM_ENABLE_RTTI" false)
      (lib.cmakeBool "CLANG_ENABLE_STATIC_ANALYZER" false)
      (lib.cmakeBool "CLANG_ENABLE_ARCMT" false)
      (lib.cmakeBool "LLVM_BUILD_TOOLS" false)
      (lib.cmakeBool "LLVM_BUILD_UTILS" false)
      (lib.cmakeBool "LLVM_INCLUDE_UTILS" false)
      (lib.cmakeBool "LLVM_BUILD_RUNTIMES" false)
      (lib.cmakeBool "LLVM_INCLUDE_RUNTIMES" false)
      (lib.cmakeBool "LLVM_ENABLE_OCAMLDOC" false)
      (lib.cmakeBool "LLVM_ENABLE_BINDINGS" false)

      (lib.cmakeBool "LLVM_ENABLE_LTO" false)
      (lib.cmakeBool "LLDB_ENABLE_LUA" false)
      (lib.cmakeBool "LLDB_ENABLE_SWIG" true)
      (lib.cmakeBool "LLDB_ENABLE_PYTHON" true)

      (lib.cmakeFeature "Python3_EXECUTABLE" "${python3.pythonOnBuildForHost.interpreter}")
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      (lib.cmakeBool "LLDB_USE_SYSTEM_DEBUGSERVER" true)
    ];

  ninjaFlags = [
    "lldb"
    "lldb-server"
  ];

  installPhase = ''
    mkdir $out
    mv bin $out/
    mv lib $out/
  '';

  doCheck = false;
  dontStrip = true;
  dontFixup = true;
})
