# Useful Tools & Resources

A collection of useful development tools, libraries, and resources used in this dotfiles configuration.

## Shell & Terminal

### Core Shell Tools
- **[Fish](https://fishshell.com/)** - Smart and user-friendly command line shell
- **[Starship](https://starship.rs/)** - Minimal, fast, customizable prompt for any shell
- **[Atuin](https://atuin.sh/)** - Magical shell history with sync and context
- **[Zoxide](https://github.com/ajeetdsouza/zoxide)** - Smarter cd command inspired by z and autojump
- **[Direnv](https://direnv.net/)** - Shell extension for managing environment variables
- **[Carapace](https://carapace-sh.github.io/)** - Multi-shell completion generator

### Terminal Multiplexer
- **[tmux](https://github.com/tmux/tmux)** - Terminal multiplexer
- **[tmux-fingers](https://github.com/morantron/tmux-fingers)** - Copy-paste from tmux with keyboard shortcuts
- **[Tmuxinator](https://github.com/tmuxinator/tmuxinator)** - Manage complex tmux sessions

### Modern CLI Replacements
- **[Bat](https://github.com/sharkdp/bat)** - Cat clone with syntax highlighting and Git integration
- **[Eza](https://github.com/eza-community/eza)** - Modern replacement for ls
- **[Ripgrep](https://github.com/BurntSushi/ripgrep)** - Fast search tool (grep alternative)
- **[Fd](https://github.com/sharkdp/fd)** - Fast and user-friendly alternative to find
- **[Delta](https://github.com/dandavison/delta)** - Syntax-highlighting pager for git, diff, and grep
- **[Fzf](https://github.com/junegunn/fzf)** - Command-line fuzzy finder
- **[Dust](https://github.com/bootandy/dust)** - More intuitive du
- **[Duf](https://github.com/muesli/duf)** - Disk usage analyzer (df alternative)
- **[Procs](https://github.com/dalance/procs)** - Modern replacement for ps
- **[SD](https://github.com/chmln/sd)** - Intuitive find & replace (sed alternative)

### File Management
- **[Yazi](https://yazi-rs.github.io/)** - Blazing fast terminal file manager
- **[Stow](https://www.gnu.org/software/stow/)** - Symlink farm manager for dotfiles
- **[Tree-sitter](https://tree-sitter.github.io/)** - Parser generator tool and incremental parsing library

### Terminal Emulators
- **[WezTerm](https://wezfurlong.org/wezterm/)** - GPU-accelerated cross-platform terminal emulator

## Development Tools

### Editors
- **[Neovim](https://neovim.io/)** - Hyperextensible Vim-based text editor
  - Using LazyVim distribution

### AI & Code Assistance
- **[Claude Code CLI](https://claude.ai/download)** - Official Claude AI command-line interface
- **[Gemini CLI](https://github.com/google/generative-ai-cli)** - Google Gemini command-line interface

### Version Control
- **[Git](https://git-scm.com/)** - Distributed version control system
- **[GitHub CLI](https://cli.github.com/)** - GitHub command-line tool
- **[Jujutsu](https://github.com/martinvonz/jj)** - Version control system with git compatibility

### Languages & Runtimes
- **[Node.js](https://nodejs.org/)** - JavaScript runtime
- **[Bun](https://bun.sh/)** - Fast all-in-one JavaScript runtime
- **[pnpm](https://pnpm.io/)** - Fast, disk space efficient package manager
- **[Python 3.11](https://www.python.org/)** - Programming language
- **[Go](https://go.dev/)** - Programming language
- **[Rust](https://www.rust-lang.org/)** - Programming language
- **[Crystal](https://crystal-lang.org/)** - Programming language
- **[UV](https://github.com/astral-sh/uv)** - Extremely fast Python package installer

### Language Version Managers
- **[Mise](https://mise.jdx.dev/)** - Polyglot runtime manager (asdf alternative)
- **[asdf](https://asdf-vm.com/)** - Extendable version manager

### Code Quality & Formatting
- **[Black](https://black.readthedocs.io/)** - Python code formatter
- **[isort](https://pycqa.github.io/isort/)** - Python import sorter
- **[StyLua](https://github.com/JohnnyMorganz/StyLua)** - Lua code formatter
- **[ShellCheck](https://www.shellcheck.net/)** - Shell script analysis tool
- **[shfmt](https://github.com/mvdan/sh)** - Shell script formatter

### Build & Task Tools
- **[Just](https://github.com/casey/just)** - Command runner
- **[Task](https://taskfile.dev/)** - Task runner / simpler Make alternative

## Cloud & Infrastructure

### AWS Tools
- **[AWS CLI](https://aws.amazon.com/cli/)** - AWS command-line interface
- **[Granted](https://github.com/common-fate/granted)** - CLI for managing AWS profiles
- **[e1s](https://github.com/keidarcy/e1s)** - Terminal UI for AWS ECS
- **[Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)** - AWS Systems Manager Session Manager plugin

### Azure Tools
- **[Azure CLI](https://docs.microsoft.com/en-us/cli/azure/)** - Azure command-line interface
- **[Kubelogin](https://github.com/Azure/kubelogin)** - Kubernetes credential plugin for Azure

### Kubernetes
- **[kubectl](https://kubernetes.io/docs/tasks/tools/)** - Kubernetes command-line tool
- **[Minikube](https://minikube.sigs.k8s.io/)** - Local Kubernetes development
- **[k3d](https://k3d.io/)** - k3s in Docker (lightweight Kubernetes)
- **[Kind](https://kind.sigs.k8s.io/)** - Kubernetes in Docker
- **[Kubectx](https://github.com/ahmetb/kubectx)** - Fast context switching
- **[Kubens](https://github.com/ahmetb/kubectx)** - Fast namespace switching
- **[Kubie](https://github.com/sbstp/kubie)** - Alternative kubectl context manager
- **[Helm](https://helm.sh/)** - Kubernetes package manager
- **[Kustomize](https://kustomize.io/)** - Kubernetes configuration customization
- **[Stern](https://github.com/stern/stern)** - Multi-pod log tailing
- **[Velero](https://velero.io/)** - Kubernetes backup and restore
- **[ArgoCD](https://argo-cd.readthedocs.io/)** - GitOps continuous delivery
- **[Flux](https://fluxcd.io/)** - GitOps toolkit

### Infrastructure as Code
- **[Terraform](https://www.terraform.io/)** - Infrastructure as code tool
- **[Terragrunt](https://terragrunt.gruntwork.io/)** - Terraform wrapper
- **[Terraform Docs](https://terraform-docs.io/)** - Generate Terraform documentation
- **[TFLint](https://github.com/terraform-linters/tflint)** - Terraform linter
- **[TFSec](https://aquasecurity.github.io/tfsec/)** - Terraform security scanner
- **[Infracost](https://www.infracost.io/)** - Cloud cost estimates for Terraform
- **[Pulumi](https://www.pulumi.com/)** - Modern infrastructure as code

### Containers
- **[Podman](https://podman.io/)** - Daemonless container engine
- **[Skopeo](https://github.com/containers/skopeo)** - Container image operations
- **[Lazydocker](https://github.com/jesseduffield/lazydocker)** - Terminal UI for Docker
- **[Dive](https://github.com/wagoodman/dive)** - Docker image layer explorer
- **[ctop](https://github.com/bcicen/ctop)** - Container metrics viewer

### Diagram & Visualization
- **[Diagrams](https://diagrams.mingrammer.com/)** - Diagram as Code for prototyping cloud system architecture
  - Python library for creating architecture diagrams
  - Supports AWS, Azure, GCP, Kubernetes, and more
  - Required by: `aws-diagram-mcp-server`
  - Installation: `pipx install diagrams`
  - Dependencies: `graphviz` (via Homebrew)
- **[Graphviz](https://graphviz.org/)** - Graph visualization software

## Security & DevSecOps

### Vulnerability Scanning
- **[Trivy](https://github.com/aquasecurity/trivy)** - Comprehensive security scanner
- **[Grype](https://github.com/anchore/grype)** - Vulnerability scanner for container images
- **[Syft](https://github.com/anchore/syft)** - SBOM generator
- **[Nuclei](https://github.com/projectdiscovery/nuclei)** - Vulnerability scanner
- **[Semgrep](https://semgrep.dev/)** - Static analysis tool
- **[Hadolint](https://github.com/hadolint/hadolint)** - Dockerfile linter
- **[Checkov](https://www.checkov.io/)** - Infrastructure as code security scanner
- **[GitLeaks](https://github.com/gitleaks/gitleaks)** - Secret scanner

### Secrets Management
- **[SOPS](https://github.com/getsops/sops)** - Secrets management
- **[Age](https://github.com/FiloSottile/age)** - Modern file encryption
- **[Cosign](https://github.com/sigstore/cosign)** - Container signing and verification

### Code Security
- **[Vet](https://vet.run/)** - Policy-driven security and compliance scanner

## Observability & Monitoring

### System Monitoring
- **[Bottom](https://github.com/ClementTsang/bottom)** - System monitor (btm)
- **[htop](https://htop.dev/)** - Interactive process viewer
- **[btop](https://github.com/aristocratos/btop)** - Resource monitor
- **[Glances](https://nicolargo.github.io/glances/)** - Cross-platform system monitoring
- **[Bandwhich](https://github.com/imsnif/bandwhich)** - Network utilization monitor

### Log Analysis
- **[lnav](https://lnav.org/)** - Log file navigator
- **[Splash](https://github.com/joshi4/splash)** - Log colorizer

### Performance & Benchmarking
- **[Hyperfine](https://github.com/sharkdp/hyperfine)** - Command-line benchmarking tool
- **[wrk](https://github.com/wg/wrk)** - HTTP benchmarking tool
- **[oha](https://github.com/hatoo/oha)** - HTTP load generator
- **[FlameGraph](https://github.com/brendangregg/FlameGraph)** - Performance profiling

## Network Tools

### Network Utilities
- **[mtr](https://www.bitwizard.nl/mtr/)** - Network diagnostic tool
- **[nmap](https://nmap.org/)** - Network mapper
- **[tcpdump](https://www.tcpdump.org/)** - Packet analyzer
- **[gping](https://github.com/orf/gping)** - Ping with graph
- **[Doggo](https://github.com/mr-karan/doggo)** - Modern DNS client

### HTTP Clients
- **[HTTPie](https://httpie.io/)** - User-friendly HTTP client
- **[curlie](https://github.com/rs/curlie)** - curl + HTTPie features
- **[xh](https://github.com/ducaale/xh)** - Friendly HTTP client
- **[gRPCurl](https://github.com/fullstorydev/grpcurl)** - cURL-like tool for gRPC
- **[ngrok](https://ngrok.com/)** - Tunneling and reverse proxy

## File & System Tools

### File Analysis
- **[Tokei](https://github.com/XAMPPRocky/tokei)** - Code statistics
- **[ncdu](https://dev.yorhel.nl/ncdu)** - Disk usage analyzer
- **[ImageMagick](https://imagemagick.org/)** - Image manipulation

### File Processing
- **[jq](https://jqlang.github.io/jq/)** - JSON processor
- **[yq](https://github.com/mikefarah/yq)** - YAML/XML/TOML processor
- **[choose](https://github.com/theryangeary/choose)** - Human-friendly cut alternative
- **[w3m](https://w3m.sourceforge.net/)** - Text-based web browser
- **[Glow](https://github.com/charmbracelet/glow)** - Markdown renderer

### File Watching
- **[fswatch](https://github.com/emcrisostomo/fswatch)** - File change monitor
- **[watchexec](https://github.com/watchexec/watchexec)** - Execute commands on file changes
- **[entr](https://eradman.com/entrproject/)** - Run arbitrary commands when files change

### Archive Tools
- **[unar](https://theunarchiver.com/command-line)** - Archive extractor
- **[ffmpegthumbnailer](https://github.com/dirkvdb/ffmpegthumbnailer)** - Video thumbnail generator
- **[ueberzugpp](https://github.com/jstkdng/ueberzugpp)** - Terminal image viewer

### URL Extraction
- **[urlview](https://github.com/sigpipe/urlview)** - URL extractor for tmux
- **[extract_url](https://github.com/m3m0ryh0l3/extracturl)** - Alternative URL extractor

## CI/CD & Automation

- **[act](https://github.com/nektos/act)** - Run GitHub Actions locally
- **[Commitizen](https://commitizen-tools.github.io/commitizen/)** - Conventional commits helper

## Documentation & Publishing

- **[MacTeX](https://www.tug.org/mactex/)** - LaTeX distribution for macOS
- **[tealdeer](https://github.com/dbrgn/tealdeer)** - Fast tldr client
- **[Onefetch](https://github.com/o2sh/onefetch)** - Git repository summary
- **[Fastfetch](https://github.com/fastfetch-cli/fastfetch)** - System information tool

## GUI Applications

### Development
- **[Altair GraphQL Client](https://altairgraphql.dev/)** - GraphQL IDE

### System
- **[SketchyBar](https://github.com/FelixKratz/SketchyBar)** - macOS status bar

## File System

- **[FUSE-T](https://www.fuse-t.org/)** - Kext-less FUSE implementation for macOS
- **[FUSE-T SSHFS](https://www.fuse-t.org/)** - SSH filesystem implementation

## MCP Servers

See `.claude/mcp.md` for MCP server documentation

## Package Management

- **[Homebrew](https://brew.sh/)** - Package manager for macOS
- **[pipx](https://pipx.pypa.io/)** - Install and run Python applications in isolated environments
- **[mas](https://github.com/mas-cli/mas)** - Mac App Store command-line interface

---

*Last updated: 2025-10-04*
*Total tools: 148+*
