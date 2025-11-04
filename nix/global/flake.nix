{
  description = "Global development environment for inheritance";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
        globalEnv = import ./default.nix {
          inherit pkgs;
          pkgs-unstable = pkgs-unstable;
        };
      in {
        # Default shell that projects inherit from
        devShells = {
          default = globalEnv.devShell;
          minimal = globalEnv.minimalShell;
        };

        # Export for other flakes to use
        lib = {
          inherit (globalEnv) commonDevPackages commonShellHook packages;
        };
      });
}