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
    steps_json=$(python3 -c "
import json
steps = [s.strip() for s in '$steps_str'.split(',') if s.strip()]
print(json.dumps(steps))" 2>/dev/null)

    local json
    json=$(python3 -c "
import json
steps = json.loads('$steps_json')
mol = {
    'id': '$id',
    'name': '$name',
    'steps': steps,
    'current_step': 0,
    'step_status': 'pending',
    'history': [],
    'created': '$ts',
    'updated': '$ts'
}
print(json.dumps(mol, indent=2))" 2>/dev/null)

    write_molecule "$id" "$json"

    echo -e "${GREEN}Created molecule${NC} ${BOLD}${id}${NC}: ${name}"
    echo "  Steps: $steps_str"
    echo "  Current: step 0 ($(echo "$steps_json" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())[0])" 2>/dev/null))"
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
    updated=$(echo "$json" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
ts = '$ts'

# Record completion of current step
m['history'].append({
    'step': m['current_step'],
    'name': m['steps'][m['current_step']],
    'status': 'completed',
    'ended': ts
})

# Advance to next step
m['current_step'] += 1
m['updated'] = ts

if m['current_step'] >= len(m['steps']):
    m['step_status'] = 'complete'
    print(json.dumps(m, indent=2))
else:
    m['step_status'] = 'pending'
    print(json.dumps(m, indent=2))
" 2>/dev/null)

    write_molecule "$molecule_id" "$updated"

    local current_step total_steps step_status
    current_step=$(echo "$updated" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['current_step'])" 2>/dev/null)
    total_steps=$(echo "$updated" | python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())['steps']))" 2>/dev/null)
    step_status=$(echo "$updated" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['step_status'])" 2>/dev/null)

    if [[ "$step_status" == "complete" ]]; then
        local name
        name=$(echo "$updated" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['name'])" 2>/dev/null)
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
        next_step_name=$(echo "$updated" | python3 -c "import sys,json; m=json.loads(sys.stdin.read()); print(m['steps'][m['current_step']])" 2>/dev/null)
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

    echo "$json" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
total = len(m['steps'])
current = m['current_step']
status = m['step_status']

print(f\"Molecule: {m['name']} ({m['id']})\")
print(f\"Progress: step {current}/{total} ({status})\")
print(f\"Created:  {m['created']}\")
print()
for i, step in enumerate(m['steps']):
    if i < current:
        icon = '\033[0;32m✓\033[0m'
        state = 'done'
    elif i == current:
        if status == 'failed':
            icon = '\033[0;31m✗\033[0m'
            state = 'FAILED'
        elif status == 'running':
            icon = '\033[0;34m→\033[0m'
            state = 'running'
        elif status == 'complete':
            icon = '\033[0;32m✓\033[0m'
            state = 'done'
        else:
            icon = '\033[1;33m◆\033[0m'
            state = 'next'
    else:
        icon = '\033[2m·\033[0m'
        state = 'pending'
    print(f'  {icon} [{i}] {step} ({state})')
" 2>/dev/null
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
    updated=$(echo "$json" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
m['step_status'] = 'failed'
m['updated'] = '$ts'
m['history'].append({
    'step': m['current_step'],
    'name': m['steps'][m['current_step']],
    'status': 'failed',
    'reason': '''$escaped_reason''',
    'ended': '$ts'
})
print(json.dumps(m, indent=2))" 2>/dev/null)

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
    updated=$(echo "$json" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
if m['step_status'] != 'failed':
    print(json.dumps(m, indent=2))
    sys.exit(0)
m['step_status'] = 'pending'
m['updated'] = '$ts'
print(json.dumps(m, indent=2))" 2>/dev/null)

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
        python3 -c "
import os, json, glob
molecules = []
active_only = $([[ "$active_only" == "true" ]] && echo "True" || echo "False")
for f in sorted(glob.glob('$MOLECULE_DIR/*.json')):
    with open(f) as fh:
        m = json.load(fh)
    is_complete = m['step_status'] == 'complete'
    if active_only and is_complete:
        continue
    molecules.append(m)
print(json.dumps(molecules, indent=2))" 2>/dev/null
        return
    fi

    echo -e "${BLUE}=== Molecules ===${NC}"
    for f in $MOLECULE_DIR/*.json; do
        [[ -f "$f" ]] || continue
        python3 -c "
import json
with open('$f') as fh:
    m = json.load(fh)
total = len(m['steps'])
current = m['current_step']
status = m['step_status']
active_only = $([[ "$active_only" == "true" ]] && echo "True" || echo "False")
is_complete = status == 'complete'
if active_only and is_complete:
    import sys; sys.exit(0)
bar_len = 20
filled = int(current / total * bar_len) if total > 0 else 0
if is_complete: filled = bar_len
bar = '█' * filled + '░' * (bar_len - filled)
color = '\033[0;32m' if is_complete else ('\033[0;31m' if status == 'failed' else '\033[0;34m')
step_name = m['steps'][current] if current < total else 'done'
print(f\"  {color}{m['id']}\033[0m  {m['name']}  [{bar}] {current}/{total} ({step_name})\")
" 2>/dev/null || true
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
    echo "$json" | python3 -c "
import sys, json
m = json.loads(sys.stdin.read())
total = len(m['steps'])
current = m['current_step']

if current >= total:
    print('Molecule complete. No more steps.')
    sys.exit(0)

step_name = m['steps'][current]
completed_steps = [h['name'] for h in m['history'] if h['status'] == 'completed']

print(f'MOLECULE RESUME: {m[\"name\"]} (step {current}/{total})')
print(f'Current step: {step_name}')
print(f'Status: {m[\"step_status\"]}')
if completed_steps:
    print(f'Completed: {\", \".join(completed_steps)}')
remaining = m['steps'][current+1:]
if remaining:
    print(f'Remaining: {\", \".join(remaining)}')
" 2>/dev/null
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
