function hm-packages --description "List packages installed by Home Manager"
    if test -e "$HOME/.local/state/nix/profiles/home-manager"
        # List packages in the Home Manager profile
        nix-store -q --requisites ~/.local/state/nix/profiles/home-manager | grep -E '/(bin|lib|share)' | xargs -I {} basename {} | sort -u | head -50
    else if test -d "$HOME/.nix-profile"
        # Fallback to listing nix profile packages
        ls ~/.nix-profile/bin/ 2>/dev/null | sort
    else
        echo "Home Manager not activated. Run 'hm-switch' first"
        return 1
    end
end
