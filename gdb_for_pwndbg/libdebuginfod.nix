{
  buildPackages,
  pkgsStatic,

  fetchurl,

  pkg-config,
  breakpointHook,
  autoreconfHook,

  elfutils,
  curl,
}:
let
 version = "0.191";
 libcurl =       ((curl.override {
        stdenv = buildPackages.zig_glibc_2_28.stdenv;

        gssSupport = false;
        scpSupport = false;
        pslSupport = false;
        http2Support = false;
#        opensslSupport = false;
#        rustlsSupport = true;
        wolfsslSupport = false;

        zstdSupport = false;
        zlibSupport = true;
        brotliSupport = false;
        idnSupport = false;
        opensslSupport = true;
      }).overrideAttrs (old2: {
       propagatedBuildInputs = [];
       buildInputs = [
         pkgsStatic.zlib
#         pkgsStatic.zstd
         pkgsStatic.openssl
       ];
        # brotlidec?
#    ++ lib.optional gnutlsSupport gnutls
#    ++ lib.optional http2Support nghttp2
      }));

in
(elfutils.override {
  enableDebuginfod = true;
  stdenv = buildPackages.zig_glibc_2_28.stdenv;
}).overrideAttrs
  (old: {
    version = version;

    nativeBuildInputs = old.nativeBuildInputs ++ [
      pkg-config
      breakpointHook
      autoreconfHook
    ];

    src = fetchurl {
      url = "https://sourceware.org/elfutils/ftp/${version}/${old.pname}-${version}.tar.bz2";
      hash = "sha256-33bbcTZtHXCDZfx6bGDKSDmPFDZ+sriVTvyIlxR62HE=";
    };

    passthru = {
      libcurl = libcurl;
    };

    buildInputs = [
      # libelf
      pkgsStatic.zstd
      pkgsStatic.zlib
      #          pkgsStatic.lzma
      #          pkgsStatic.bzip2

      # libdebuginfod
      libcurl
    ];

    dontStrip = true;
    doCheck = false;
    doInstallCheck = false;

    patches = old.patches ++ [
      ./fix-rpath-link.patch
      ./cxx-header-collision.patch
    ];

    configureFlags = [
      "--program-prefix=eu-"
      "--disable-debuginfod"
      "--disable-symbol-versioning"
      "--disable-demangler"
      "--enable-deterministic-archives"
      "--enable-libdebuginfod"
      "CFLAGS=-Wno-unused-const-variable"
      "CXXFLAGS=-Wno-unused-const-variable"
    ];
  })
