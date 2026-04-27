function skills-manifest --description "Manage per-repo skill manifests"
    set -l cmd $argv[1]
    set -l dotfiles_skills ~/dotfiles/skills
    set -l manifest_file .claude/skill-manifest.toml

    switch "$cmd"
        case sync
            if not test -f $manifest_file
                echo "No skill manifest found at: $manifest_file"
                echo "Create one with: skills-manifest init"
                return 1
            end
            ~/dotfiles/scripts/sync-skills-harnesses.sh

        case init
            if test -f $manifest_file
                echo "Manifest already exists: $manifest_file"
                return 1
            end

            mkdir -p .claude
            echo '# Skill Manifest
# Declares which skills this repo needs from the central dotfiles library.
# Run: skills-manifest sync  (to materialize symlinks into all harness surfaces)

[manifest]
description = "Skills for this project"

[sources]
# Format: skill-name = "dotfiles:<category>/<skill-name>"
#         skill-name = "path:<absolute-or-home-relative-path>"
# Example:
# dotfiles-sync = "dotfiles:shared/dotfiles-sync"
# custom-skill = "path:~/my-skills/custom"
' >$manifest_file
            echo "Created: $manifest_file"
            echo "Edit it to add skill sources, then run: skills-manifest sync"

        case clean
            set -l cleaned 0
            for target_dir in .claude/skills .agents/skills .gemini/skills .opencode/skills
                test -d "$target_dir"; or continue
                for item in $target_dir/*/
                    test -L "$item"; or continue
                    set -l link_target (readlink "$item")
                    if string match -q "*skills/*" "$link_target"
                        rm "$item"
                        echo "  Removed: $item"
                        set cleaned (math $cleaned + 1)
                    end
                end
            end
            echo "Cleaned $cleaned harness skill link(s)."

        case status
            echo "Skill Manifest Status"
            echo "━━━━━━━━━━━━━━━━━━━━━"

            if test -f $manifest_file
                echo "Manifest: $manifest_file"
            else
                echo "No manifest found. Run: skills-manifest init"
                return 0
            end

            echo ""
            if test -d .claude/skills
                echo "Project skills (.claude/skills/):"
                for item in .claude/skills/*/
                    test -d "$item"; or continue
                    set -l name (basename $item)
                    if test -L "$item"
                        set -l link_target (readlink "$item")
                        printf "  %-25s → %s\n" "$name" "$link_target"
                    else
                        printf "  %-25s (local)\n" "$name"
                    end
                end
            else
                echo "No .claude/skills/ directory. Run: skills-manifest sync"
            end

            echo ""
            echo "Harness targets:"
            for target_dir in .claude/skills .agents/skills .gemini/skills .opencode/skills
                if test -d "$target_dir"
                    set -l count (find "$target_dir" -name SKILL.md -maxdepth 2 2>/dev/null | wc -l | string trim)
                    printf "  %-18s %s skill(s)\n" "$target_dir" "$count"
                else
                    printf "  %-18s missing\n" "$target_dir"
                end
            end

        case help '*'
            echo "Usage: skills-manifest <command>"
            echo ""
            echo "Commands:"
            echo "  sync     Materialize central skills into all harness skill surfaces"
            echo "  init     Create a new skill-manifest.toml in current repo"
            echo "  clean    Remove manifest-managed symlinks from .claude/skills/"
            echo "  status   Show current manifest and linked skills"
            echo "  help     Show this help"
            echo ""
            echo "Manifest file: .claude/skill-manifest.toml"
            echo "See: skills/README.md"
    end
end
