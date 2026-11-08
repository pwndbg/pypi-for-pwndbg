{
  description = "gdb/lldb for pwndbg";

  nixConfig = {
    #    extra-substituters = [
    #      "https://pwndbg.cachix.org"
    #    ];
    #    extra-trusted-public-keys = [
    #      "pwndbg.cachix.org-1:HhtIpP7j73SnuzLgobqqa8LVTng5Qi36sQtNt79cD3k="
    #    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    debuginfod-zig.url = "github:pwndbg/debuginfod-zig/v1.0.0";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      debuginfod-zig,
      zig-overlay,
      ...
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
      lib = nixpkgs.lib;
      pythonVersions = [
        "310"
        "311"
        "312"
        "313"
        "314"
        "315"
      ];

      fun_gdb_wheel =
        pkgs: name:
        (lib.genAttrs pythonVersions (
          v:
          pkgs.callPackage ./gdb_for_pwndbg/wheel.nix {
            gdb_drv = pkgs.${name}.${v};
          }
        ));
      fun_gdb =
        pkgs:
        (lib.genAttrs pythonVersions (
          v:
          pkgs.callPackage ./gdb_for_pwndbg/gdb.nix {
            python3 = pkgs."python${v}";
            version = "18.1";
            pypiVersion = "18.1.0.post1";
            src = pkgs.fetchurl {
              url = "mirror://gnu/gdb/gdb-18.1.tar.xz";
              hash = "sha256-zZ/D/itHdDhA5CwVktPYf4MC6xhjnAuLS6CJgALiNI8=";
            };
          }
        ));
      fun_gdb_dev =
        pkgs:
        (lib.genAttrs pythonVersions (
          v:
          pkgs.callPackage ./gdb_for_pwndbg/gdb.nix {
            python3 = pkgs."python${v}";
            version = "18.0";
            pypiVersion = "18.0.0.dev251227";
            src = pkgs.fetchgit {
              url = "git://sourceware.org/git/binutils-gdb.git";
              rev = "de90570a8bacac3c75f70b45b94b643eecbe22f4"; # refs/heads/gdb-18-branch
              hash = "sha256-+PIOdY4Sk1pofWe0dL4bvZFcZeeqU2b1nQMHe02+GLQ=";
            };
          }
        ));

      fun_lldb_wheel =
        pkgs: name:
        (lib.genAttrs pythonVersions (
          v:
          pkgs.callPackage ./lldb_for_pwndbg/wheel.nix {
            lldb_drv = pkgs.${name}.${v};
          }
        ));

      fun_lldb =
        pkgs:
        (lib.genAttrs pythonVersions (
          v:
          pkgs.callPackage ./lldb_for_pwndbg/lldb.nix {
            python3 = pkgs."python${v}";
            version = "23.1.0";
            pypiVersion = "23.1.0.post2";
            monorepoSrc = pkgs.fetchFromGitHub {
              owner = "llvm";
              repo = "llvm-project";
              rev = "llvmorg-23.1.0";
              hash = "sha256-Astfi1UDDcydyws3Q1sELqho/PxiNN/tvCtmCGj5FoE=";
            };
            patches = [ ];
          }
        ));
      fun_lldb_dev =
        pkgs:
        (lib.genAttrs pythonVersions (
          v:
          pkgs.callPackage ./lldb_for_pwndbg/lldb.nix {
            python3 = pkgs."python${v}";
            version = "23.0.0git";
            pypiVersion = "23.0.0.dev260209";
            monorepoSrc = pkgs.fetchFromGitHub {
              owner = "llvm";
              repo = "llvm-project";
              rev = "fed9abcb4796507622bdd9e2e36bc80260a5197b"; # refs/heads/main
              hash = "sha256-xkfHSmcQIkobNu1khy6SGMYsgYvAg4bhDMgYAKQUKQ8=";
            };
          }
        ));

      overlay = (
        final: prev:
        let
          isLinux = final.stdenv.hostPlatform.isLinux;

          # Rebuild `pkg` with `portableStaticStdenv` as a self-contained static lib. Its own deps are
          # dropped: pass the ones needed via `.override` on `pkg` and re-add them with
          # `.overrideAttrs { propagatedBuildInputs = …; }` on the result.
          makeStatic =
            pkg:
            (pkg.override { stdenv = final.portableStaticStdenv; }).overrideAttrs {
              propagatedBuildInputs = [ ];
              buildInputs = [ ];
              doCheck = false;
            };
        in
        {
          # Prebuilt upstream zig binary (runs on this set's host, i.e. the build machine when
          # used as `buildPackages.zig_glibc_2_28`), wrapped into our cc/bintools/stdenv.
          zig_glibc_2_28 = prev.callPackage ./zig {
            zig = zig-overlay.packages.${prev.stdenv.hostPlatform.system}."0.17.1";
          };

          # Host stdenv with zig as CC (Linux: glibc 2.28, loongarch64: 2.36); plain stdenv on macOS.
          # Unlike `buildPackages.zig_glibc_2_28.stdenv`, build/host/target platforms are correct here.
          portableStdenv =
            if isLinux then
              final.overrideCC final.stdenv final.buildPackages.zig_glibc_2_28.cc
            else
              final.stdenv;

          # `portableStdenv` building static libraries only. Like `pkgsStatic`, the host platform gets
          # `isStatic = true` (packages default to static from it: zlib `shared`, openssl `static`,
          # ncurses/xz `enableStatic`, …) and the stdenv adds --enable-static/--disable-shared,
          # -DBUILD_SHARED_LIBS=OFF, -Ddefault_library=static. Unlike `pkgsStatic`: the libc stays
          # as configured (glibc; musl under `pkgsMusl`) and binaries are not linked with `-static`.
          # Side effect: native builds formally become cross (host != build), same as `pkgsStatic`.
          # macOS: `pkgsStatic`'s stdenv (no musl there, just isStatic).
          portableStaticStdenv =
            if isLinux then
              final.stdenvAdapters.makeStaticLibraries (
                final.portableStdenv.override {
                  hostPlatform = lib.systems.elaborate {
                    inherit (final.stdenv.hostPlatform) config;
                    gcc = final.stdenv.hostPlatform.gcc or { };
                    isStatic = true;
                  };
                }
              )
            else
              final.pkgsStatic.stdenv;

          libclang_rt_ppc_builtins = prev.callPackage ./zig/libclang_rt_ppc_builtins.nix { };
          liblldb_stub = prev.callPackage ./liblldb_stub { };
          libpython_loader_lldb = prev.callPackage ./libpython_loader_lldb { };
          libpython_stub = prev.callPackage ./libpython_stub { };

          # nixos-25.11 only ships python315 as 3.15.0a6 (before the ABI freeze); use the final release.
          python315 =
            (prev.python315.override {
              self = final.__splicedPackages.python315;
              sourceVersion = {
                major = "3";
                minor = "15";
                patch = "0";
                suffix = "";
              };
              hash = "sha256-ukvtG6NGuRaJC3bZ4yBFFCCqafZAiZfTPGZILurj1XU=";
            }).overrideAttrs
              (
                old:
                # 3.15 dropped configure's `RUNSHARED=` reset for cross builds (3.14 still has it), so the
                # build python runs with LD_LIBRARY_PATH pointing at the target libpython. glibc skips a
                # foreign-arch lib, but a foreign byte order is fatal: s390x fails in `checksharedmods`.
                lib.optionalAttrs (prev.stdenv.hostPlatform != prev.stdenv.buildPlatform) {
                  makeFlags = (old.makeFlags or [ ]) ++ [ "RUNSHARED=" ];
                }
              );

          # lldb's Python type annotations need swig >= 4.5.0 (nixpkgs ships 4.3.1).
          swig_4_5_0 = prev.swig.overrideAttrs (old: {
            version = "4.5.0";
            src = prev.fetchFromGitHub {
              owner = "swig";
              repo = "swig";
              rev = "v4.5.0";
              hash = "sha256-NXN3Zx66PNpYNuFVCalHymb/GW0cUi5drjIXNOVMgb8=";
            };
          });

          zlib-static = makeStatic prev.zlib;
          zstd-static = makeStatic prev.zstd;
          xz-static = makeStatic prev.xz;
          gmp-static = makeStatic prev.gmp;
          libipt-static = makeStatic prev.libipt;
          libiconv-static = makeStatic prev.libiconvReal;
          ncurses-static = makeStatic prev.ncurses;
          expat-static = makeStatic prev.expat;
          nghttp2-static = makeStatic prev.nghttp2;
          mpfr-static = (makeStatic (prev.mpfr.override { gmp = final.gmp-static; })).overrideAttrs {
            propagatedBuildInputs = [ final.gmp-static ];
          };

          # Only Boost.Regex (all source-highlight needs). zig is clang, but its wrapper isn't flagged
          # `isClang`, so pick b2's clang toolset by hand and drop clang.jam's own `--target=…`
          # (nixpkgs patch, applied there only for `isClang`): it would override zig's `-target …gnu.2.28`.
          boost-static =
            let
              onlyRegex = builtins.replaceStrings [ "--without-python" ] [ "--with-regex" ];
            in
            (makeStatic (prev.boost.override { toolset = "clang"; })).overrideAttrs (old: {
              patches =
                old.patches
                ++ lib.optional (!(final.portableStaticStdenv.cc.isClang or false)) (
                  prev.path + "/pkgs/development/libraries/boost/fix-clang-target.patch"
                );
              buildPhase = onlyRegex old.buildPhase;
              installPhase = onlyRegex old.installPhase;
            });

          sourceHighlight-static =
            (makeStatic (prev.sourceHighlight.override { boost = final.boost-static; })).overrideAttrs
              (old: {
                # gdb links libsource-highlight.a, which needs libboost_regex.a
                propagatedBuildInputs = [ final.boost-static ];
                # C++17 drops `register`; nixpkgs adds this upstream patch only for `isClang`
                patches =
                  old.patches
                  ++ lib.optional (!(final.portableStaticStdenv.cc.isClang or false)) (
                    prev.fetchpatch {
                      name = "remove-register-keyword";
                      url = "https://git.savannah.gnu.org/cgit/src-highlite.git/patch/?id=416b39758dba2c74515584514a959ad1b0ad50d1";
                      hash = "sha256-R5A7IGHhU82EqceMCsuNBanhRz4dFVqiaH8637dr7jw=";
                      includes = [ "lib/*" ];
                    }
                  );
              });

          libxml2-static = (makeStatic prev.libxml2).overrideAttrs (
            # macOS has no iconv in libc
            lib.optionalAttrs final.stdenv.hostPlatform.isDarwin {
              propagatedBuildInputs = [ final.libiconv-static ];
            }
          );

          libedit-static =
            (makeStatic (prev.libedit.override { ncurses = final.ncurses-static; })).overrideAttrs
              { propagatedBuildInputs = [ final.ncurses-static ]; };

          # OpenSSL without DSO/engine support for static linking into liblldb.so.
          # - no-engine/no-dso: avoid dlopen dependency (-Wl,-z,defs issue)
          openssl-static =
            let
              noEngine =
                old:
                (
                  {
                    configureFlags = (old.configureFlags or [ ]) ++ [
                      "no-engine"
                      "no-dso"
                    ];
                  }
                  // lib.optionalAttrs isLinux {
                    configureScript =
                      if final.stdenv.hostPlatform.isAarch32 then
                        "${old.configureScript} -mcpu=baseline"
                      else if final.stdenv.hostPlatform.isx86_32 then
                        "${old.configureScript} -DBROKEN_CLANG_ATOMICS"
                      else
                        old.configureScript;
                  }
                );
            in
            (makeStatic prev.openssl).overrideAttrs noEngine;

          libcurl-static =
            let
              args = {
                openssl = final.openssl-static;
                nghttp2 = final.nghttp2-static;
                zlib = final.zlib-static;
                zstd = final.zstd-static;

                zlibSupport = true;
                zstdSupport = true;
                opensslSupport = true;
                http2Support = true;

                brotliSupport = false;
                gssSupport = false;
                http3Support = false;
                websocketSupport = false;
                ldapSupport = false;
                idnSupport = false;
                pslSupport = false;
                rtmpSupport = false;
                scpSupport = false;
              };
              propagatedBuildInputs = [
                final.nghttp2-static
                final.openssl-static
                final.zlib-static
                final.zstd-static
              ];
            in
            if isLinux then
              (makeStatic (prev.curl.override args)).overrideAttrs { inherit propagatedBuildInputs; }
            else
              # NOTE: On macOS, using fully static libcurl with LLDB fails for unknown reasons.
              # LLDB crashes or fails to link — possibly missing Apple SDK frameworks
              # (e.g. Security, CoreFoundation) that aren't pulled in transitively,
              # or libcurl.pc missing required flags. Using dynamic curl with static deps for now.
              (prev.curl.override args).overrideAttrs {
                inherit propagatedBuildInputs;
                buildInputs = [ ];
              };

          gdb-for-pwndbg = fun_gdb final;
          wheel-gdb-for-pwndbg = fun_gdb_wheel final "gdb-for-pwndbg";

          gdb_dev-for-pwndbg = fun_gdb_dev final;
          wheel-gdb_dev-for-pwndbg = fun_gdb_wheel final "gdb_dev-for-pwndbg";

          lldb-for-pwndbg = fun_lldb final;
          wheel-lldb-for-pwndbg = fun_lldb_wheel final "lldb-for-pwndbg";

          lldb_dev-for-pwndbg = fun_lldb_dev final;
          wheel-lldb_dev-for-pwndbg = fun_lldb_wheel final "lldb_dev-for-pwndbg";
        }
      );
      overlay_flat = final: prev: (debuginfod-zig.overlays.default final prev) // (overlay final prev);

      fun_pkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = [
            overlay_flat
          ];
        };
    in
    {
      overlays.default = overlay_flat;
      packages = forAllSystems (
        system:
        let
          pkgs = (fun_pkgs system);
        in
        {
          gdb-for-pwndbg = pkgs.gdb-for-pwndbg;
          wheel-gdb-for-pwndbg = pkgs.wheel-gdb-for-pwndbg;

          gdb_dev-for-pwndbg = pkgs.gdb_dev-for-pwndbg;
          wheel-gdb_dev-for-pwndbg = pkgs.wheel-gdb_dev-for-pwndbg;

          lldb-for-pwndbg = pkgs.lldb-for-pwndbg;
          wheel-lldb-for-pwndbg = pkgs.wheel-lldb-for-pwndbg;

          lldb_dev-for-pwndbg = pkgs.lldb_dev-for-pwndbg;
          wheel-lldb_dev-for-pwndbg = pkgs.wheel-lldb_dev-for-pwndbg;

          pkgsCross = pkgs.pkgsCross;

          libcurl-static = pkgs.libcurl-static;
          libpython_loader_lldb = pkgs.libpython_loader_lldb;
          liblldb_stub = pkgs.liblldb_stub;
          libpython_stub = pkgs.libpython_stub;
        }
      );
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
