Study the following to maximise efficiency with them...

  🔒 Security & DevSecOps Tools

  - trivy - Container/IaC vulnerability scanner (better than just gitleaks)
  - cosign - Container signing and verification
  - syft - SBOM generation tool
  - grype - Vulnerability scanner for containers
  - tfsec - Terraform security scanner
  - checkov - IaC security scanner (Terraform, CloudFormation, k8s)
  - semgrep - Static analysis security tool
  - nuclei - Vulnerability scanner with templates
  - sops - Secrets management (encrypt files)
  - age - Modern encryption tool

  📊 Observability & Monitoring

  - stern - Multi-pod log tailing
  - dive - Docker image layer explorer
  - ctop - Container metrics viewer
  - duf - Better disk usage viewer
  - gping - Ping with graph
  - hyperfine - Command-line benchmarking
  - oha - HTTP load testing (better than ab)

  🔧 DevOps/SRE Essentials

  - helm - Kubernetes package manager
  - kustomize - Kubernetes config management
  - velero - Backup/restore for Kubernetes
  - argocd - GitOps CD tool (CLI)
  - flux - GitOps toolkit
  - terragrunt - Terraform wrapper for DRY configs
  - tflint - Terraform linter
  - infracost - Cloud cost estimates for Terraform
  - cloud-nuke - Clean up cloud resources

  🌐 Network & Connectivity

  - mtr - Better traceroute
  - nmap - Network discovery
  - tcpdump - Packet analyzer
  - wireshark - Network protocol analyzer (GUI)
  - ngrok - Secure tunnels to localhost
  - httpie - Modern HTTP client
  - curlie - Better curl with httpie interface
  - xh - Friendly HTTP client (Rust-based httpie)
  - grpcurl - Like curl but for gRPC

  📁 Better File/System Tools

  - dust - Better du (disk usage)
  - sd - Better sed (find & replace)
  - choose - Better cut/awk
  - delta - Better git diff (you have git-delta)
  - tokei - Code statistics
  - ncdu - NCurses disk usage
  - lnav - Log file navigator
  - glances - System monitoring (better htop)

  🏗️ Infrastructure Tools

  - pulumi - IaC with real programming languages
  - packer - Image builder
  - vault - Secrets management (CLI)
  - consul - Service mesh/discovery
  - nomad - Workload orchestration

  🐳 Container Tools

  - podman - Docker alternative
  - buildah - Container image builder
  - skopeo - Container image operations
  - hadolint - Dockerfile linter

  📈 Performance & Debugging

  - strace - System call tracer
  - dtrace - Dynamic tracing (macOS)
  - flamegraph - Performance visualization
  - wrk - HTTP benchmarking

  🔄 CI/CD & Automation

  - act - Run GitHub Actions locally
  - pre-commit - Git hooks (you have this!)
  - commitizen - Conventional commits
  - semantic-release - Automated versioning

  🧰 Development Tools

  - direnv - Environment switcher (you have this!)
  - watchexec - Execute commands on file change
  - entr - Run commands on file change
  - just - Command runner (better make)
  - task - Task runner

  1. killp - Enhanced with preview window showing process details
  2. port - Now works without arguments, shows all ports with fzf selection
  3. ports - Interactive filtering with preview showing process details
  4. mem - Live filtering of processes by memory usage with preview
  5. cpu - Live filtering of processes by CPU usage with preview
  6. netstat-tuln - Interactive network connection filtering
  7. dnslookup - Interactive DNS record type selection

  New Interactive Monitors:

  1. procmon - Full-screen interactive process monitor
    - ENTER - View process details
    - CTRL-K - Kill process
    - CTRL-R - Refresh
    - ESC - Exit
  2. portmon - Full-screen interactive port monitor
    - ENTER - View port details
    - CTRL-K - Kill process using port
    - CTRL-R - Refresh
    - ESC - Exit
  3. topmon - Choose between btop, htop, or procs with fzf

  🚀 Key Features

  - Preview Windows - See details before taking action
  - Multi-select - Kill multiple processes at once (TAB to select)
  - Live Refresh - CTRL-R to update data in real-time
  - Interactive Actions - Kill processes directly from fzf
  - Smart Defaults - Functions work with or without arguments
