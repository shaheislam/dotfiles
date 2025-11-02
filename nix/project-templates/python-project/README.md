# Python Project Template

Nix flake template for Python development with basedpyright/pyright LSP and common Python tools.

## What's Included

- **Python 3.12** (latest stable from nixos-24.05)
- **basedpyright** (Python language server with enhanced type checking)
- **ruff-lsp** (Fast Python linter/formatter via LSP)
- **Optional tools** (commented in flake.nix):
  - black (code formatter)
  - isort (import sorter)
  - pytest (testing framework)
  - ipython (enhanced REPL)

## Quick Start

```bash
# 1. Navigate to your project
cd ~/my-python-app

# 2. Initialize from template
nix flake init -t ~/dotfiles/nix/project-templates#python-project

# 3. Create .envrc
echo "use flake" > .envrc

# 4. Allow direnv
direnv allow

# 5. Create app.py
cat > app.py << 'EOF'
def greet(name: str) -> str:
    return f"Hello, {name}!"

if __name__ == "__main__":
    print(greet("World"))
EOF

# 6. Open in Neovim
nvim app.py
```

## Validation

### Step 1: Check Environment

```bash
# Should show project environment active
echo $NIX_LSP_ENABLED
# Expected: true

# Check Python version
python --version
# Expected: Python 3.12.x

# Check LSP servers
which basedpyright-langserver
# Expected: /nix/store/.../basedpyright-langserver

which ruff-lsp
# Expected: /nix/store/.../ruff-lsp
```

### Step 2: Test in Neovim

```bash
nvim app.py

# In Neovim:
:LspInfo
# Expected: basedpyright and ruff attached

# Test LSP features:
# - K on "str" - should show type documentation
# - gd on function - should go to definition
# - Save file - should show diagnostics and format
```

### Step 3: Test Python Tools

```bash
# Run program
python app.py
# Expected: Hello, World!

# Check type hints
python -c "import app; print(app.greet('Test'))"
# Expected: Hello, Test!
```

## Customization

### Use pyright Instead of basedpyright

Edit `flake.nix`:

```nix
buildInputs = [
  pkgs.python312
  pkgs.nodePackages.pyright  # Use pyright instead
  pkgs.ruff-lsp
];
```

Reload:

```bash
nix flake update
direnv reload
```

### Change Python Version

```nix
buildInputs = [
  pkgs.python311  # or python310, python39, etc.
  pkgs.basedpyright
  pkgs.ruff-lsp
];
```

### Enable Optional Tools

Uncomment lines in `flake.nix`:

```nix
buildInputs = with pkgs; [
  python312
  basedpyright
  ruff-lsp
  # Uncomment desired tools:
  black           # Code formatter
  isort           # Import sorter
  pytest          # Testing framework
  ipython         # Enhanced REPL
];
```

### Add Virtual Environment Support

Add to `shellHook` in `flake.nix`:

```nix
shellHook = ''
  # Create virtual environment if it doesn't exist
  if [ ! -d .venv ]; then
    python -m venv .venv
  fi

  # Activate virtual environment
  source .venv/bin/activate

  echo "🐍 Python Project Environment"
  echo "   Python: $(python --version)"
  echo "   Virtual env: .venv"
'';
```

Then:

```bash
direnv reload
pip install -r requirements.txt
```

## Common Workflows

### Create requirements.txt

```bash
pip freeze > requirements.txt
```

### Install Dependencies

```bash
pip install -r requirements.txt
```

### Run Tests

```bash
pytest
# or if pytest is enabled in flake.nix
pytest tests/
```

### Format Code

```bash
# If black is enabled
black .

# If isort is enabled
isort .
```

### Type Checking

```bash
# Using basedpyright
basedpyright app.py

# Or let the LSP do it in Neovim
```

## Switching Between pyright and basedpyright

**basedpyright** (default):
- Enhanced type checking features
- Faster updates with new Python features
- Stricter by default

**pyright** (alternative):
- Official Microsoft implementation
- More conservative updates
- Better for legacy projects

To switch, edit `flake.nix` and change the LSP package.

## Troubleshooting

### LSP Not Found

```bash
# Check direnv is active
direnv status

# If not, allow it
direnv allow

# Verify LSP is in flake.nix
cat flake.nix | grep -E "(pyright|ruff)"
```

### Type Checking Too Strict

If basedpyright is too strict, either:

1. Switch to pyright (less strict)
2. Configure basedpyright in `pyrightconfig.json`:

```json
{
  "typeCheckingMode": "basic",
  "reportMissingTypeStubs": false
}
```

### Virtual Environment Issues

```bash
# Remove and recreate
rm -rf .venv
direnv reload
# Will recreate .venv automatically if shellHook configured
```

## Next Steps

- Read [../README.md](../README.md) for inheritance patterns
- See [../../TESTING.md](../../TESTING.md) for comprehensive validation
- Check [../../QUICK_START.md](../../QUICK_START.md) for quick reference
