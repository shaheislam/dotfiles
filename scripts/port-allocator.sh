#!/usr/bin/env bash
# port-allocator.sh — Per-worktree port allocation with file locking
#
# Inspired by superset-sh/superset's port allocation system.
# Prevents port conflicts when running multiple worktree devcontainers.
#
# Each worktree gets a base port from which a range of PORTS_PER_WORKSPACE
# consecutive ports are allocated. The allocation is stored in a JSON file
# with file-locking to prevent races.
#
# Usage:
#   port-allocator.sh allocate <worktree-name>   # Allocate port range, print base port
#   port-allocator.sh release  <worktree-name>   # Release port range
#   port-allocator.sh get      <worktree-name>   # Get existing allocation (no create)
#   port-allocator.sh list                        # List all allocations
#   port-allocator.sh cleanup                     # Remove stale allocations
#   port-allocator.sh env      <worktree-name>   # Print PORT_* env vars for a worktree

set -euo pipefail

# --- Configuration ---
ALLOC_DIR="${HOME}/.claude"
ALLOC_FILE="${ALLOC_DIR}/port-allocations.json"
LOCK_DIR="${ALLOC_DIR}/.port-lock"
BASE_PORT=${GWT_PORT_BASE:-10000}
PORTS_PER_WORKSPACE=${GWT_PORTS_PER_WORKSPACE:-20}
MAX_PORT=65535
LOCK_TIMEOUT=10 # seconds

# Named port offsets within a workspace's range
PORT_NAMES=(
    "APP"     # 0  - Main application
    "API"     # 1  - API server
    "DEV"     # 2  - Dev server (Vite, Webpack, etc.)
    "DB"      # 3  - Database
    "REDIS"   # 4  - Redis/cache
    "QUEUE"   # 5  - Queue worker
    "METRICS" # 6  - Metrics/monitoring
    "DEBUG"   # 7  - Debugger
    "HMR"     # 8  - Hot module reload
    "PROXY"   # 9  - Reverse proxy
    "TEST"    # 10 - Test runner
    "DOCS"    # 11 - Documentation server
    "GRPC"    # 12 - gRPC
    "WS"      # 13 - WebSocket
    "ADMIN"   # 14 - Admin panel
    "SPARE_1" # 15
    "SPARE_2" # 16
    "SPARE_3" # 17
    "SPARE_4" # 18
    "SPARE_5" # 19
)

# --- Lock helpers (mkdir-based, atomic) ---
acquire_lock() {
    local deadline=$((SECONDS + LOCK_TIMEOUT))
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        if [ $SECONDS -ge $deadline ]; then
            # Check for stale lock
            local lock_pid_file="$LOCK_DIR/pid"
            if [ -f "$lock_pid_file" ]; then
                local lock_pid
                lock_pid=$(cat "$lock_pid_file" 2>/dev/null || true)
                if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
                    echo "Removing stale lock (PID $lock_pid)" >&2
                    rm -rf "$LOCK_DIR"
                    continue
                fi
            fi
            echo "Error: Could not acquire port allocation lock (timeout ${LOCK_TIMEOUT}s)" >&2
            return 1
        fi
        sleep 0.1
    done
    echo $$ >"$LOCK_DIR/pid"
}

release_lock() {
    rm -rf "$LOCK_DIR"
}

# --- JSON helpers (jq-based) ---
ensure_alloc_file() {
    mkdir -p "$ALLOC_DIR"
    if [ ! -f "$ALLOC_FILE" ]; then
        echo '{}' >"$ALLOC_FILE"
    fi
}

read_alloc() {
    ensure_alloc_file
    cat "$ALLOC_FILE"
}

write_alloc() {
    local json="$1"
    echo "$json" >"$ALLOC_FILE.tmp"
    mv "$ALLOC_FILE.tmp" "$ALLOC_FILE"
}

# --- Commands ---
cmd_allocate() {
    local name="$1"
    acquire_lock
    trap release_lock EXIT

    local alloc
    alloc=$(read_alloc)

    # Check if already allocated
    local existing
    existing=$(echo "$alloc" | jq -r --arg n "$name" '.[$n].base_port // empty')
    if [ -n "$existing" ]; then
        # Update timestamp, return existing
        alloc=$(echo "$alloc" | jq --arg n "$name" '.[$n].last_used = now')
        write_alloc "$alloc"
        echo "$existing"
        return 0
    fi

    # Find all used base ports
    local used_ports
    used_ports=$(echo "$alloc" | jq '[.[].base_port] | sort')

    # Find next available base port
    local candidate=$BASE_PORT
    while true; do
        if [ $candidate -gt $((MAX_PORT - PORTS_PER_WORKSPACE)) ]; then
            echo "Error: No available port ranges" >&2
            return 1
        fi
        local is_used
        is_used=$(echo "$used_ports" | jq --argjson c "$candidate" --argjson r "$PORTS_PER_WORKSPACE" \
            '[.[] | select(. >= ($c - $r + 1) and . <= ($c + $r - 1))] | length')
        if [ "$is_used" = "0" ]; then
            break
        fi
        candidate=$((candidate + PORTS_PER_WORKSPACE))
    done

    # Allocate
    alloc=$(echo "$alloc" | jq --arg n "$name" --argjson bp "$candidate" --argjson r "$PORTS_PER_WORKSPACE" \
        '.[$n] = { base_port: $bp, range: $r, allocated_at: now, last_used: now }')
    write_alloc "$alloc"

    echo "$candidate"
}

cmd_release() {
    local name="$1"
    acquire_lock
    trap release_lock EXIT

    local alloc
    alloc=$(read_alloc)
    alloc=$(echo "$alloc" | jq --arg n "$name" 'del(.[$n])')
    write_alloc "$alloc"
}

cmd_get() {
    local name="$1"
    local alloc
    alloc=$(read_alloc)
    local port
    port=$(echo "$alloc" | jq -r --arg n "$name" '.[$n].base_port // empty')
    if [ -z "$port" ]; then
        return 1
    fi
    echo "$port"
}

cmd_list() {
    local alloc
    alloc=$(read_alloc)
    if [ "$alloc" = "{}" ]; then
        echo "No port allocations"
        return 0
    fi
    {
        printf "WORKTREE\tPORT_RANGE\tALLOCATED\n"
        echo "$alloc" | jq -r 'to_entries | sort_by(.value.base_port) | .[] |
            "\(.key)\t\(.value.base_port)-\(.value.base_port + .value.range - 1)\t\(.value.allocated_at | todate)"'
    } | column -t -s $'\t'
}

cmd_cleanup() {
    acquire_lock
    trap release_lock EXIT

    local alloc
    alloc=$(read_alloc)
    local names
    names=$(echo "$alloc" | jq -r 'keys[]')

    local removed=0
    for name in $names; do
        # Check if git worktree still exists by looking for its directory
        # Worktree naming: repo-branch → ../repo-branch
        if ! git worktree list --porcelain 2>/dev/null | grep -q "$name"; then
            alloc=$(echo "$alloc" | jq --arg n "$name" 'del(.[$n])')
            echo "Released: $name"
            removed=$((removed + 1))
        fi
    done

    write_alloc "$alloc"
    echo "Cleaned up $removed stale allocation(s)"
}

cmd_env() {
    local name="$1"
    local base
    base=$(cmd_get "$name") || {
        echo "Error: No allocation for '$name'" >&2
        return 1
    }

    local i=0
    for pname in "${PORT_NAMES[@]}"; do
        echo "PORT_${pname}=$((base + i))"
        i=$((i + 1))
    done
    echo "PORT_BASE=$base"
    echo "PORT_RANGE=$PORTS_PER_WORKSPACE"
}

# --- Main ---
case "${1:-}" in
allocate)
    [ -z "${2:-}" ] && {
        echo "Usage: port-allocator.sh allocate <worktree-name>" >&2
        exit 1
    }
    cmd_allocate "$2"
    ;;
release)
    [ -z "${2:-}" ] && {
        echo "Usage: port-allocator.sh release <worktree-name>" >&2
        exit 1
    }
    cmd_release "$2"
    ;;
get)
    [ -z "${2:-}" ] && {
        echo "Usage: port-allocator.sh get <worktree-name>" >&2
        exit 1
    }
    cmd_get "$2"
    ;;
list)
    cmd_list
    ;;
cleanup)
    cmd_cleanup
    ;;
env)
    [ -z "${2:-}" ] && {
        echo "Usage: port-allocator.sh env <worktree-name>" >&2
        exit 1
    }
    cmd_env "$2"
    ;;
*)
    echo "Usage: port-allocator.sh {allocate|release|get|list|cleanup|env} [worktree-name]"
    echo ""
    echo "Per-worktree port allocation to prevent conflicts."
    echo ""
    echo "Commands:"
    echo "  allocate <name>  Allocate port range, print base port"
    echo "  release  <name>  Release port range"
    echo "  get      <name>  Get existing base port (no create)"
    echo "  list             List all allocations"
    echo "  cleanup          Remove allocations for deleted worktrees"
    echo "  env      <name>  Print PORT_* environment variables"
    echo ""
    echo "Environment:"
    echo "  GWT_PORT_BASE              Starting port (default: 10000)"
    echo "  GWT_PORTS_PER_WORKSPACE    Ports per worktree (default: 20)"
    exit 1
    ;;
esac
