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
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    debuginfod-zig.url = "github:pwndbg/debuginfod-zig/v1.0.2";
    zig-overlay.url = "github:mitchellh/zig-overlay";
    # nixpkgs 26.11 dropped x86_64-darwin; 26.05 still supports it
    nixpkgs-x86_64-darwin.url = "https://channels.nixos.org/nixpkgs-26.05-darwin/nixexprs.tar.zst";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      debuginfod-zig,
      zig-overlay,
      nixpkgs-x86_64-darwin,
      ...
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs (
        lib.unique (nixpkgs.lib.systems.flakeExposed ++ [ "x86_64-darwin" ])
      );
      nixpkgsFor = system: if system == "x86_64-darwin" then nixpkgs-x86_64-darwin else nixpkgs;
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
            patchelf = pkgs.buildPackages.patchelf_0_19_3;
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
            patchelf = pkgs.buildPackages.patchelf_0_19_3;
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

          # Host stdenv with zig as CC (Linux: glibc 2.28, ppc64le: 2.32, loongarch64: 2.36); plain stdenv on macOS.
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

          # 3.15 dropped configure's `RUNSHARED=` reset for cross builds (3.14 still has it), so the
          # build python runs with LD_LIBRARY_PATH pointing at the target libpython. glibc skips a
          # foreign-arch lib, but a foreign byte order is fatal: s390x fails in `checksharedmods`.
          # Upstream: https://github.com/python/cpython/issues/160924 (fix: PR #161321).
          # nixpkgs dropped python310 in 26.05: build it with the current cpython expression. The
          # 3.10-only patches it no longer ships come from nixos-25.11, its last release with 3.10.
          python310 =
            prev.python310 or (
              let
                patch =
                  path: hash:
                  prev.fetchurl {
                    name = baseNameOf path;
                    url = "https://raw.githubusercontent.com/NixOS/nixpkgs/b6018f87da91d19d0ab4cf979885689b469cdd41/pkgs/development/interpreters/python/cpython/${path}";
                    inherit hash;
                  };
              in
              (prev.python311.override {
                self = final.__splicedPackages.python310;
                sourceVersion = {
                  major = "3";
                  minor = "10";
                  patch = "19";
                  suffix = "";
                };
                hash = "sha256-yPSlllciAdgd19+R9w4XfhmnDx1ImWi1S1+78pqXwHY=";
                noldconfigPatch = patch "3.10/no-ldconfig.patch" "sha256-AaneOmdIHDHbH67pkMxshUCt/nZDCg1mwhQ7ubZ0i/4=";
              }).overrideAttrs
                (
                  old:
                  lib.optionalAttrs prev.stdenv.hostPlatform.isDarwin {
                    # with clang: 25.11's distutils C++ patch for 3.7-3.10 (newer nixpkgs fall back to
                    # bugs.python.org's for < 3.11) and its macOS Tcl/Tk lookup patch for 3.9-3.10
                    patches =
                      map (
                        p:
                        if (p.name or "") == "python-3.x-distutils-C++.patch" then
                          patch "3.7/python-3.x-distutils-C++.patch" "sha256-WqArTEerQRw0jBSbG1jAmwV0NUPZVOkDQ3o1vYTq/uY="
                        else
                          p
                      ) old.patches
                      ++ [ (patch "3.9/darwin-tcl-tk.patch" "sha256-HA5/OwvxALNsB+0MJDqiAQC+kbRZYpKyZC5TTYEMYtQ=") ];
                  }
                )
            );

          python315 = prev.python315.overrideAttrs (
            old:
            lib.optionalAttrs (prev.stdenv.hostPlatform != prev.stdenv.buildPlatform) {
              makeFlags = (old.makeFlags or [ ]) ++ [ "RUNSHARED=" ];
            }
          );

          # For the wheels. patchelf >= 0.18 (still in 0.19.3 and master) builds the extra LOAD in
          # shiftFile() from the split segment's raw p_offset/p_paddr/p_vaddr, without rdi(): on a
          # foreign-endian file (s390x on aarch64/x86_64) it gets a garbage offset and llvm-strip
          # fails with "program header with offset 0xf0e920ffffde1610 ... goes past the end".
          # Upstream: https://github.com/NixOS/patchelf/issues/680
          patchelf_0_19_3 = prev.patchelf.overrideAttrs (old: {
            version = "0.19.3";
            src = prev.fetchurl {
              url = "https://github.com/NixOS/patchelf/releases/download/0.19.3/patchelf-0.19.3.tar.bz2";
              hash = "sha256-INviPp28StdpB4qGetACwEKXoGn/k8lftyJC3VXU3W8=";
            };
            postPatch = (old.postPatch or "") + ''
              substituteInPlace src/patchelf.cc \
                --replace-fail 'phdrs.at(splitIndex).p_offset - ' 'rdi(phdrs.at(splitIndex).p_offset) - ' \
                --replace-fail 'phdrs.at(splitIndex).p_paddr - ' 'rdi(phdrs.at(splitIndex).p_paddr) - ' \
                --replace-fail 'phdrs.at(splitIndex).p_vaddr - ' 'rdi(phdrs.at(splitIndex).p_vaddr) - '
            '';
          });

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
          # gmp 6.3.0's longlong.h spells LoongArch's 128-bit type `__int128__`, which only GCC
          # accepts, not clang/zig (mpfr's copy of it already says `__int128`).
          gmp-static = (makeStatic prev.gmp).overrideAttrs (
            old:
            lib.optionalAttrs final.stdenv.hostPlatform.isLoongArch64 {
              env = (old.env or { }) // {
                NIX_CFLAGS_COMPILE = toString [
                  (old.env.NIX_CFLAGS_COMPILE or "")
                  "-D__int128__=__int128"
                ];
              };
            }
          );
          libipt-static = makeStatic prev.libipt;
          libiconv-static = makeStatic prev.libiconvReal;
          ncurses-static = makeStatic prev.ncurses;
          expat-static = makeStatic prev.expat;
          nghttp2-static = makeStatic prev.nghttp2;
          mpfr-static = (makeStatic (prev.mpfr.override { gmp = final.gmp-static; })).overrideAttrs {
            propagatedBuildInputs = [ final.gmp-static ];
          };

          # Only Boost.Regex (all source-highlight needs). zig is clang, but its wrapper isn't flagged
          # `isClang`, so pick b2's clang toolset by hand and stop clang.jam from adding its own
          # `--target=…`: it would override zig's `-target …gnu.2.28`. Boost < 1.91: nixpkgs' patch
          # (applied there only for `isClang`); >= 1.91: clang.jam's `<triple>none` option.
          boost-static =
            let
              onlyRegex = builtins.replaceStrings [ "--without-python" ] [ "--with-regex" ];
              isClang = final.portableStaticStdenv.cc.isClang or false;
              # start of the clang block in nixpkgs' user-config.jam (the gcc block looks the same)
              clangCross = "using clang : cross : ${final.portableStaticStdenv.cc.targetPrefix}c++\n  : ";
            in
            (makeStatic (prev.boost.override { toolset = "clang"; })).overrideAttrs (old: {
              patches =
                old.patches
                ++ lib.optional (!isClang && lib.versionOlder old.version "1.91") (
                  prev.path + "/pkgs/development/libraries/boost/fix-clang-target.patch"
                );
              # user-config.jam is written by nixpkgs' preConfigure
              postConfigure =
                (old.postConfigure or "")
                + lib.optionalString (!isClang && lib.versionAtLeast old.version "1.91") ''
                  substituteInPlace user-config.jam --replace-fail \
                    ${lib.escapeShellArg "${clangCross}<archiver>"} \
                    ${lib.escapeShellArg "${clangCross}<triple>none <archiver>"}
                '';
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
        import (nixpkgsFor system) {
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
      formatter = forAllSystems (system: (nixpkgsFor system).legacyPackages.${system}.nixfmt-tree);
    };
}
