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
              }
            )
          );
          lldb = (
            lib.genAttrs pythonVersions (
              v:
              pkgs.callPackage ./lldb_for_pwndbg/lldb.nix {
                python3 = pkgs."python${v}";
                version = "21.1.0";
                monorepoSrc = pkgs.fetchFromGitHub {
                  owner = "llvm";
                  repo = "llvm-project";
                  rev = "llvmorg-21.1.0";
                  hash = "sha256-4DLEZuhREHMl2t0f1iqvXSRSE5VBMVxd94Tj4m8Yf9s=";
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
          lldb_wheel = (
            lib.genAttrs pythonVersions (
              v:
              pkgs.callPackage ./lldb_for_pwndbg/wheel.nix {
                lldb_drv = self.packages.${system}.lldb.${v};
              }
            )
          );
        }
      );
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
