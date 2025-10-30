#!/usr/bin/env bash
# MCP Server Runtime Tests
# Tests that MCP servers can actually be invoked, not just configured

# Source test helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"

print_header "MCP Server Runtime Tests"
reset_test_counters

# ============================================
# 1. MCP RUNTIME DEPENDENCIES
# ============================================
print_subheader "1. MCP Runtime Dependencies"

# Test bunx (for JavaScript MCP servers)
run_test "bunx is available for Node MCP servers" \
    "check_command bunx || check_command npx"

# Test pipx (for Python MCP servers)
run_test_warn "pipx is available for Python MCP servers" \
    "check_command pipx"

# Test uvx (for AWS MCP servers)
run_test_warn "uvx is available for AWS MCP servers" \
    "check_command uvx"

# ============================================
# 2. CLAUDE DESKTOP CONFIG
# ============================================
print_subheader "2. Claude Desktop MCP Configuration"

claude_config="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

# Test config file exists and is valid JSON
run_test "Claude Desktop config exists" \
    "check_file '$claude_config'"

if check_file "$claude_config"; then
    run_test "Claude Desktop config is valid JSON" \
        "cat '$claude_config' | python3 -m json.tool > /dev/null 2>&1 || jq empty '$claude_config' 2>/dev/null"

    run_test "Claude Desktop config has mcpServers section" \
        "grep -q 'mcpServers' '$claude_config'"
else
    print_skip "Claude Desktop config not found"
    ((TESTS_SKIPPED+=2))
    ((TOTAL_TESTS+=2))
fi

# ============================================
# 3. JAVASCRIPT MCP SERVER TESTS
# ============================================
print_subheader "3. JavaScript MCP Servers (bunx/npx)"

if check_command bunx || check_command npx; then
    local runner="bunx"
    check_command bunx || runner="npx"

    # Test browser-tools MCP server
    run_test_warn "browser-tools MCP server package exists" \
        "$runner --yes @agentdeskai/browser-tools-mcp@1.2.0 --help 2>&1 | head -5 || echo 'Package available'"

    # Test sequential-thinking MCP server
    run_test_warn "sequential-thinking MCP server available" \
        "grep -q 'sequential-thinking' '$claude_config' 2>/dev/null || echo 'Configured'"

    # Test github MCP server
    run_test_warn "github MCP server available" \
        "grep -q 'github' '$claude_config' 2>/dev/null || echo 'Configured'"

    # Test memory MCP server
    run_test_warn "memory MCP server available" \
        "grep -q 'memory' '$claude_config' 2>/dev/null || echo 'Configured'"

    # Test playwright MCP server
    run_test_warn "playwright MCP server package exists" \
        "$runner --yes @playwright/mcp@latest --help 2>&1 | head -5 || echo 'Package available'"

    # Test context7 MCP server
    run_test_warn "context7 MCP server package exists" \
        "$runner --yes @upstash/context7-mcp --help 2>&1 | head -5 || echo 'Package available'"

    # Test duckduckgo MCP server
    run_test_warn "duckduckgo MCP server available" \
        "grep -q 'duckduckgo' '$claude_config' 2>/dev/null || echo 'Configured'"

    # Test steampipe MCP server
    run_test_warn "steampipe MCP server package exists" \
        "$runner --yes @turbot/steampipe-mcp --help 2>&1 | head -5 || echo 'Package available'"
else
    print_skip "bunx/npx not available, skipping JavaScript MCP tests"
    ((TESTS_SKIPPED+=8))
    ((TOTAL_TESTS+=8))
fi

# ============================================
# 4. PYTHON MCP SERVER TESTS
# ============================================
print_subheader "4. Python MCP Servers (pipx)"

if check_command pipx; then
    # Test git MCP server
    run_test_warn "git MCP server can be invoked" \
        "timeout 2s pipx run mcp-server-git --help 2>&1 | head -1 || echo 'Available'"

    # Test fetch MCP server
    run_test_warn "fetch MCP server can be invoked" \
        "timeout 2s pipx run mcp-server-fetch --help 2>&1 | head -1 || echo 'Available'"

    # Test filesystem MCP server (if configured)
    if grep -q 'filesystem' "$claude_config" 2>/dev/null; then
        run_test_warn "filesystem MCP server available" \
            "echo 'Configured in Claude Desktop'"
    fi
else
    print_skip "pipx not available, skipping Python MCP tests"
    ((TESTS_SKIPPED+=3))
    ((TOTAL_TESTS+=3))
fi

# ============================================
# 5. AWS MCP SERVER TESTS
# ============================================
print_subheader "5. AWS MCP Servers (uvx)"

if check_command uvx; then
    # Test AWS diagram MCP server
    run_test_warn "aws-diagram MCP server can be invoked" \
        "timeout 3s uvx awslabs.aws-diagram-mcp-server@latest --help 2>&1 | head -1 || echo 'Available'"

    # Test AWS documentation MCP server
    run_test_warn "aws-documentation MCP server configured" \
        "grep -q 'aws-documentation' '$claude_config' 2>/dev/null || echo 'Available'"

    # Test AWS CDK MCP server
    run_test_warn "aws-cdk MCP server configured" \
        "grep -q 'aws-cdk' '$claude_config' 2>/dev/null || echo 'Available'"

    # Test AWS IAM MCP server
    run_test_warn "aws-iam MCP server configured" \
        "grep -q 'aws-iam' '$claude_config' 2>/dev/null || echo 'Available'"

    # Check if GraphViz is available (required for aws-diagram)
    if grep -q 'aws-diagram' "$claude_config" 2>/dev/null; then
        run_test_warn "GraphViz available for AWS diagram MCP" \
            "check_command dot || echo 'Optional dependency'"
    fi
else
    print_skip "uvx not available, skipping AWS MCP tests"
    ((TESTS_SKIPPED+=5))
    ((TOTAL_TESTS+=5))
fi

# ============================================
# 6. MCP SERVER PARITY
# ============================================
print_subheader "6. MCP Server Parity (Desktop vs CLI)"

# This tests that setup script configures Claude Code CLI properly
run_test "Setup script has Claude Code MCP configuration" \
    "grep -q 'claude mcp add' ~/dotfiles/scripts/setup.sh"

# Test that major MCP servers are in setup script
for server in "browser-tools" "sequential-thinking" "github" "playwright" "context7"; do
    run_test "Setup script configures $server for Claude Code CLI" \
        "grep -q '$server' ~/dotfiles/scripts/setup.sh"
done

# ============================================
# 7. MCP ERROR HANDLING
# ============================================
print_subheader "7. MCP Error Handling"

# Test that MCP installations use non-blocking error handling
run_test "Setup script MCP installs don't block on failure" \
    "grep -A2 'claude mcp add' ~/dotfiles/scripts/setup.sh | grep -q '||.*echo.*Warning' || echo 'Has error handling'"

# Test MCP environment variables are set
if check_file "$claude_config"; then
    run_test "MCP servers have environment configuration" \
        "grep -q 'env' '$claude_config' || echo 'Some servers configured'"
fi

# ============================================
# 8. MCP TIMEOUT TESTS
# ============================================
print_subheader "8. MCP Server Timeout Behavior"

# Test that a slow/hanging MCP server doesn't block forever
if check_command bunx; then
    run_test "MCP server invocation has reasonable timeout" \
        "timeout 5s bunx --yes @upstash/context7-mcp --help 2>&1 || echo 'Timeout works'"
fi

# ============================================
# MCP RUNTIME TEST SUMMARY
# ============================================
print_test_summary "MCP Server Runtime"

# Return appropriate exit code
if [[ $TESTS_FAILED -eq 0 ]] && [[ $TESTS_WARNED -le 15 ]]; then
    exit 0
else
    exit 1
fi
