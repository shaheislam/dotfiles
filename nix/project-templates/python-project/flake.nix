# Python Project - Override Global LSPs
# Example: Using specific Python LSP versions for a legacy project
{
  description = "Python project with specific LSP versions - demonstrating hybrid approach";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Python version selection
        pythonVersion = pkgs.python311;  # or python39, python310, python312

        # Custom Python environment with packages
        pythonEnv = pythonVersion.withPackages (ps: with ps; [
          # Common development packages
          pip
          setuptools
          wheel
          virtualenv

          # Testing
          pytest
          pytest-cov
          pytest-asyncio
          pytest-mock
          pytest-xdist
          hypothesis

          # Linting and formatting (project-specific)
          black
          isort
          flake8
          pylint
          mypy
          bandit

          # Documentation
          sphinx
          sphinx-rtd-theme

          # Debugging
          ipython
          ipdb
          rich  # Better pretty printing

          # Type stubs
          types-requests
          types-pyyaml
        ]);

      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Python and package managers
            pythonEnv
            poetry
            pdm
            pipx
            uv  # Fast Python package installer

            # OVERRIDE EXAMPLE: Use pyright instead of basedpyright
            # This overrides the global basedpyright with project-specific pyright
            nodePackages.pyright  # Legacy project compatibility

            # Keep using global ruff-lsp
            ruff-lsp          # Fast linter

            # Additional tools
            pre-commit
            git
            direnv

            # Database clients (optional)
            postgresql
            redis
            sqlite
          ];

          shellHook = ''
            echo "🐍 Python Project with LSP Overrides (Hybrid Approach)"
            echo "======================================================="
            python --version
            echo ""
            echo "🔄 LSP Overrides:"
            echo "  • pyright (overriding global basedpyright)"
            echo "  • ruff-lsp (using global version)"
            echo ""
            echo "📦 Project-specific formatters:"
            echo "  • black, isort (enabled for this project)"
            echo ""
            echo "Available tools:"
            echo "  • pytest (testing)"
            echo "  • mypy (type checking)"
            echo "  • poetry, pdm, uv (package management)"
            echo ""

            # Check for virtual environment
            if [ -d ".venv" ]; then
              echo "📦 Virtual environment detected at .venv"

              # Auto-activate if not in Nix pure mode
              if [ -z "$IN_NIX_SHELL_PURE" ]; then
                echo "Activating virtual environment..."
                source .venv/bin/activate
              fi
            else
              echo "💡 No virtual environment found. Create one with:"
              echo "   python -m venv .venv"
              echo "   source .venv/bin/activate"
            fi

            # Check for project files
            if [ -f "pyproject.toml" ]; then
              if command -v poetry &>/dev/null && [ -f "poetry.lock" ]; then
                echo "📜 Poetry project detected"
                echo "   Install deps: poetry install"
              elif command -v pdm &>/dev/null && [ -f "pdm.lock" ]; then
                echo "📜 PDM project detected"
                echo "   Install deps: pdm install"
              fi
            elif [ -f "requirements.txt" ]; then
              echo "📜 requirements.txt detected"
              echo "   Install deps: pip install -r requirements.txt"
            else
              echo "💡 Initialize project with:"
              echo "   poetry init  # or"
              echo "   pdm init"
            fi

            # Set up pre-commit if config exists
            if [ -f ".pre-commit-config.yaml" ]; then
              pre-commit install 2>/dev/null || true
            fi

            # Python path for better imports
            export PYTHONPATH="$PWD:$PYTHONPATH"
          '';

          # Environment variables
          PYTHONDONTWRITEBYTECODE = "1";
          PYTHONUNBUFFERED = "1";
          PIP_NO_CACHE_DIR = "1";
          VIRTUAL_ENV_DISABLE_PROMPT = "1";  # Let shell prompt handle this

          # Nix LSP detection (for Neovim integration)
          NIX_LSP_ENABLED = "true";
        };

        # Minimal shell for CI/testing
        devShells.test = pkgs.mkShell {
          buildInputs = with pkgs; [
            pythonEnv
            ruff
          ];

          shellHook = ''
            echo "🧪 Python Test Environment"
            python --version
            echo "Run tests: pytest"
            echo "Run linting: ruff check ."
          '';
        };

        # Data science shell
        devShells.datascience = pkgs.mkShell {
          buildInputs = with pkgs; [
            (pythonVersion.withPackages (ps: with ps; [
              # Data science packages
              numpy
              pandas
              matplotlib
              seaborn
              scikit-learn
              jupyter
              ipython
              plotly
              # Deep learning (uncomment as needed)
              # pytorch
              # tensorflow
            ]))
            basedpyright
          ];

          shellHook = ''
            echo "📊 Python Data Science Environment"
            python --version
            echo "Start Jupyter: jupyter notebook"
          '';
        };

        # Web development shell
        devShells.web = pkgs.mkShell {
          buildInputs = with pkgs; [
            (pythonVersion.withPackages (ps: with ps; [
              # Web frameworks
              django
              flask
              fastapi
              uvicorn
              gunicorn
              celery
              redis
              sqlalchemy
              alembic
              pydantic
            ]))
            basedpyright
            ruff-lsp
            postgresql
            redis
          ];

          shellHook = ''
            echo "🌐 Python Web Development Environment"
            python --version
            echo "Frameworks: Django, Flask, FastAPI"
          '';
        };
      });
}