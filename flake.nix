{
  description = "gdb for pwndbg";

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
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
      lib = nixpkgs.lib;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              (final: prev: {
                zig_glibc_2_28 = (prev.callPackage ./zig { })."0.13";
              })
            ];
          };
          pythonVersions = [
            "310"
            "311"
            "312"
            "313"
            "314"
          ];
        in
        {
          gdb = (
            lib.genAttrs pythonVersions (
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
            )
          );
#          gdb_dev = (
#            lib.genAttrs pythonVersions (
#              v:
#              pkgs.callPackage ./gdb_for_pwndbg/gdb.nix {
#                python3 = pkgs."python${v}";
#                version = "17.0";
#                pypiVersion = "17.0.0.dev251019";
#                src = pkgs.fetchgit {
#                  url = "git://sourceware.org/git/binutils-gdb.git";
#                  rev = "ba759554ff2d71c8cdd43df645abd04545c32f82";  # refs/heads/gdb-17-branch
#                  hash = "sha256-4Hg2ltF62mzabSamPp5fR+SDbGcUqzb87DUgWuoVURs=";
#                };
#              }
#            )
#          );
          lldb = (
            lib.genAttrs pythonVersions (
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
            )
          );
          lldb_dev = (
            lib.genAttrs pythonVersions (
              v:
              pkgs.callPackage ./lldb_for_pwndbg/lldb.nix {
                python3 = pkgs."python${v}";
                version = "22.0.0git";
                pypiVersion = "22.0.0.dev251019";
                monorepoSrc = pkgs.fetchFromGitHub {
                  owner = "llvm";
                  repo = "llvm-project";
                  rev = "63ca2fd7a16f532a95e53780220d2eae0debb8d9";  # refs/heads/main
                  hash = "sha256-tOczPkDDir9XMIVZ3udpBWUDuoAhHuosw79gFjH2oRU=";
                };
              }
            )
          );
          gdb_wheel = (
            lib.genAttrs pythonVersions (
              v:
              pkgs.callPackage ./gdb_for_pwndbg/wheel.nix {
                gdb_drv = self.packages.${system}.gdb.${v};
              }
            )
          );
          gdb_dev_wheel = (
            lib.genAttrs pythonVersions (
              v:
              pkgs.callPackage ./gdb_for_pwndbg/wheel.nix {
                gdb_drv = self.packages.${system}.gdb_dev.${v};
              }
            )
          );
          lldb_wheel = (
            lib.genAttrs pythonVersions (
              v:
              pkgs.callPackage ./lldb_for_pwndbg/wheel.nix {
                lldb_drv = self.packages.${system}.lldb.${v};
              }
            )
          );
          lldb_dev_wheel = (
            lib.genAttrs pythonVersions (
              v:
              pkgs.callPackage ./lldb_for_pwndbg/wheel.nix {
                lldb_drv = self.packages.${system}.lldb_dev.${v};
              }
            )
          );
        }
      );
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
