#!/usr/bin/env bash
# Materialize the central dotfiles skill library into AI harness skill surfaces.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_ROOT="$DOTFILES_ROOT/skills"
MANIFEST_FILE="$DOTFILES_ROOT/.claude/skill-manifest.toml"

TARGETS=(
    ".claude/skills"
    ".agents/skills"
    ".gemini/skills"
    ".opencode/skills"
    ".pi/agent/skills"
)

usage() {
    cat <<'EOF'
Usage: scripts/sync-skills-harnesses.sh [--check]

Links central skills into harness-specific skill directories:
  .claude/skills   Claude Code
  .agents/skills   Codex CLI / Agent Skills standard
  .gemini/skills   Gemini CLI / Agent Skills standard
  .opencode/skills OpenCode bridge surface
  .pi/agent/skills Pi coding agent global skills

Default mode creates or refreshes managed symlinks. --check reports drift only.
EOF
}

CHECK_ONLY=false
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
elif [[ "${1:-}" == "--check" ]]; then
    CHECK_ONLY=true
elif [[ -n "${1:-}" ]]; then
    usage >&2
    exit 2
fi

resolve_source() {
    local value="$1"

    case "$value" in
    dotfiles:*)
        printf '%s/%s\n' "$SKILLS_ROOT" "${value#dotfiles:}"
        ;;
    path:~*)
        printf '%s%s\n' "$HOME" "${value#path:~}"
        ;;
    path:*)
        printf '%s\n' "${value#path:}"
        ;;
    *)
        return 1
        ;;
    esac
}

collect_sources() {
    local category skill_dir name

    for category in shared personal work; do
        [[ -d "$SKILLS_ROOT/$category" ]] || continue
        for skill_dir in "$SKILLS_ROOT/$category"/*; do
            [[ -d "$skill_dir" && -f "$skill_dir/SKILL.md" ]] || continue
            name="$(basename "$skill_dir")"
            printf '%s\t%s\n' "$name" "$skill_dir"
        done
    done

    [[ -f "$MANIFEST_FILE" ]] || return 0

    local in_sources=false line trimmed key value resolved
    while IFS= read -r line; do
        trimmed="${line#"${line%%[![:space:]]*}"}"
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

        [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue

        if [[ "$trimmed" == \[*\] ]]; then
            if [[ "$trimmed" == "[sources]" ]]; then
                in_sources=true
            else
                in_sources=false
            fi
            continue
        fi

        [[ "$in_sources" == true && "$trimmed" == *=* ]] || continue

        key="${trimmed%%=*}"
        key="${key//[[:space:]]/}"
        value="${trimmed#*=}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"

        resolved="$(resolve_source "$value")" || {
            printf 'WARN: manifest source %s has unsupported value: %s\n' "$key" "$value" >&2
            continue
        }
        [[ -d "$resolved" && -f "$resolved/SKILL.md" ]] || {
            printf 'WARN: manifest source %s not found: %s\n' "$key" "$resolved" >&2
            continue
        }
        printf '%s\t%s\n' "$key" "$resolved"
    done <"$MANIFEST_FILE"
}

is_managed_link() {
    local target="$1"
    [[ -L "$target" ]] || return 1

    local link_target resolved
    link_target="$(readlink "$target")"
    case "$link_target" in
    /*) resolved="$link_target" ;;
    *) resolved="$(cd "$(dirname "$target")" && cd "$(dirname "$link_target")" && pwd)/$(basename "$link_target")" ;;
    esac

    [[ "$resolved" == "$SKILLS_ROOT"/* || "$resolved" == "$HOME"/.agents/skills/* ]]
}

absolute_path() {
    local path="$1"
    local dir base

    dir="$(dirname "$path")"
    base="$(basename "$path")"
    printf '%s/%s\n' "$(cd "$dir" && pwd -P)" "$base"
}

resolved_link_path() {
    local target="$1"
    local link_target

    link_target="$(readlink "$target")"
    case "$link_target" in
    /*) absolute_path "$link_target" ;;
    *) absolute_path "$(dirname "$target")/$link_target" ;;
    esac
}

link_resolves_to() {
    local target="$1"
    local expected="$2"
    [[ -L "$target" ]] || return 1

    [[ "$(resolved_link_path "$target")" == "$(absolute_path "$expected")" ]]
}

link_skill() {
    local name="$1"
    local source_dir="$2"
    local target_root="$3"
    local target="$target_root/$name"
    local rel_target

    if [[ -e "$target" || -L "$target" ]]; then
        if is_managed_link "$target"; then
            if [[ "$CHECK_ONLY" == false ]]; then
                rm "$target"
            fi
        else
            printf 'KEEP: %s exists and is not a managed skill link\n' "${target#$DOTFILES_ROOT/}"
            return 0
        fi
    fi

    if [[ "$CHECK_ONLY" == true ]]; then
        if link_resolves_to "$target" "$source_dir"; then
            return 0
        fi
        printf 'DRIFT: %s should link to %s\n' "${target#$DOTFILES_ROOT/}" "$source_dir"
        return 1
    fi

    mkdir -p "$target_root"
    rel_target="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$source_dir" "$target_root")"
    ln -s "$rel_target" "$target"
    printf 'LINK: %s -> %s\n' "${target#$DOTFILES_ROOT/}" "$rel_target"
}

main() {
    [[ -d "$SKILLS_ROOT" ]] || {
        printf 'Missing central skills directory: %s\n' "$SKILLS_ROOT" >&2
        exit 1
    }

    local target rel_target_root name source_dir failures=0

    while IFS=$'\t' read -r name source_dir; do
        [[ -n "$name" && -n "$source_dir" ]] || continue
        for target in "${TARGETS[@]}"; do
            rel_target_root="$DOTFILES_ROOT/$target"
            link_skill "$name" "$source_dir" "$rel_target_root" || failures=$((failures + 1))
        done
    done < <(collect_sources | sort -u)

    if [[ "$CHECK_ONLY" == true && "$failures" -gt 0 ]]; then
        printf 'Skill harness drift detected: %s issue(s)\n' "$failures" >&2
        exit 1
    fi
}

main "$@"
