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
#   jenkins doctor              - Check prerequisites

function jenkins --description "Jenkins CLI for jenkins.thepetlabco.info"
    set -l jenkins_url "https://jenkins.thepetlabco.info"
    set -l jar_dir "$HOME/.local/share/jenkins-cli"
    set -l jar_path "$jar_dir/jenkins-cli.jar"

    # Handle meta-commands before checking java
    switch "$argv[1]"
        case doctor
            _jenkins_doctor "$jenkins_url" "$jar_path"
            return $status
        case update
            _jenkins_download "$jenkins_url" "$jar_dir" "$jar_path"
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

    if test (count $argv) -eq 0
        java -jar "$jar_path" -s "$jenkins_url" help
    else
        java -jar "$jar_path" -s "$jenkins_url" $argv
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

function _jenkins_doctor --description "Check Jenkins CLI prerequisites"
    set -l url $argv[1]
    set -l jar $argv[2]

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

    # Check connectivity
    if curl -fsSL --connect-timeout 5 "$url" >/dev/null 2>&1
        echo "✓ $url reachable"
    else
        echo "✗ $url not reachable"
        echo "  Check VPN/network connectivity"
    end
end
