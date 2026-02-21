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

            echo "Syncing skill manifest"
            echo "━━━━━━━━━━━━━━━━━━━━━━"

            # Ensure .claude/skills/ exists
            mkdir -p .claude/skills

            set -l linked 0
            set -l errors 0

            # Parse [sources] section
            set -l in_sources false
            for line in (cat $manifest_file)
                set -l trimmed (string trim $line)

                # Detect section headers
                if string match -q -- '[*]' "$trimmed"
                    if test "$trimmed" = "[sources]"
                        set in_sources true
                    else
                        set in_sources false
                    end
                    continue
                end

                # Skip comments and empty lines
                if test -z "$trimmed"; or string match -q -- '#*' "$trimmed"
                    continue
                end

                if test "$in_sources" = true
                    # Parse: skill-name = "source:path"
                    set -l key (echo $trimmed | string replace -r '\s*=.*$' '')
                    set -l val (echo $trimmed | string replace -r '^[^=]*=\s*' '' | string replace -a '"' '' | string trim)

                    if test -z "$key" -o -z "$val"
                        continue
                    end

                    set -l target ".claude/skills/$key"

                    # Already exists - skip
                    if test -e "$target"
                        if test -L "$target"
                            echo "  ↔ $key (already linked)"
                        else
                            echo "  ⚠ $key (local directory, not managed)"
                        end
                        continue
                    end

                    # Resolve source
                    set -l resolved_path ""
                    if string match -q "dotfiles:*" "$val"
                        # dotfiles:category/skill-name
                        set -l rel (string replace "dotfiles:" "" $val)
                        set resolved_path "$dotfiles_skills/$rel"
                    else if string match -q "path:*" "$val"
                        # path:~/some/path or path:/absolute/path
                        set resolved_path (string replace "path:" "" $val | string replace "~" $HOME)
                    else
                        echo "  ✗ $key (unknown source format: $val)"
                        set errors (math $errors + 1)
                        continue
                    end

                    if test -d "$resolved_path" -a -f "$resolved_path/SKILL.md"
                        ln -s (realpath $resolved_path) $target
                        echo "  ✓ $key → $val"
                        set linked (math $linked + 1)
                    else
                        echo "  ✗ $key (not found: $resolved_path)"
                        set errors (math $errors + 1)
                    end
                end
            end

            echo "━━━━━━━━━━━━━━━━━━━━━━"
            echo "Linked $linked skill(s). Errors: $errors."

        case init
            if test -f $manifest_file
                echo "Manifest already exists: $manifest_file"
                return 1
            end

            mkdir -p .claude
            echo '# Skill Manifest
# Declares which skills this repo needs from the dotfiles library.
# Run: skills-manifest sync  (to materialize symlinks into .claude/skills/)

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
            if not test -d .claude/skills
                echo "No .claude/skills/ directory."
                return 0
            end

            set -l cleaned 0
            for item in .claude/skills/*/
                test -L "$item"; or continue
                set -l link_target (readlink "$item")
                if string match -q "*dotfiles/skills/*" "$link_target"; or string match -q "*dotfiles-skillsperrepo/skills/*" "$link_target"
                    rm "$item"
                    echo "  Removed: "(basename $item)
                    set cleaned (math $cleaned + 1)
                end
            end
            echo "Cleaned $cleaned manifest-managed skill(s)."

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

        case help '*'
            echo "Usage: skills-manifest <command>"
            echo ""
            echo "Commands:"
            echo "  sync     Materialize skill manifest into .claude/skills/ symlinks"
            echo "  init     Create a new skill-manifest.toml in current repo"
            echo "  clean    Remove manifest-managed symlinks from .claude/skills/"
            echo "  status   Show current manifest and linked skills"
            echo "  help     Show this help"
            echo ""
            echo "Manifest file: .claude/skill-manifest.toml"
            echo "See: skills/README.md"
    end
end
