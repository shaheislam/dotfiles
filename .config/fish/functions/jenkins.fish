# Jenkins CLI wrapper
# Thin wrapper around jenkins-cli.jar for https://jenkins.thepetlabco.info/
# Auto-downloads the jar on first use; hardcoded to single endpoint.
#
# Usage:
#   jenkins help                - List available commands
#   jenkins build <job>         - Build a job
#   jenkins list-jobs           - List all jobs
#   jenkins console <job>       - Get console output
#   jenkins who-am-i            - Check credentials
#   jenkins version             - Show Jenkins version
#   jenkins update              - Re-download jenkins-cli.jar
#   jenkins setup               - Configure authentication
#   jenkins doctor              - Check prerequisites

function jenkins --description "Jenkins CLI for jenkins.thepetlabco.info"
    set -l jenkins_url "https://jenkins.thepetlabco.info"
    set -l jar_dir "$HOME/.local/share/jenkins-cli"
    set -l jar_path "$jar_dir/jenkins-cli.jar"
    set -l auth_path "$jar_dir/auth"

    # Handle meta-commands before checking java
    switch "$argv[1]"
        case doctor
            _jenkins_doctor "$jenkins_url" "$jar_path" "$auth_path"
            return $status
        case update
            _jenkins_download "$jenkins_url" "$jar_dir" "$jar_path"
            return $status
        case setup
            _jenkins_setup "$auth_path"
            return $status
    end

    # Ensure java is available
    if not command -q java
        echo "Error: java not found. Install with: brew install openjdk"
        echo "Then symlink: sudo ln -sfn (brew --prefix openjdk)/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk"
        return 1
    end

    # Auto-download jar on first use
    if not test -f "$jar_path"
        echo "Jenkins CLI jar not found. Downloading..."
        _jenkins_download "$jenkins_url" "$jar_dir" "$jar_path"
        or return 1
    end

    # Build auth args if credentials file exists
    set -l auth_args
    if test -f "$auth_path"
        set auth_args -auth @$auth_path
    else
        echo "Warning: No auth configured. Run 'jenkins setup' for authenticated access." >&2
    end

    if test (count $argv) -eq 0
        java -jar "$jar_path" -s "$jenkins_url" $auth_args help
    else
        java -jar "$jar_path" -s "$jenkins_url" $auth_args $argv
    end
end

function _jenkins_download --description "Download jenkins-cli.jar from server"
    set -l url $argv[1]
    set -l dir $argv[2]
    set -l path $argv[3]

    mkdir -p "$dir"
    echo "Downloading jenkins-cli.jar from $url..."
    if curl -fsSL "$url/jnlpJars/jenkins-cli.jar" -o "$path"
        echo "Saved to $path"
    else
        echo "Error: Failed to download jenkins-cli.jar"
        echo "Check network connectivity and that $url is reachable."
        return 1
    end
end

function _jenkins_setup --description "Configure Jenkins CLI authentication"
    set -l auth_path $argv[1]
    set -l dir (path dirname "$auth_path")

    if test -f "$auth_path"
        echo "Auth file already exists at $auth_path"
        read -l -P "Overwrite? [y/N] " confirm
        if test "$confirm" != y -a "$confirm" != Y
            return 0
        end
    end

    echo "Jenkins CLI Authentication Setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Get your API token from: https://jenkins.thepetlabco.info/me/security/"
    echo ""

    read -l -P "Username: " username
    if test -z "$username"
        echo "Error: Username cannot be empty"
        return 1
    end

    read -l -P "API Token: " token
    if test -z "$token"
        echo "Error: API token cannot be empty"
        return 1
    end

    mkdir -p "$dir"
    echo "$username:$token" >"$auth_path"
    chmod 600 "$auth_path"
    echo "Auth saved to $auth_path (mode 600)"
end

function _jenkins_doctor --description "Check Jenkins CLI prerequisites"
    set -l url $argv[1]
    set -l jar $argv[2]
    set -l auth $argv[3]

    echo "Jenkins CLI Doctor"
    echo "━━━━━━━━━━━━━━━━━"

    # Check Java
    if command -q java
        set -l ver (java --version 2>&1 | head -1)
        echo "✓ Java: $ver"
    else
        echo "✗ Java not found"
        echo "  Fix: brew install openjdk"
    end

    # Check jar
    if test -f "$jar"
        set -l size (command stat -f%z "$jar" 2>/dev/null; or command stat -c%s "$jar" 2>/dev/null)
        echo "✓ jenkins-cli.jar ($size bytes)"
    else
        echo "✗ jenkins-cli.jar not downloaded"
        echo "  Fix: jenkins update"
    end

    # Check auth
    if test -f "$auth"
        set -l perms (command stat -f%Lp "$auth" 2>/dev/null; or command stat -c%a "$auth" 2>/dev/null)
        if test "$perms" = 600
            echo "✓ Auth configured (mode $perms)"
        else
            echo "⚠ Auth file exists but permissions are $perms (expected 600)"
            echo "  Fix: chmod 600 $auth"
        end
    else
        echo "✗ Auth not configured"
        echo "  Fix: jenkins setup"
    end

    # Check connectivity
    if curl -fsSL --connect-timeout 5 "$url" >/dev/null 2>&1
        echo "✓ $url reachable"
    else
        echo "✗ $url not reachable"
        echo "  Check VPN/network connectivity"
    end
end
