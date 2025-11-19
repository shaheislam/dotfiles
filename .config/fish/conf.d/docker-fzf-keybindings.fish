# Docker FZF Keybindings - CTRL-D prefix
# Complements existing Docker workflows with fuzzy finding

# Only activate if fzf and docker are available
if command -v fzf >/dev/null 2>&1 && command -v docker >/dev/null 2>&1
    # CTRL-D ? for help
    bind -M default \cd\? '__fzf_docker_sh list_bindings; commandline -f repaint'
    bind -M insert \cd\? '__fzf_docker_sh list_bindings; commandline -f repaint'

    # CTRL-D CTRL-C / CTRL-D C for Containers (running)
    bind -M default \cdc '__fzf_docker_sh containers; commandline -f repaint'
    bind -M insert \cdc '__fzf_docker_sh containers; commandline -f repaint'
    bind -M default \cd\cc '__fzf_docker_sh containers; commandline -f repaint'
    bind -M insert \cd\cc '__fzf_docker_sh containers; commandline -f repaint'

    # CTRL-D CTRL-A / CTRL-D A for All containers
    bind -M default \cda '__fzf_docker_sh all_containers; commandline -f repaint'
    bind -M insert \cda '__fzf_docker_sh all_containers; commandline -f repaint'
    bind -M default \cd\ca '__fzf_docker_sh all_containers; commandline -f repaint'
    bind -M insert \cd\ca '__fzf_docker_sh all_containers; commandline -f repaint'

    # CTRL-D CTRL-I / CTRL-D I for Images
    bind -M default \cdi '__fzf_docker_sh images; commandline -f repaint'
    bind -M insert \cdi '__fzf_docker_sh images; commandline -f repaint'
    bind -M default \cd\ci '__fzf_docker_sh images; commandline -f repaint'
    bind -M insert \cd\ci '__fzf_docker_sh images; commandline -f repaint'

    # CTRL-D CTRL-V / CTRL-D V for Volumes
    bind -M default \cdv '__fzf_docker_sh volumes; commandline -f repaint'
    bind -M insert \cdv '__fzf_docker_sh volumes; commandline -f repaint'
    bind -M default \cd\cv '__fzf_docker_sh volumes; commandline -f repaint'
    bind -M insert \cd\cv '__fzf_docker_sh volumes; commandline -f repaint'

    # CTRL-D CTRL-N / CTRL-D N for Networks
    bind -M default \cdn '__fzf_docker_sh networks; commandline -f repaint'
    bind -M insert \cdn '__fzf_docker_sh networks; commandline -f repaint'
    bind -M default \cd\cn '__fzf_docker_sh networks; commandline -f repaint'
    bind -M insert \cd\cn '__fzf_docker_sh networks; commandline -f repaint'

    # CTRL-D CTRL-S / CTRL-D S for Compose Services
    bind -M default \cds '__fzf_docker_sh compose_services; commandline -f repaint'
    bind -M insert \cds '__fzf_docker_sh compose_services; commandline -f repaint'
    bind -M default \cd\cs '__fzf_docker_sh compose_services; commandline -f repaint'
    bind -M insert \cd\cs '__fzf_docker_sh compose_services; commandline -f repaint'
end

# Quick Reference Guide
# ┌────────────────────────────────────────────────────────────────────────┐
# │  SELECTION MODE (CTRL-D) - Docker FZF Integration:                    │
# ├────────────────────────────────────────────────────────────────────────┤
# │  CTRL-D ?      Help                                                    │
# │  CTRL-D C      Running Containers                                      │
# │  CTRL-D A      All Containers (including stopped)                      │
# │  CTRL-D I      Images                                                  │
# │  CTRL-D V      Volumes                                                 │
# │  CTRL-D N      Networks                                                │
# │  CTRL-D S      Compose Services                                        │
# ├────────────────────────────────────────────────────────────────────────┤
# │  Within FZF:                                                           │
# │  CTRL-E        Execute shell in container                              │
# │  CTRL-L        View logs (follow mode)                                 │
# │  CTRL-S        Stop/Start (context-dependent)                          │
# │  CTRL-R        Restart/Run (context-dependent)                         │
# │  CTRL-X        Remove (containers/images/volumes/networks)             │
# │  CTRL-I        Inspect (detailed info)                                 │
# │  ALT-A         Show all (toggle filter)                                │
# └────────────────────────────────────────────────────────────────────────┘
