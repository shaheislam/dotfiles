{
  description = "Global development environment for inheritance";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        globalEnv = import ./default.nix { inherit pkgs; };
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