{
  lib,
  stdenv,
  stdenvNoCC,
  pkgsStatic,
  buildPackages,

  version,
  pypiVersion,
  monorepoSrc ? null,

  cmake,
  ninja,
  which,
  swig,
  libedit-static,
  libcxx,

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

  # Dynamic libiconv causes issues with our portable build.
  # It reads /some-path/lib/gconv/gconv-modules.d/gconv-modules-extra.conf,
  # then loads /some-path/lib/gconv/UTF-32.so dynamically.
  # libiconv is required by libxml2
  libxml2NonLinux = pkgsStatic.libxml2.overrideAttrs (old: {
    propagatedBuildInputs = [ pkgsStatic.libiconvReal ];
  });
  staticLibxml2 = if stdenv.hostPlatform.isLinux then pkgsStatic.libxml2 else libxml2NonLinux;
in
stdenvOver.mkDerivation (finalAttrs: {
  pname = "lldb";
  inherit version;

  src = monorepoSrc;
  strictDeps = true;

  enableParallelBuilding = true;

  # this option break alot of cross build..
  hardeningDisable = [ "zerocallusedregs" ];

  passthru = {
    pythonVersion = python3.pythonVersion;
    python = python3;
    pypiVersion = pypiVersion;
  };

  patches = [
    # temporary fix for: https://github.com/llvm/llvm-project/issues/155692
    ./patches/fix-apple-memory-mapping.patch

    # todo: upstream changes?
    ./patches/lldb-fix-cross-python.patch
  ];

  # See: https://github.com/ziglang/zig-bootstrap/commit/451966c163c7a2e9769d62fd77585af1bc9aca4b
  # See: https://github.com/ziglang/zig/issues/18804#issue-2116892765
  postPatch = ''
    chmod -R a+w ../
    sed -i 's@add_clang_subdirectory(clang-shlib)@@g' ./clang/tools/CMakeLists.txt

    # others steps must execute from llvm directory
    cd llvm;
  '';

  nativeBuildInputs = [
    cmake
    which
    swig
    ninja
  ];

  env.LDFLAGS = builtins.concatStringsSep " " (
    lib.optionals stdenv.hostPlatform.isDarwin [
      # Force static linking libc++ on Darwin, see: https://github.com/llvm/llvm-project/issues/76945#issuecomment-2002557889
      "-nostdlib++"
      "-Wl,${libcxx}/lib/libc++.a,${libcxx}/lib/libc++abi.a"
    ]
  );

  buildInputs = [
    pkgsStatic.zlib
    pkgsStatic.zstd
    pkgsStatic.xz
    pkgsStatic.ncurses
    staticLibxml2
    libedit-static
#    python3
  ];

  cmakeFlags = [
    (lib.cmakeFeature "LLVM_TABLEGEN" "${tblgen}/bin/llvm-tblgen")
    (lib.cmakeFeature "CLANG_TABLEGEN" "${tblgen}/bin/clang-tblgen")
    (lib.cmakeFeature "LLDB_TABLEGEN_EXE" "${tblgen}/bin/lldb-tblgen")

    (lib.cmakeFeature "LLVM_ENABLE_PROJECTS" "clang;lldb")
    # (lib.cmakeFeature "LLVM_TARGETS_TO_BUILD" "AArch64")
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

    # https://github.com/ziglang/zig/issues/22213#issuecomment-2540597445
    (lib.cmakeBool "CMAKE_C_LINKER_DEPFILE_SUPPORTED" false)
    (lib.cmakeBool "CMAKE_CXX_LINKER_DEPFILE_SUPPORTED" false)

    (lib.cmakeBool "LLVM_ENABLE_LTO" false)
    (lib.cmakeBool "LLDB_ENABLE_LUA" false)
    (lib.cmakeBool "LLDB_ENABLE_SWIG" true)
    (lib.cmakeBool "LLDB_ENABLE_PYTHON" true)

    # libc.so.6 Unable to initialize decompressor for section '.debug_abbrev'
    (lib.cmakeBool "LLVM_ENABLE_ZLIB" true)
    (lib.cmakeBool "LLVM_ENABLE_ZSTD" true)
    (lib.cmakeBool "LLDB_ENABLE_LZMA" true)

    (lib.cmakeBool "LLDB_ENABLE_LIBXML2" true)
    (lib.cmakeBool "LLDB_ENABLE_CURSES" true)
    (lib.cmakeBool "LLDB_ENABLE_LIBEDIT" true)

#    (lib.cmakeFeature "Python3_EXECUTABLE" "${python3.interpreter}")
    (lib.cmakeFeature "Python3_ROOT_DIR" "${python3}")
    (lib.cmakeFeature "Python3_EXECUTABLE_NATIVE" "${python3.pythonOnBuildForHost.interpreter}")
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
})
