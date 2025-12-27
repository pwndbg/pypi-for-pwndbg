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
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    debuginfod-zig.url = "github:pwndbg/debuginfod-zig";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      debuginfod-zig,
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
            version = "17.1";
            pypiVersion = "17.1.0.post1";
            src = pkgs.fetchurl {
              url = "mirror://gnu/gdb/gdb-17.1.tar.xz";
              hash = "sha256-FJlvX3TJ9o9aVD/cRbyngAIH+R+SrupsLnkYIsfG2HY=";
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
            version = "21.1.7";
            pypiVersion = "21.1.7.post1";
            monorepoSrc = pkgs.fetchFromGitHub {
              owner = "llvm";
              repo = "llvm-project";
              rev = "llvmorg-21.1.7";
              hash = "sha256-SaRJ7+iZMhhBdcUDuJpMAY4REQVhrvYMqI2aq3Kz08o=";
            };
            patches = [
              (pkgs.fetchpatch {
                # Fix issue: https://github.com/llvm/llvm-project/issues/170891
                name = "fix-lldb-crash";
                url = "https://github.com/llvm/llvm-project/commit/c814ac1928b264a5bdeb98ec9035412fa37fb243.patch";
                hash = "sha256-6piRR064Qv/gj9oML4G5XCGfvQJ2bHuIFHvvoq8A4Uk=";
              })
            ];
          }
        ));
      fun_lldb_dev =
        pkgs:
        (lib.genAttrs pythonVersions (
          v:
          pkgs.callPackage ./lldb_for_pwndbg/lldb.nix {
            python3 = pkgs."python${v}";
            version = "22.0.0git";
            pypiVersion = "22.0.0.dev251019";
            monorepoSrc = pkgs.fetchFromGitHub {
              owner = "llvm";
              repo = "llvm-project";
              rev = "63ca2fd7a16f532a95e53780220d2eae0debb8d9"; # refs/heads/main
              hash = "sha256-tOczPkDDir9XMIVZ3udpBWUDuoAhHuosw79gFjH2oRU=";
            };
          }
        ));

      overlay = (
        final: prev: {
          zig_glibc_2_28 = (prev.callPackage ./zig { })."0.15";
          libclang_rt_ppc_builtins = prev.callPackage ./zig/libclang_rt_ppc_builtins.nix { };

          zlib-static = prev.pkgsStatic.zlib;
          zstd-static = prev.pkgsStatic.zstd;
          xz-static = prev.pkgsStatic.xz;
          gmp-static = prev.pkgsStatic.gmp;
          mpfr-static = prev.pkgsStatic.mpfr;
          libipt-static = prev.pkgsStatic.libipt;
          sourceHighlight-static = prev.pkgsStatic.sourceHighlight;

          # Dynamic libiconv causes issues with our portable build.
          # It reads /some-path/lib/gconv/gconv-modules.d/gconv-modules-extra.conf,
          # then loads /some-path/lib/gconv/UTF-32.so dynamically.
          libiconv-static = prev.pkgsStatic.libiconvReal;

          ncurses-static =
            let
              pkg =
                (prev.ncurses.override {
                  stdenv = final.buildPackages.zig_glibc_2_28.stdenv;
                  enableStatic = true;
                }).overrideAttrs
                  (old: {
                    hardeningDisable = [ "zerocallusedregs" ];
                    propagatedBuildInputs = [ ];
                    buildInputs = [ ];
                    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
                      prev.pkgsBuildHost.ncurses
                    ];
                    configurePlatforms = [ ];
                    configureFlags = (old.configureFlags or [ ]) ++ [
                      "--disable-shared"
                      "--enable-static"
                      "--target=${prev.stdenv.targetPlatform.config}"
                      "--host=${prev.stdenv.targetPlatform.config}"
                      "--build=${prev.stdenv.buildPlatform.config}"
                    ];
                  });
            in
            (if prev.stdenv.targetPlatform.isLinux then pkg else prev.pkgsStatic.ncurses);

          libxml2-static =
            if prev.stdenv.targetPlatform.isLinux then
              (prev.libxml2.override {
                stdenv = final.buildPackages.zig_glibc_2_28.stdenv;
                enableStatic = true;
                enableShared = false;
              }).overrideAttrs
                (old: {
                  hardeningDisable = [ "zerocallusedregs" ];
                  propagatedBuildInputs = [ ];
                  buildInputs = [ ];
                  doCheck = false;
                  configureFlags = (old.configureFlags or [ ]) ++ [
                    "--target=${prev.stdenv.targetPlatform.config}"
                    "--host=${prev.stdenv.targetPlatform.config}"
                    "--build=${prev.stdenv.buildPlatform.config}"
                  ];
                })
            else
              (prev.pkgsStatic.libxml2.overrideAttrs (old: {
                # libiconv is required by libxml2
                propagatedBuildInputs = [ final.libiconv-static ];
                buildInputs = [ ];
              }));

          expat-static =
            let
              pkg =
                (prev.expat.override {
                  stdenv = final.buildPackages.zig_glibc_2_28.stdenv;
                }).overrideAttrs
                  (old: {
                    hardeningDisable = [ "zerocallusedregs" ];
                    propagatedBuildInputs = [ ];
                    buildInputs = [ ];
                    doCheck = false;

                    configureFlags = (old.configureFlags or [ ]) ++ [
                      "--disable-shared"
                      "--enable-static"
                      "--target=${prev.stdenv.targetPlatform.config}"
                      "--host=${prev.stdenv.targetPlatform.config}"
                      "--build=${prev.stdenv.buildPlatform.config}"
                    ];
                  });
            in
            (if prev.stdenv.targetPlatform.isLinux then pkg else prev.pkgsStatic.expat);

          libedit-static =
            let
              pkg =
                (prev.libedit.override {
                  stdenv = final.buildPackages.zig_glibc_2_28.stdenv;
                  ncurses = final.ncurses-static;
                }).overrideAttrs
                  (old: {
                    hardeningDisable = [ "zerocallusedregs" ];
                    propagatedBuildInputs = [ final.ncurses-static ];
                    buildInputs = [ ];

                    configureFlags = (old.configureFlags or [ ]) ++ [
                      "--disable-shared"
                      "--enable-static"
                      "--target=${prev.stdenv.targetPlatform.config}"
                      "--host=${prev.stdenv.targetPlatform.config}"
                      "--build=${prev.stdenv.buildPlatform.config}"
                    ];
                  });
            in
            (if prev.stdenv.targetPlatform.isLinux then pkg else prev.pkgsStatic.libedit);

          libcurl-static = prev.pkgsStatic.curl.override {
            http2Support = true;
            gssSupport = false;
            http3Support = false;
            websocketSupport = false;
            ldapSupport = false;
            idnSupport = false;
            pslSupport = false;
            rtmpSupport = false;
            scpSupport = false;
          };

          gdb-for-pwndbg = fun_gdb prev;
          wheel-gdb-for-pwndbg = fun_gdb_wheel final "gdb-for-pwndbg";

          gdb_dev-for-pwndbg = fun_gdb_dev prev;
          wheel-gdb_dev-for-pwndbg = fun_gdb_wheel final "gdb_dev-for-pwndbg";

          lldb-for-pwndbg = fun_lldb prev;
          wheel-lldb-for-pwndbg = fun_lldb_wheel final "lldb-for-pwndbg";

          lldb_dev-for-pwndbg = fun_lldb_dev prev;
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
          wheel_dev-lldb-for-pwndbg = pkgs.wheel_dev-lldb-for-pwndbg;

          pkgsCross = pkgs.pkgsCross;
        }
      );
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
