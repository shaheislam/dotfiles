# Minimal flake example - just override one LSP
{
  description = "Minimal override example - just gopls";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-darwin";  # or "aarch64-darwin" for M1 Macs
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          # Just override gopls to latest version
          gopls

          # Everything else uses global versions
        ];

        shellHook = ''
          echo "📦 Minimal override active"
          echo "   gopls: $(gopls version | head -1)"
          echo "   All other LSPs: using global versions"
        '';
      };
    };
}