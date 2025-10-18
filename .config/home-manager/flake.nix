{
  description = "Home Manager configuration for global Nix environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, home-manager, flake-utils, ... }:
    let
      system = "aarch64-darwin";  # Apple Silicon. Use "x86_64-darwin" for Intel
      pkgs = nixpkgs.legacyPackages.${system};

      username = "shaheislam";
      homeDirectory = "/Users/shaheislam";
    in {
      homeConfigurations."${username}" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          ./home.nix
          {
            home = {
              inherit username homeDirectory;
              stateVersion = "24.05";
            };
          }
        ];
      };

      # Convenience activation package
      packages.${system}.default = self.homeConfigurations."${username}".activationPackage;

      # App for easy activation
      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/home-manager";
      };
    };
}