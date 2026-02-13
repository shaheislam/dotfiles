function hm-generations --description "List Home Manager generations"
    if command -v home-manager >/dev/null 2>&1
        home-manager generations
    else
        echo "Home Manager not activated"
        return 1
    end
end
