{
  version,
  pypiVersion,
  src,

  lib,
  stdenv,
  targetPackages,
  pkgsBuildHost,

  # Build time
  fetchurl,
  pkg-config,
  texinfo,
  buildPackages,

  # buildInputs:
  libiconv-static,
  zlib-static,
  zstd-static,
  xz-static,
  expat-static,
  ncurses-static,
  gmp-static,
  mpfr-static,
  libipt-static,
  sourceHighlight-static,

  breakpointHook,
  python3,
  libcxx,
  bintools,
  libdebuginfod-zig-static,

  safePaths ? [
    # $debugdir:$datadir/auto-load are whitelisted by default by GDB
    "$debugdir"
    "$datadir/auto-load"
  ],
}:
let
  isCross = stdenv.buildPlatform != stdenv.targetPlatform;

  # For macos we use normal llvm compiler
  # For linux we need zig + forced glibc==2.28
  stdenvOver = if stdenv.targetPlatform.isLinux then buildPackages.zig_glibc_2_28.stdenv else stdenv;
in
stdenvOver.mkDerivation (finalAttrs: {
  pname = "gdb";
  inherit version src;

  patches = [
    ./patches/gdb-fix-cross-python.patch
    ./patches/enable-silent.patch
    ./patches/darwin-target-match.patch
    ./patches/enable-debuginfod.patch
  ];

  postPatch = lib.optionalString stdenv.targetPlatform.isDarwin ''
    substituteInPlace gdb/darwin-nat.c \
      --replace-fail '#include "bfd/mach-o.h"' '#include "mach-o.h"'

    #substituteInPlace libiberty/filedescriptor.c \
    #  --replace-fail '#include "bfd/mach-o.h"' '#include "mach-o.h"'
    #substituteInPlace libiberty/fibheap.c \
    #  --replace-fail '#include "bfd/mach-o.h"' '#include "mach-o.h"'
    # HAVE_LIMITS_H
  '';

  strictDeps = true;

  depsBuildBuild = [ buildPackages.stdenv.cc ];

  nativeBuildInputs = [
    pkg-config
    texinfo
    bintools
  ]
  ++ lib.optionals stdenv.targetPlatform.isDarwin [
  ];

  buildInputs = [
    gmp-static
    mpfr-static
    libipt-static
    sourceHighlight-static

    ncurses-static
    expat-static
    zlib-static
    zstd-static
    xz-static
    libdebuginfod-zig-static

    python3
  ];

  passthru = {
    pythonVersion = python3.pythonVersion;
    python = python3;
    pypiVersion = pypiVersion;
  };

  env.NIX_CFLAGS_COMPILE = builtins.concatStringsSep " " (
    [
      "-Wno-format-nonliteral"
    ]
    ++ lib.optionals stdenv.targetPlatform.isLinux [
      "-Wl,--build-id=sha1"
    ]
    ++ lib.optionals stdenv.targetPlatform.isDarwin [
    ]
  );

  env.CPPFLAGS = builtins.concatStringsSep " " ([
    "-I${libiconv-static}/include"
  ]);

  env.LDFLAGS = builtins.concatStringsSep " " (
    [
      "-L${libiconv-static}/lib"
    ]
    ++ lib.optionals stdenv.targetPlatform.isDarwin [
      # Force static linking libc++ on Darwin, see: https://github.com/llvm/llvm-project/issues/76945#issuecomment-2002557889
      "-nostdlib++"
      "-Wl,${libcxx}/lib/libc++.a,${libcxx}/lib/libc++abi.a"
    ]
  );

  preConfigure = ''
    mkdir _build
    cd _build
  '';
  configureScript = "../configure";

  # this option break alot of cross build..
  hardeningDisable =
    lib.optionals (stdenv.targetPlatform.isLinux && isCross) [
      "zerocallusedregs"
    ]
    ++ lib.optionals (stdenv.targetPlatform.isLoongArch64 || stdenv.targetPlatform.isAarch32) [
      "stackclashprotection"
    ];

  configureFlags = [
    "--program-prefix="
    "--disable-werror"

    "--enable-targets=all"
    "--enable-64-bit-bfd"
    "--disable-install-libbfd"
    "--disable-shared"
    "--enable-static"
    "--with-system-zlib"
    "--without-system-readline"

    "--with-system-gdbinit=/etc/gdb/gdbinit"
    "--with-system-gdbinit-dir=/etc/gdb/gdbinit.d"
    "--with-separate-debug-dir=/usr/lib/debug"
    "--with-jit-reader-dir=/usr/lib/gdb"
    "--with-auto-load-safe-path=${builtins.concatStringsSep ":" safePaths}"

    "--with-gmp=${gmp-static.dev}"
    "--with-mpfr=${mpfr-static.dev}"
    "--with-expat"
    "--with-libexpat-prefix=${expat-static.dev}"

    "--disable-sim"
    "--disable-inprocess-agent"
    "--with-python=${python3.pythonOnBuildForHost.interpreter}"
    "--with-debuginfod=yes"
  ]
  ++ lib.optionals stdenv.targetPlatform.isDarwin [
    "--target=x86_64-apple-darwin"
  ]
  ++ lib.optionals (!stdenv.targetPlatform.isDarwin) [
    "--target=${stdenv.targetPlatform.config}"
    "--host=${stdenv.targetPlatform.config}"
    "--build=${stdenv.buildPlatform.config}"
  ];

  # TODO:
  # fix: --with-python=/nix/store/g61j9ws03l841jyb2wxin8ab0dqh5viv-python3-3.14.0a6
  # fix: --with-python-libdir=/nix/store/g61j9ws03l841jyb2wxin8ab0dqh5viv-python3-3.14.0a6/lib

  # TODO: to powinno byc lib/python3.12/site-packages/gdb/
  # TODO: __init__.py powinno zwraca komunikat jakis lepszy jak _gdb import sie wywali
  # fix: --with-gdb-datadir=/nix/store/cgal8dan40165178zjzgfyahzd5hm596-gdb-16.2/share/gdb

  enableParallelBuilding = true;
  separateDebugInfo = true;

  dontStrip = true;
  doCheck = false;
})
