# Go Project Template

Nix flake template for Go development with gopls LSP and common Go tools.

## What's Included

- **Go** (latest stable from nixos-24.05)
- **gopls** (Go language server)
- **golangci-lint-langserver** (Linting support)
- **Optional tools** (commented in flake.nix):
  - delve (debugger)
  - golines (line length formatter)
  - gofumpt (stricter gofmt)
  - air (live reload)

## Quick Start

```bash
# 1. Navigate to your project
cd ~/my-go-app

# 2. Initialize from template
nix flake init -t ~/dotfiles/nix/project-templates#go-project

# 3. Create .envrc
echo "use flake" > .envrc

# 4. Allow direnv
direnv allow

# 5. Create main.go
cat > main.go << 'EOF'
package main

import "fmt"

func main() {
    fmt.Println("Hello, World!")
}
EOF

# 6. Open in Neovim
nvim main.go
```

## Validation

### Step 1: Check Environment

```bash
# Should show project environment active
echo $NIX_LSP_ENABLED
# Expected: true

# Should show Nix store path (not ~/.nix-profile)
which gopls
# Expected: /nix/store/.../gopls

# Check versions
go version
gopls version
```

### Step 2: Test in Neovim

```bash
nvim main.go

# In Neovim:
:LspInfo
# Expected: gopls attached

# Check environment
:lua print(vim.env.NIX_LSP_ENABLED)
# Expected: true

# Test LSP features:
# - K on "fmt" - should show documentation
# - gd on "Println" - should go to definition
# - Save file - should auto-format
```

### Step 3: Test Go Tools

```bash
# Run program
go run main.go
# Expected: Hello, World!

# Build program
go build -o app

# Check generated binary
./app
# Expected: Hello, World!
```

## Customization

### Use Latest gopls (Unstable)

Edit `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";  # Add this
  };

  outputs = { nixpkgs, nixpkgs-unstable, ... }:
    let
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.go
          pkgs-unstable.gopls  # Use unstable gopls
        ];
      };
    };
}
```

Then reload:

```bash
nix flake update
direnv reload
```

### Enable Optional Tools

Uncomment lines in `flake.nix`:

```nix
buildInputs = with pkgs; [
  go
  gopls
  # Uncomment desired tools:
  delve          # Debugger
  golines        # Line length formatter
  gofumpt        # Stricter gofmt
  air            # Live reload for development
];
```

### Change Go Version

```nix
buildInputs = [
  pkgs.go_1_21  # or go_1_20, go_1_22, etc.
  pkgs.gopls
];
```

## Common Workflows

### Initialize Go Module

```bash
go mod init github.com/username/project
```

### Add Dependencies

```bash
go get github.com/pkg/errors
go mod tidy
```

### Run Tests

```bash
go test ./...
```

### Format Code

```bash
go fmt ./...
# or use gofumpt if enabled
gofumpt -w .
```

## Troubleshooting

### gopls Not Found

```bash
# Check direnv is active
direnv status

# If not, allow it
direnv allow

# Verify gopls is in flake.nix
cat flake.nix | grep gopls
```

### LSP Features Not Working

```bash
# Restart Neovim LSP
# In Neovim: :LspRestart

# Check gopls is running
ps aux | grep gopls

# Check Neovim LSP logs
# In Neovim: :LspLog
```

### Wrong gopls Version

```bash
# Update flake dependencies
nix flake update

# Reload environment
direnv reload

# Verify version
gopls version
```

## Next Steps

- Read [../README.md](../README.md) for inheritance patterns
- See [../../TESTING.md](../../TESTING.md) for comprehensive validation
- Check [../../QUICK_START.md](../../QUICK_START.md) for quick reference
