function secsan --description "Run security scans with fzf selection"
    set -l tools "trivy image" "trivy fs ." "trivy config ." "grype ." "tfsec ." "checkov -d ." "semgrep --config=auto ." "hadolint Dockerfile"

    set -l selected (printf '%s\n' $tools | fzf \
        --prompt="Select security scan to run: " \
        --height=40% \
        --border)

    if test -n "$selected"
        echo "Running: $selected"
        eval $selected
    end
end
