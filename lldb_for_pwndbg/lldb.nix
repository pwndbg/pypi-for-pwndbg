{
  lib,
  stdenv,
  buildPackages,
  pkgsBuildHost,

  version,
  pypiVersion,
  monorepoSrc ? null,
  patches ? [ ],

  cmake,
  ninja,
  which,
  swig,

  # buildInputs:
  libedit-static,
  zlib-static,
  zstd-static,
  xz-static,
  ncurses-static,
  libxml2-static,
  libclang_rt_ppc_builtins,
  libcurl-static,

  libcxx,
  python3,
  pkg-config,
}:
let
  tblgen = pkgsBuildHost.callPackage ./tblgen.nix {
    inherit version monorepoSrc;
  };

  isCross = stdenv.buildPlatform != stdenv.targetPlatform;

  # For macos we use normal llvm compiler
  # For linux we need zig + forced glibc==2.28
  stdenvOver = if stdenv.targetPlatform.isLinux then buildPackages.zig_glibc_2_28.stdenv else stdenv;
in
stdenvOver.mkDerivation (finalAttrs: {
  pname = "lldb";
  inherit version;

  src = monorepoSrc;
  strictDeps = true;

  enableParallelBuilding = true;

  # this option break alot of cross build..
  hardeningDisable =
    lib.optionals (stdenv.targetPlatform.isLinux && isCross) [
      "zerocallusedregs"
    ]
    ++ lib.optionals (stdenv.targetPlatform.isLoongArch64 || stdenv.targetPlatform.isAarch32) [
      "stackclashprotection"
    ];

  passthru = {
    pythonVersion = python3.pythonVersion;
    python = python3;
    pypiVersion = pypiVersion;
  };

  patches = [
    # temporary fix for: https://github.com/llvm/llvm-project/issues/155692
    ./patches/fix-apple-memory-mapping.patch
    ./patches/enable-debuginfod.patch
    ./patches/debuginfod-user-agent.patch
    ./patches/debuginfod-source-download.patch

    # Use pkg-config for curl to get transitive deps (openssl, nghttp2, etc.)
    ./patches/debuginfod-pkgconfig-curl.patch

    # todo: upstream changes?
    ./patches/lldb-fix-cross-python.patch
  ]
  ++ patches;

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
    pkg-config
  ];

  # since py3.14 probably this is required for cross compilation
  env._PYTHON_PROJECT_BASE = "${python3}";

  env.LDFLAGS = builtins.concatStringsSep " " (
    lib.optionals stdenv.targetPlatform.isDarwin [
      # Force static linking libc++ on Darwin, see: https://github.com/llvm/llvm-project/issues/76945#issuecomment-2002557889
      "-nostdlib++"
      "-Wl,${libcxx}/lib/libc++.a,${libcxx}/lib/libc++abi.a"
    ]
    ++ lib.optionals stdenv.targetPlatform.isPower64 [
      "-L${libclang_rt_ppc_builtins}/lib"
      "-lclang_rt_ppc_builtins"
    ]
  );

  buildInputs = [
    zlib-static
    zstd-static
    xz-static
    ncurses-static
    libxml2-static
    libedit-static
    libcurl-static
    python3
  ];

  cmakeFlags = [
    (lib.cmakeFeature "LLVM_HOST_TRIPLE" "${stdenv.targetPlatform.config}")

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

    # curl is needed for debuginfod, https://github.com/llvm/llvm-project/pull/70996
    # FORCE_ON makes cmake error out if curl is not found (vs silently disabling it).
    (lib.cmakeFeature "LLVM_ENABLE_CURL" "FORCE_ON")

    (lib.cmakeFeature "Python3_EXECUTABLE" "${python3.pythonOnBuildForHost.interpreter}")
    (lib.cmakeFeature "Python3_INCLUDE_DIR" "${python3}/include/python${python3.pythonVersion}")
    (lib.cmakeFeature "Python3_LIBRARY" "${python3}/lib/libpython${python3.pythonVersion}${stdenv.targetPlatform.extensions.library}")
  ]
  ++ lib.optionals stdenv.targetPlatform.isDarwin [
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
