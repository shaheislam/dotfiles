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
      # Detect current system architecture automatically
      # Works on: Apple Silicon (aarch64-darwin), Intel Mac (x86_64-darwin),
      # Linux ARM (aarch64-linux), Linux x86 (x86_64-linux)
      currentSystem = builtins.currentSystem or "aarch64-darwin";

      # Shared function to create home configurations for any user
      # Usage: mkHomeConfig { username = "yourname"; }
      mkHomeConfig = { username, homeDirectory ? "/Users/${username}", system ? currentSystem }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};

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

      # Dynamic username detection from environment (requires --impure)
      # Used by setup scripts for automatic configuration
      dynamicUser = builtins.getEnv "USER";
      # Fallback to "user" if USER env var is empty (shouldn't happen but defensive)
      detectedUser = if dynamicUser != "" then dynamicUser else "user";

      # Smart path detection for macOS vs Linux
      # Checks if /Users exists (macOS) or falls back to /home (Linux)
      detectedHomeDir =
        if builtins.pathExists "/Users"
        then "/Users/${detectedUser}"   # macOS
        else "/home/${detectedUser}";   # Linux
    in {
      # homeConfigurations: Add your username(s) here
      # Then use: home-manager switch --flake ~/.config/home-manager#yourname
      homeConfigurations = {
        # DYNAMIC DEFAULT - Auto-detects current user (requires --impure flag)
        # Usage: home-manager switch --flake .#default --impure
        # Perfect for setup scripts that need to work on any device/user
        # Automatically detects macOS (/Users/) vs Linux (/home/)
        default = mkHomeConfig {
          username = detectedUser;
          homeDirectory = detectedHomeDir;
        };

        # EXPLICIT CONFIGURATIONS - For manual/reproducible use (no --impure needed)
        # Usage: home-manager switch --flake .#shahe
        "shahe" = mkHomeConfig {
          username = "shahe";
        };

        "shaheislam" = mkHomeConfig {
          username = "shaheislam";
        };

        # Easy to add more users for different devices:
        # "work-laptop" = mkHomeConfig {
        #   username = "work-user";
        #   # Optionally override home directory:
        #   # homeDirectory = "/home/work-user";  # For Linux
        # };

        # "personal-macbook" = mkHomeConfig {
        #   username = "personal";
        # };
      };
    } // flake-utils.lib.eachDefaultSystem (system: {
      # Per-system outputs (packages and apps for each architecture)
      # These work automatically regardless of which username you use
      packages.default = self.homeConfigurations."shaheislam".activationPackage;

      apps.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/home-manager";
      };
    });
}