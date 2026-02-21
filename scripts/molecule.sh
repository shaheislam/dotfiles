#!/usr/bin/env bash
#
# molecule.sh - Durable multi-step workflow state machine (Molecule pattern)
#
# Molecules track ordered steps with checkpoints and resume capability.
# Each molecule is stored as a JSON file in ~/.claude/molecules/.
#
# Usage:
#   molecule.sh create <name> --steps "step1,step2,step3"
#   molecule.sh advance <molecule-id>
#   molecule.sh status <molecule-id> [--json]
#   molecule.sh fail <molecule-id> --reason "msg"
#   molecule.sh retry <molecule-id>
#   molecule.sh list [--active] [--json]
#   molecule.sh resume <molecule-id>
#
# Exit codes:
#   0 - Success
#   1 - Error
#   2 - Molecule complete (no more steps)

set -euo pipefail

MOLECULE_DIR="${HOME}/.claude/molecules"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/json-helpers.sh"

ensure_dir() {
    mkdir -p "$MOLECULE_DIR"
}

timestamp_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

generate_id() {
    printf 'm%x%04x' "$(date +%s)" "$((RANDOM % 65536))"
}

molecule_file() {
    echo "${MOLECULE_DIR}/$1.json"
}

read_molecule() {
    local id="$1"
    local f
    f=$(molecule_file "$id")
    if [[ -f "$f" ]]; then
        cat "$f"
    fi
}

write_molecule() {
    local id="$1" json="$2"
    echo "$json" >"$(molecule_file "$id")"
}

# --- Commands ---

cmd_create() {
    local name="" steps_str=""

    while [[ $# -gt 0 ]]; do
        case $1 in
        --steps)
            steps_str="$2"
            shift 2
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            exit 1
            ;;
        *)
            if [[ -z "$name" ]]; then
                name="$1"
            fi
            shift
            ;;
        esac
    done

    if [[ -z "$name" ]]; then
        echo -e "${RED}Error: Molecule name required${NC}" >&2
        exit 1
    fi

    if [[ -z "$steps_str" ]]; then
        echo -e "${RED}Error: --steps required (comma-separated list)${NC}" >&2
        exit 1
    fi

    ensure_dir

    local id ts
    id="$(generate_id)"
    ts="$(timestamp_now)"

    # Build steps array
    local steps_json
    steps_json=$(echo "$steps_str" | jq -R '[split(",") | .[] | gsub("^ +| +$"; "") | select(length > 0)]')

    local json
    json=$(jq -n --arg id "$id" --arg name "$name" --arg ts "$ts" --argjson steps "$steps_json" '{
  id: $id, name: $name, steps: $steps, current_step: 0,
  step_status: "pending", history: [], created: $ts, updated: $ts
}')

    write_molecule "$id" "$json"

    echo -e "${GREEN}Created molecule${NC} ${BOLD}${id}${NC}: ${name}"
    echo "  Steps: $steps_str"
    echo "  Current: step 0 ($(echo "$steps_json" | jq -r '.[0]'))"
    echo "$id"
}

cmd_advance() {
    local molecule_id="$1"

    if [[ -z "$molecule_id" ]]; then
        echo -e "${RED}Error: molecule-id required${NC}" >&2
        exit 1
    fi

    local json
    json=$(read_molecule "$molecule_id")
    if [[ -z "$json" ]]; then
        echo -e "${RED}Error: Molecule not found: ${molecule_id}${NC}" >&2
        exit 1
    fi

    local ts
    ts="$(timestamp_now)"

    local updated
    updated=$(echo "$json" | jq --arg ts "$ts" '
  .history += [{step: .current_step, name: .steps[.current_step], status: "completed", ended: $ts}]
  | .current_step += 1
  | .updated = $ts
  | if .current_step >= (.steps | length) then .step_status = "complete" else .step_status = "pending" end
')

    write_molecule "$molecule_id" "$updated"

    local current_step total_steps step_status
    current_step=$(echo "$updated" | jq -r '.current_step')
    total_steps=$(echo "$updated" | jq -r '.steps | length')
    step_status=$(echo "$updated" | jq -r '.step_status')

    if [[ "$step_status" == "complete" ]]; then
        local name
        name=$(echo "$updated" | jq -r '.name')
        echo -e "${GREEN}${BOLD}Molecule '${name}' complete!${NC} All ${total_steps} steps done."

        # Send mail notification
        local mail_script
        mail_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/agent-mail.sh"
        if [[ -x "$mail_script" ]]; then
            "$mail_script" send all -s "Molecule Complete: ${name}" -m "All ${total_steps} steps in molecule ${molecule_id} complete." --from "molecule" 2>/dev/null || true
        fi
        exit 2
    else
        local next_step_name
        next_step_name=$(echo "$updated" | jq -r '.steps[.current_step]')
        echo -e "${GREEN}Advanced${NC} to step ${current_step}/${total_steps}: ${next_step_name}"
    fi
}

cmd_status() {
    local molecule_id="" json_mode=false

    while [[ $# -gt 0 ]]; do
        case $1 in
        --json)
            json_mode=true
            shift
            ;;
        -*) shift ;;
        *)
            if [[ -z "$molecule_id" ]]; then
                molecule_id="$1"
            fi
            shift
            ;;
        esac
    done

    if [[ -z "$molecule_id" ]]; then
        echo -e "${RED}Error: molecule-id required${NC}" >&2
        exit 1
    fi

    local json
    json=$(read_molecule "$molecule_id")
    if [[ -z "$json" ]]; then
        echo -e "${RED}Error: Molecule not found: ${molecule_id}${NC}" >&2
        exit 1
    fi

    if $json_mode; then
        echo "$json"
        return
    fi

    local mol_name mol_id mol_current mol_total mol_status mol_created
    mol_name=$(echo "$json" | jq -r '.name')
    mol_id=$(echo "$json" | jq -r '.id')
    mol_current=$(echo "$json" | jq -r '.current_step')
    mol_total=$(echo "$json" | jq -r '.steps | length')
    mol_status=$(echo "$json" | jq -r '.step_status')
    mol_created=$(echo "$json" | jq -r '.created')

    echo "Molecule: ${mol_name} (${mol_id})"
    echo "Progress: step ${mol_current}/${mol_total} (${mol_status})"
    echo "Created:  ${mol_created}"
    echo

    local i=0
    while [[ $i -lt $mol_total ]]; do
        local step_name icon state
        step_name=$(echo "$json" | jq -r --argjson idx "$i" '.steps[$idx]')
        if [[ $i -lt $mol_current ]]; then
            icon='\033[0;32m✓\033[0m'
            state='done'
        elif [[ $i -eq $mol_current ]]; then
            if [[ "$mol_status" == "failed" ]]; then
                icon='\033[0;31m✗\033[0m'
                state='FAILED'
            elif [[ "$mol_status" == "running" ]]; then
                icon='\033[0;34m→\033[0m'
                state='running'
            elif [[ "$mol_status" == "complete" ]]; then
                icon='\033[0;32m✓\033[0m'
                state='done'
            else
                icon='\033[1;33m◆\033[0m'
                state='next'
            fi
        else
            icon='\033[2m·\033[0m'
            state='pending'
        fi
        echo -e "  ${icon} [${i}] ${step_name} (${state})"
        i=$((i + 1))
    done
}

cmd_fail() {
    local molecule_id="" reason=""

    local positional=0
    while [[ $# -gt 0 ]]; do
        case $1 in
        --reason)
            reason="$2"
            shift 2
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            exit 1
            ;;
        *)
            positional=$((positional + 1))
            if [[ $positional -eq 1 ]]; then
                molecule_id="$1"
            fi
            shift
            ;;
        esac
    done

    if [[ -z "$molecule_id" ]]; then
        echo -e "${RED}Error: molecule-id required${NC}" >&2
        exit 1
    fi

    local json
    json=$(read_molecule "$molecule_id")
    if [[ -z "$json" ]]; then
        echo -e "${RED}Error: Molecule not found: ${molecule_id}${NC}" >&2
        exit 1
    fi

    local ts
    ts="$(timestamp_now)"
    local escaped_reason="${reason:-unknown}"

    local updated
    updated=$(echo "$json" | jq --arg ts "$ts" --arg reason "$escaped_reason" '
  .step_status = "failed"
  | .updated = $ts
  | .history += [{step: .current_step, name: .steps[.current_step], status: "failed", reason: $reason, ended: $ts}]
')

    write_molecule "$molecule_id" "$updated"
    echo -e "${RED}Failed${NC} step in molecule ${molecule_id}: ${reason:-unknown}"
}

cmd_retry() {
    local molecule_id="$1"

    if [[ -z "$molecule_id" ]]; then
        echo -e "${RED}Error: molecule-id required${NC}" >&2
        exit 1
    fi

    local json
    json=$(read_molecule "$molecule_id")
    if [[ -z "$json" ]]; then
        echo -e "${RED}Error: Molecule not found: ${molecule_id}${NC}" >&2
        exit 1
    fi

    local ts
    ts="$(timestamp_now)"

    local updated
    updated=$(echo "$json" | jq --arg ts "$ts" '
  if .step_status != "failed" then . else .step_status = "pending" | .updated = $ts end
')

    write_molecule "$molecule_id" "$updated"
    echo -e "${GREEN}Retrying${NC} current step in molecule ${molecule_id}"
}

cmd_list() {
    local active_only=false json_mode=false

    while [[ $# -gt 0 ]]; do
        case $1 in
        --active)
            active_only=true
            shift
            ;;
        --json)
            json_mode=true
            shift
            ;;
        *) shift ;;
        esac
    done

    ensure_dir

    local files
    files=$(ls "$MOLECULE_DIR"/*.json 2>/dev/null) || true

    if [[ -z "$files" ]]; then
        if $json_mode; then
            echo "[]"
        else
            echo "No molecules."
        fi
        return 0
    fi

    if $json_mode; then
        local result="[]"
        for f in $MOLECULE_DIR/*.json; do
            [[ -f "$f" ]] || continue
            local mol
            mol=$(jq '.' "$f")
            local is_complete
            is_complete=$(echo "$mol" | jq -r '.step_status')
            if $active_only && [[ "$is_complete" == "complete" ]]; then
                continue
            fi
            result=$(echo "$result" | jq --argjson mol "$mol" '. += [$mol]')
        done
        echo "$result" | jq '.'
        return
    fi

    echo -e "${BLUE}=== Molecules ===${NC}"
    for f in $MOLECULE_DIR/*.json; do
        [[ -f "$f" ]] || continue
        local mol_id mol_name mol_current mol_total mol_status mol_step_name
        mol_id=$(jq -r '.id' "$f")
        mol_name=$(jq -r '.name' "$f")
        mol_current=$(jq -r '.current_step' "$f")
        mol_total=$(jq -r '.steps | length' "$f")
        mol_status=$(jq -r '.step_status' "$f")

        if $active_only && [[ "$mol_status" == "complete" ]]; then
            continue
        fi

        local bar_len=20 filled
        if [[ "$mol_total" -gt 0 ]]; then
            filled=$((mol_current * bar_len / mol_total))
        else
            filled=0
        fi
        if [[ "$mol_status" == "complete" ]]; then
            filled=$bar_len
        fi
        local bar=""
        local i=0
        while [[ $i -lt $filled ]]; do
            bar+="█"
            i=$((i + 1))
        done
        i=0
        local remaining=$((bar_len - filled))
        while [[ $i -lt $remaining ]]; do
            bar+="░"
            i=$((i + 1))
        done

        local color
        if [[ "$mol_status" == "complete" ]]; then
            color='\033[0;32m'
        elif [[ "$mol_status" == "failed" ]]; then
            color='\033[0;31m'
        else
            color='\033[0;34m'
        fi

        if [[ "$mol_current" -lt "$mol_total" ]]; then
            mol_step_name=$(jq -r --argjson idx "$mol_current" '.steps[$idx]' "$f")
        else
            mol_step_name="done"
        fi

        echo -e "  ${color}${mol_id}\033[0m  ${mol_name}  [${bar}] ${mol_current}/${mol_total} (${mol_step_name})"
    done
}

cmd_resume() {
    local molecule_id="$1"

    if [[ -z "$molecule_id" ]]; then
        echo -e "${RED}Error: molecule-id required${NC}" >&2
        exit 1
    fi

    local json
    json=$(read_molecule "$molecule_id")
    if [[ -z "$json" ]]; then
        echo -e "${RED}Error: Molecule not found: ${molecule_id}${NC}" >&2
        exit 1
    fi

    # Output resume context for the current step
    local mol_name mol_current mol_total mol_status step_name
    mol_name=$(echo "$json" | jq -r '.name')
    mol_current=$(echo "$json" | jq -r '.current_step')
    mol_total=$(echo "$json" | jq -r '.steps | length')
    mol_status=$(echo "$json" | jq -r '.step_status')

    if [[ "$mol_current" -ge "$mol_total" ]]; then
        echo "Molecule complete. No more steps."
        return 0
    fi

    step_name=$(echo "$json" | jq -r '.steps[.current_step]')
    local completed_steps
    completed_steps=$(echo "$json" | jq -r '[.history[] | select(.status == "completed") | .name] | join(", ")')
    local remaining_steps
    remaining_steps=$(echo "$json" | jq -r '[.steps[(.current_step + 1):]] | join(", ")')

    echo "MOLECULE RESUME: ${mol_name} (step ${mol_current}/${mol_total})"
    echo "Current step: ${step_name}"
    echo "Status: ${mol_status}"
    if [[ -n "$completed_steps" ]]; then
        echo "Completed: ${completed_steps}"
    fi
    if [[ -n "$remaining_steps" ]]; then
        echo "Remaining: ${remaining_steps}"
    fi
}

# --- Main ---

show_help() {
    echo "molecule.sh - Durable multi-step workflow state machine"
    echo ""
    echo "USAGE:"
    echo "  molecule.sh <command> [args...]"
    echo ""
    echo "COMMANDS:"
    echo "  create <name> --steps \"s1,s2,s3\"   Create molecule with ordered steps"
    echo "  advance <molecule-id>               Move to next step"
    echo "  status <molecule-id> [--json]        Show current step and progress"
    echo "  fail <molecule-id> [--reason msg]    Mark current step failed"
    echo "  retry <molecule-id>                  Retry failed step"
    echo "  list [--active] [--json]             List molecules"
    echo "  resume <molecule-id>                 Output resume context"
    echo ""
    echo "STORAGE:"
    echo "  ${MOLECULE_DIR}/<id>.json"
}

if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
create) cmd_create "$@" ;;
advance) cmd_advance "$@" ;;
status) cmd_status "$@" ;;
fail) cmd_fail "$@" ;;
retry) cmd_retry "$@" ;;
list) cmd_list "$@" ;;
resume) cmd_resume "$@" ;;
help | --help | -h)
    show_help
    exit 0
    ;;
*)
    echo -e "${RED}Error: Unknown command '$COMMAND'${NC}" >&2
    exit 1
    ;;
esac
