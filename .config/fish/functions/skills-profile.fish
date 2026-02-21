function skills-profile --description "Manage Claude Code skill profiles per device/repo"
    set -l cmd $argv[1]
    set -l dotfiles_skills ~/dotfiles/skills
    set -l claude_skills ~/.claude/skills
    set -l profile_dir $dotfiles_skills/profiles
    set -l active_file ~/.claude/active-skill-profile

    switch "$cmd"
        case activate
            set -l profile_name $argv[2]
            if test -z "$profile_name"
                echo "Usage: skills-profile activate <profile-name>"
                echo "Run 'skills-profile list' to see available profiles."
                return 1
            end

            set -l profile_file $profile_dir/$profile_name.toml
            if not test -f "$profile_file"
                echo "Profile not found: $profile_name"
                echo "Available profiles:"
                _skills_profile_list_profiles
                return 1
            end

            echo "Activating skill profile: $profile_name"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

            # Ensure target directory exists
            mkdir -p $claude_skills

            # Remove existing profile-managed symlinks (those pointing into dotfiles/skills/)
            _skills_profile_clean_managed $claude_skills $dotfiles_skills

            # Parse profile and create symlinks
            set -l linked 0
            set -l errors 0

            # Parse include categories
            set -l categories (_skills_profile_parse_includes $profile_file)
            for category in $categories
                set -l category_dir $dotfiles_skills/$category
                if not test -d "$category_dir"
                    echo "  ⚠ Category not found: $category"
                    continue
                end

                for skill_dir in $category_dir/*/
                    test -d "$skill_dir"; or continue
                    test -f "$skill_dir/SKILL.md"; or continue

                    set -l skill_name (basename $skill_dir)

                    # Check if excluded
                    if _skills_profile_is_excluded $profile_file $skill_name
                        echo "  ⊘ $skill_name (excluded)"
                        continue
                    end

                    set -l target $claude_skills/$skill_name
                    if test -e "$target"
                        # Skip if already exists (non-managed symlink or directory)
                        if test -L "$target"
                            echo "  ↔ $skill_name (already linked)"
                        else
                            echo "  ⚠ $skill_name (exists, not managed)"
                        end
                    else
                        ln -s $skill_dir $target
                        echo "  ✓ $skill_name ($category)"
                        set linked (math $linked + 1)
                    end
                end
            end

            # Parse and link external skills
            set -l externals (_skills_profile_parse_externals $profile_file)
            for external in $externals
                set -l parts (string split "=" $external)
                set -l ext_name $parts[1]
                set -l ext_path (string replace "~" $HOME $parts[2])

                if not test -d "$ext_path"
                    echo "  ✗ $ext_name (external path not found: $ext_path)"
                    set errors (math $errors + 1)
                    continue
                end

                set -l target $claude_skills/$ext_name
                if test -e "$target"
                    if test -L "$target"
                        echo "  ↔ $ext_name (already linked)"
                    else
                        echo "  ⚠ $ext_name (exists, not managed)"
                    end
                else
                    ln -s $ext_path $target
                    echo "  ✓ $ext_name (external)"
                    set linked (math $linked + 1)
                end
            end

            # Save active profile
            echo $profile_name >$active_file

            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Linked $linked skills. Errors: $errors."
            echo "Profile '$profile_name' is now active."

        case deactivate
            echo "Deactivating skill profile..."
            _skills_profile_clean_managed $claude_skills $dotfiles_skills
            rm -f $active_file
            echo "All profile-managed skills removed."
            echo "External skills (not from dotfiles/skills/) are preserved."

        case list
            echo "Available Skill Profiles"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━"
            _skills_profile_list_profiles

            echo ""
            echo "Skill Library Categories"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━"
            for cat_dir in $dotfiles_skills/*/
                test -d "$cat_dir"; or continue
                set -l cat_name (basename $cat_dir)
                # Skip non-category directories
                test "$cat_name" = profiles; and continue
                set -l count (find $cat_dir -name "SKILL.md" -maxdepth 2 2>/dev/null | wc -l | string trim)
                printf "  %-15s %s skill(s)\n" "$cat_name" "$count"
            end

        case status
            echo "Skills Profile Status"
            echo "━━━━━━━━━━━━━━━━━━━━━"

            # Active profile
            if test -f $active_file
                set -l active (cat $active_file | string trim)
                echo "Active profile: $active"
            else
                echo "Active profile: (none)"
            end

            echo ""

            # List skills in ~/.claude/skills/
            if test -d $claude_skills
                echo "Skills in ~/.claude/skills/:"
                set -l total 0
                set -l managed 0
                set -l external 0
                set -l unmanaged 0

                for item in $claude_skills/*/
                    test -d "$item"; or continue
                    set -l name (basename $item)
                    set total (math $total + 1)

                    if test -L "$item"
                        set -l link_target (readlink "$item")
                        if string match -q "*dotfiles/skills/*" "$link_target"; or string match -q "*dotfiles-skillsperrepo/skills/*" "$link_target"
                            set -l category (_skills_profile_extract_category "$link_target")
                            printf "  %-30s → %s (managed)\n" "$name" "$category"
                            set managed (math $managed + 1)
                        else
                            printf "  %-30s → %s (external)\n" "$name" "$link_target"
                            set external (math $external + 1)
                        end
                    else
                        printf "  %-30s (local)\n" "$name"
                        set unmanaged (math $unmanaged + 1)
                    end
                end

                echo ""
                echo "Total: $total (managed: $managed, external: $external, local: $unmanaged)"
            else
                echo "No skills directory found (~/.claude/skills/)"
            end

        case doctor
            echo "Skills Profile Doctor"
            echo "━━━━━━━━━━━━━━━━━━━━━"

            set -l ok 0
            set -l warn 0
            set -l fail 0

            # Check dotfiles skills directory
            if test -d $dotfiles_skills
                echo "✓ Skills library: $dotfiles_skills"
                set ok (math $ok + 1)
            else
                echo "✗ Skills library not found: $dotfiles_skills"
                set fail (math $fail + 1)
            end

            # Check profiles directory
            if test -d $profile_dir
                set -l profile_count (find $profile_dir -name "*.toml" -maxdepth 1 2>/dev/null | wc -l | string trim)
                echo "✓ Profiles directory: $profile_count profile(s)"
                set ok (math $ok + 1)
            else
                echo "✗ Profiles directory not found: $profile_dir"
                set fail (math $fail + 1)
            end

            # Check ~/.claude/skills/
            if test -d $claude_skills
                echo "✓ Claude skills directory exists"
                set ok (math $ok + 1)
            else
                echo "⚠ No ~/.claude/skills/ directory"
                set warn (math $warn + 1)
            end

            # Check active profile
            if test -f $active_file
                set -l active (cat $active_file | string trim)
                if test -f "$profile_dir/$active.toml"
                    echo "✓ Active profile: $active"
                    set ok (math $ok + 1)
                else
                    echo "⚠ Active profile '$active' but profile file missing"
                    set warn (math $warn + 1)
                end
            else
                echo "⚠ No active profile (run: skills-profile activate <name>)"
                set warn (math $warn + 1)
            end

            # Check for broken symlinks
            if test -d $claude_skills
                set -l broken 0
                for item in $claude_skills/*/
                    if test -L "$item"; and not test -e "$item"
                        echo "  ✗ Broken symlink: $item"
                        set broken (math $broken + 1)
                    end
                end
                if test $broken -gt 0
                    echo "✗ $broken broken symlink(s) found"
                    set fail (math $fail + 1)
                end
            end

            # Check SKILL.md format in library
            set -l bad_format 0
            for skill_file in (find $dotfiles_skills -name "SKILL.md" -not -path "*/profiles/*" 2>/dev/null)
                if not head -1 "$skill_file" | string match -q -- ---
                    echo "  ⚠ Missing frontmatter: $skill_file"
                    set bad_format (math $bad_format + 1)
                end
            end
            if test $bad_format -gt 0
                echo "⚠ $bad_format skill(s) missing YAML frontmatter"
                set warn (math $warn + 1)
            else
                echo "✓ All skills have valid frontmatter"
                set ok (math $ok + 1)
            end

            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Results: $ok ok, $warn warnings, $fail errors"

        case help '*'
            echo "Usage: skills-profile <command> [args]"
            echo ""
            echo "Commands:"
            echo "  activate <name>  Activate a skill profile (symlinks into ~/.claude/skills/)"
            echo "  deactivate       Remove all profile-managed skills"
            echo "  list             List profiles and skill library categories"
            echo "  status           Show current active profile and linked skills"
            echo "  doctor           Health check for skills configuration"
            echo "  help             Show this help"
            echo ""
            echo "Profiles are defined in: ~/dotfiles/skills/profiles/*.toml"
            echo "Skills library is at: ~/dotfiles/skills/{shared,personal,work}/"
            echo ""
            echo "See: skills/README.md"
    end
end

# ── Helper functions ──────────────────────────────────────

function _skills_profile_list_profiles
    set -l profile_dir ~/dotfiles/skills/profiles
    for profile_file in $profile_dir/*.toml
        test -f "$profile_file"; or continue
        set -l name (basename $profile_file .toml)
        set -l desc (grep "^description" $profile_file 2>/dev/null | head -1 | string replace -r '^description\s*=\s*"' '' | string replace -r '"$' '')
        set -l active ""
        if test -f ~/.claude/active-skill-profile
            if test (cat ~/.claude/active-skill-profile | string trim) = "$name"
                set active " ← active"
            end
        end
        printf "  %-15s %s%s\n" "$name" "$desc" "$active"
    end
end

function _skills_profile_clean_managed --argument-names claude_skills dotfiles_skills
    # Remove symlinks that point into the dotfiles skills library
    for item in $claude_skills/*/
        test -L "$item"; or continue
        set -l link_target (readlink "$item")
        if string match -q "*dotfiles/skills/*" "$link_target"; or string match -q "*dotfiles-skillsperrepo/skills/*" "$link_target"
            rm "$item"
        end
    end
end

function _skills_profile_parse_includes --argument-names profile_file
    # Parse include = ["shared", "personal"] from TOML
    set -l line (grep "^include" $profile_file 2>/dev/null | head -1)
    if test -n "$line"
        # Extract array values: include = ["shared", "personal"]
        echo $line | string replace -r '^include\s*=\s*\[' '' | string replace -r '\].*$' '' | string replace -a '"' '' | string replace -a "'" '' | string split "," | string trim
    end
end

function _skills_profile_parse_externals --argument-names profile_file
    # Parse [skills.external] section key=value pairs
    set -l in_section false
    for line in (cat $profile_file)
        set -l trimmed (string trim $line)

        # Detect section headers
        if string match -q -- '[*]' "$trimmed"
            if test "$trimmed" = "[skills.external]"
                set in_section true
            else
                set in_section false
            end
            continue
        end

        # Skip comments and empty lines
        if test -z "$trimmed"; or string match -q -- '#*' "$trimmed"
            continue
        end

        if test "$in_section" = true
            # Parse key = "value"
            set -l key (echo $trimmed | string replace -r '\s*=.*$' '')
            set -l val (echo $trimmed | string replace -r '^[^=]*=\s*' '' | string replace -a '"' '' | string trim)
            if test -n "$key" -a -n "$val"
                echo "$key=$val"
            end
        end
    end
end

function _skills_profile_is_excluded --argument-names profile_file skill_name
    # Check if skill is in exclude list
    set -l line (grep "^exclude" $profile_file 2>/dev/null | head -1)
    if test -n "$line"
        echo $line | string match -q "*$skill_name*"
        return $status
    end
    return 1
end

function _skills_profile_extract_category --argument-names link_target
    # Extract category from path like .../skills/shared/dotfiles-sync
    echo $link_target | string replace -r '.*/skills/' '' | string replace -r '/[^/]*/?$' ''
end
