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
            version = "16.3";
            pypiVersion = "16.3.0.post4";
            src = pkgs.fetchurl {
              url = "mirror://gnu/gdb/gdb-16.3.tar.xz";
              hash = "sha256-vPzQlVKKmHkXrPn/8/FnIYFpSSbMGNYJyZ0AQsACJMU=";
            };
          }
        ));
      fun_gdb_dev =
        pkgs:
        (lib.genAttrs pythonVersions (
          v:
          pkgs.callPackage ./gdb_for_pwndbg/gdb.nix {
            python3 = pkgs."python${v}";
            version = "17.0";
            pypiVersion = "17.0.0.dev251019";
            src = pkgs.fetchgit {
              url = "git://sourceware.org/git/binutils-gdb.git";
              rev = "ba759554ff2d71c8cdd43df645abd04545c32f82"; # refs/heads/gdb-17-branch
              hash = "sha256-4Hg2ltF62mzabSamPp5fR+SDbGcUqzb87DUgWuoVURs=";
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
            version = "21.1.3";
            pypiVersion = "21.1.3.post1";
            monorepoSrc = pkgs.fetchFromGitHub {
              owner = "llvm";
              repo = "llvm-project";
              rev = "llvmorg-21.1.3";
              hash = "sha256-zYoVXLfXY3CDbm0ZI0U1Mx5rM65ObhZg6VkU1YrGE0c=";
            };
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

      fun_pkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = [
            debuginfod-zig.overlays.default
            overlay
          ];
        };
    in
    {
      overlays.default = overlay;
      packages = forAllSystems (
        system:
        let
          pkgs = (fun_pkgs system);
        in
        {
          gdb = pkgs.gdb-for-pwndbg;
          gdb_wheel = pkgs.wheel-gdb-for-pwndbg;

          gdb_dev = pkgs.gdb_dev-for-pwndbg;
          gdb_dev_wheel = pkgs.wheel-gdb_dev-for-pwndbg;

          lldb = pkgs.lldb-for-pwndbg;
          lldb_wheel = pkgs.wheel-lldb-for-pwndbg;

          lldb_dev = pkgs.lldb_dev-for-pwndbg;
          lldb_dev_wheel = pkgs.wheel_dev-lldb-for-pwndbg;

          pkgsCross = pkgs.pkgsCross;
        }
      );
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
