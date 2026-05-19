# Garmin Connect IQ / Monkey C Flake Template
# Provides Java and local SDK discovery. The proprietary Garmin SDK is installed per machine.

{
  description = "Garmin Connect IQ Monkey C development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            jdk17_headless
            just
            libxml2
            ripgrep
            fd
            jq
          ];

          NIX_LSP_ENABLED = "true";
          MONKEYC_COMPILER_OPTIONS = "";
          # Set MONKEYC_DEFAULT_DEVICE per project only when manifest.xml is insufficient.

          shellHook = ''
            find_connectiq_sdk() {
              if [ -n "''${CONNECTIQ_HOME:-}" ] && [ -f "$CONNECTIQ_HOME/bin/LanguageServer.jar" ]; then
                printf '%s\n' "$CONNECTIQ_HOME"
                return 0
              fi

              if [ -n "''${GARMIN_CONNECTIQ_SDK:-}" ] && [ -f "$GARMIN_CONNECTIQ_SDK/bin/LanguageServer.jar" ]; then
                printf '%s\n' "$GARMIN_CONNECTIQ_SDK"
                return 0
              fi

              for cfg in "$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg" "$HOME/.Garmin/ConnectIQ/current-sdk.cfg"; do
                if [ -f "$cfg" ]; then
                  IFS= read -r sdk_root < "$cfg"
                  if [ -f "$sdk_root/bin/LanguageServer.jar" ]; then
                    printf '%s\n' "$sdk_root"
                    return 0
                  fi
                fi
              done

              return 1
            }

            sdk_root="$(find_connectiq_sdk || true)"
            if [ -n "$sdk_root" ]; then
              export CONNECTIQ_HOME="$sdk_root"
              export GARMIN_CONNECTIQ_SDK="$sdk_root"
              export PATH="$CONNECTIQ_HOME/bin:$PATH"
              echo "Connect IQ SDK: $CONNECTIQ_HOME"
            else
              echo "Connect IQ SDK not found. Install it with Garmin SDK Manager or set CONNECTIQ_HOME."
            fi

            if [ -z "''${CONNECTIQ_DEVELOPER_KEY:-}" ]; then
              for key in "$PWD/developer_key.der" "$PWD/developer_key.pem" "$HOME/.Garmin/connect_iq_dev_key.der"; do
                if [ -f "$key" ]; then
                  export CONNECTIQ_DEVELOPER_KEY="$key"
                  break
                fi
              done
            fi

            if [ -n "''${MONKEYC_DEFAULT_DEVICE:-}" ]; then
              echo "Monkey C target device override: $MONKEYC_DEFAULT_DEVICE"
            else
              echo "Monkey C target device: manifest.xml, or set MONKEYC_DEFAULT_DEVICE per project"
            fi
            if [ -n "''${CONNECTIQ_DEVELOPER_KEY:-}" ]; then
              echo "Connect IQ developer key: $CONNECTIQ_DEVELOPER_KEY"
            else
              echo "Connect IQ developer key not set. Set CONNECTIQ_DEVELOPER_KEY when building signed PRGs."
            fi
          '';
        };
      });
}
