{ config, pkgs, lib, ... }:

{
  # Basic home configuration
  home.stateVersion = "24.05";
  programs.home-manager.enable = true;

  # Global packages - always available everywhere
  home.packages = with pkgs; [
    # === Core Development Tools ===
    git
    gh
    delta  # Better git diffs
    lazygit

    # === Universal LSPs (for general editing) ===
    lua-language-server     # Neovim configs
    nil                     # Nix files
    nixpkgs-fmt            # Nix formatter
    marksman               # Markdown
    yaml-language-server   # YAML files
    nodePackages.vscode-langservers-extracted  # JSON/HTML/CSS

    # === Shell & Scripting ===
    nodePackages.bash-language-server
    shellcheck
    shfmt

    # === Search & Navigation ===
    ripgrep
    fd
    # fzf  # Managed by Homebrew to ensure latest version
    bat
    eza
    tree
    zoxide

    # === File Processing ===
    jq
    yq-go
    sd       # Better sed
    hexyl    # Hex viewer
    tokei    # Code statistics

    # === System Monitoring ===
    htop
    bottom
    procs
    dust     # Better du
    duf      # Better df
    hyperfine # Benchmarking

    # === Network Tools ===
    curl
    wget
    httpie
    doggo    # Better dig
    gping    # Graph ping

    # === Container Tools ===
    dive     # Docker image explorer
    lazydocker

    # === Documentation ===
    glow     # Terminal markdown viewer

    # === Development Utilities ===
    direnv   # Per-directory environments
    watchexec # File watcher
    just     # Command runner
    pre-commit
    commitizen

    # === Archive Tools ===
    unzip
    p7zip

    # === Security Tools ===
    gnupg
    age
    sops
  ];

  # Program configurations
  programs = {
    # Git configuration (managed by Nix)
    git = {
      enable = true;
      delta.enable = true;
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = false;
        push.autoSetupRemote = true;
      };
    };

    # Direnv configuration
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      # Configuration is managed by your dotfiles
    };

    # fzf configuration - Disabled, managed by Homebrew instead
    # fzf = {
    #   enable = true;
    #   # Configuration is managed by your dotfiles
    # };

    # Note: bat and zoxide are installed as packages above
    # Their configurations are managed by your existing dotfiles
  };

  # Environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "less";
    LESS = "-R";

    # Nix-specific
    NIX_GLOBAL_ENABLED = "true";

    # Development
    COMPOSE_DOCKER_CLI_BUILD = "1";
    DOCKER_BUILDKIT = "1";
  };

  # Shell aliases (will be available in all shells)
  home.shellAliases = {
    # Nix aliases
    nds = "nix develop --command $SHELL";
    nfu = "nix flake update";
    nfs = "nix flake show";
    nfm = "nix flake metadata";
    nsh = "nix shell";
    nsn = "nix shell nixpkgs#";
    ngc = "nix-collect-garbage -d";

    # ls replacements
    ls = "eza --icons";
    ll = "eza -la --icons";
    la = "eza -a --icons";
    lt = "eza --tree --icons";

    # Common shortcuts
    g = "git";
    d = "docker";
    dc = "docker-compose";
    k = "kubectl";
    tf = "terraform";

    # Safety aliases
    rm = "rm -i";
    cp = "cp -i";
    mv = "mv -i";
  };

  # Create useful directories
  home.file = {
    # Link or create config directories as needed
    ".config/nixpkgs/config.nix".text = ''
      {
        allowUnfree = true;
      }
    '';

    # Flog v3 extended Git graph glyphs for vim-flog.
    "Library/Fonts/FlogSymbols.ttf" = {
      source = ./fonts/FlogSymbols.ttf;
      force = true;
    };
  };

  # Activation scripts
  home.activation = {
    # Report what was installed
    report = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD echo "Home Manager environment activated!"
      $DRY_RUN_CMD echo "Global Nix packages are now available in all shells"
    '';
  };
}
