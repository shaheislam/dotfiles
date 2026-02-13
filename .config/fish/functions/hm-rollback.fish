function hm-rollback --description "Rollback to previous Home Manager generation"
    if command -v home-manager >/dev/null 2>&1
        set -l previous (home-manager generations | head -2 | tail -1 | cut -d' ' -f1)
        if test -n "$previous"
            echo "Rolling back to generation $previous..."
            "$previous/activate"
        else
            echo "No previous generation found"
            return 1
        end
    else
        echo "Home Manager not activated"
        return 1
    end
end
