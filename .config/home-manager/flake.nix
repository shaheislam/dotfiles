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

      # Shared function to create home configurations for different users
      mkHomeConfig = { username, homeDirectory }:
        home-manager.lib.homeManagerConfiguration {
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
    in {
      # Define configurations for multiple users/machines
      homeConfigurations = {
        # Primary configuration (current machine)
        "shahe" = mkHomeConfig {
          username = "shahe";
          homeDirectory = "/Users/shahe";
        };

        # Alternative username configuration
        "shaheislam" = mkHomeConfig {
          username = "shaheislam";
          homeDirectory = "/Users/shaheislam";
        };

        # Easy to add more configurations as needed:
        # "work-laptop" = mkHomeConfig {
        #   username = "work-user";
        #   homeDirectory = "/Users/work-user";
        # };
      };

      # Default activation package (uses primary configuration)
      packages.${system}.default =
        self.homeConfigurations."shahe".activationPackage;

      # App for easy activation
      apps.${system}.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/home-manager";
      };
    };
}