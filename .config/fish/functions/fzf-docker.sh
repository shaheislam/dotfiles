#!/usr/bin/env bash
# FZF Docker Integration
# Provides fuzzy finding for Docker containers, images, volumes, networks, and compose services
# Inspired by junegunn/fzf-git.sh

# shellcheck disable=SC2039
[[ $0 == - ]] && return

__fzf_docker_color() {
  if [[ -n $NO_COLOR ]]; then
    echo never
  elif [[ $# -gt 0 ]] && [[ -n $FZF_DOCKER_PREVIEW_COLOR ]]; then
    echo "$FZF_DOCKER_PREVIEW_COLOR"
  else
    echo "${FZF_DOCKER_COLOR:-always}"
  fi
}

__fzf_docker_cat() {
  if [[ -n $FZF_DOCKER_CAT ]]; then
    echo "$FZF_DOCKER_CAT"
    return
  fi

  # Sometimes bat is installed as batcat
  _fzf_docker_bat_options="--style='${BAT_STYLE:-full}' --color=$(__fzf_docker_color .) --pager=never"
  if command -v batcat > /dev/null; then
    echo "batcat $_fzf_docker_bat_options"
  elif command -v bat > /dev/null; then
    echo "bat $_fzf_docker_bat_options"
  else
    echo cat
  fi
}

if [[ $1 == --list ]]; then
  shift
  if [[ $# -eq 1 ]]; then
    containers() {
      docker ps "$@" --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | tail -n +2
    }
    all_containers() {
      docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.CreatedAt}}" | tail -n +2
    }
    running_containers() {
      docker ps --filter "status=running" --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | tail -n +2
    }
    stopped_containers() {
      docker ps -a --filter "status=exited" --filter "status=created" --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.CreatedAt}}" | tail -n +2
    }
    images() {
      docker images --format "table {{.ID}}\t{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" | tail -n +2
    }
    volumes() {
      docker volume ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}" | tail -n +2
    }
    networks() {
      docker network ls --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}" | tail -n +2
    }
    case "$1" in
      containers)
        echo 'CTRL-E (exec) ╱ CTRL-L (logs) ╱ CTRL-S (stop) ╱ CTRL-R (restart) ╱ ALT-A (show all)'
        containers
        ;;
      all-containers)
        echo 'CTRL-E (exec) ╱ CTRL-L (logs) ╱ CTRL-X (remove) ╱ CTRL-S (start) ╱ CTRL-R (restart)'
        all_containers
        ;;
      running-containers)
        echo 'CTRL-S (stop) ╱ CTRL-R (restart) ╱ CTRL-L (logs) ╱ ALT-A (show all)'
        running_containers
        ;;
      stopped-containers)
        echo 'CTRL-S (start) ╱ CTRL-X (remove) ╱ CTRL-L (logs) ╱ ALT-A (show all)'
        stopped_containers
        ;;
      images)
        echo 'CTRL-X (remove) ╱ CTRL-R (run) ╱ CTRL-I (inspect) ╱ CTRL-T (tag)'
        images
        ;;
      volumes)
        echo 'CTRL-X (remove) ╱ CTRL-I (inspect) ╱ CTRL-P (prune unused)'
        volumes
        ;;
      networks)
        echo 'CTRL-X (remove) ╱ CTRL-I (inspect) ╱ CTRL-P (prune unused)'
        networks
        ;;
      *) exit 1 ;;
    esac
  fi
fi

if [[ $- =~ i ]] || [[ $1 = --run ]]; then # ----------------------------------

if [[ $__fzf_docker_fzf ]]; then
  eval "$__fzf_docker_fzf"
else
  # Redefine this function to change the options
  _fzf_docker_fzf() {
    fzf --height 50% --tmux 90%,70% \
      --layout reverse --multi --min-height 20+ --border \
      --no-separator --header-border horizontal \
      --border-label-pos 2 \
      --color 'label:blue' \
      --preview-window 'right,50%' --preview-border line \
      --bind 'ctrl-/:change-preview-window(down,50%|hidden|)' "$@"
  }
fi

_fzf_docker_check() {
  if ! command -v docker > /dev/null 2>&1; then
    [[ -n $TMUX ]] && tmux display-message "Docker not installed"
    return 1
  fi

  if ! docker info > /dev/null 2>&1; then
    [[ -n $TMUX ]] && tmux display-message "Docker daemon not running"
    return 1
  fi

  return 0
}

__fzf_docker=${BASH_SOURCE[0]:-${(%):-%x}}
__fzf_docker=$(readlink -f "$__fzf_docker" 2> /dev/null || /usr/bin/ruby --disable-gems -e 'puts File.expand_path(ARGV.first)' "$__fzf_docker" 2> /dev/null)

_fzf_docker_containers() {
  _fzf_docker_check || return

  bash "$__fzf_docker" --list containers |
  _fzf_docker_fzf --ansi \
    --border-label '🐳 Containers (Running) ' \
    --header-lines 1 \
    --tiebreak begin \
    --preview-window down,border-top,40% \
    --no-hscroll \
    --bind 'ctrl-/:change-preview-window(down,70%|hidden|)' \
    --bind "ctrl-e:execute:docker exec -it {1} sh < /dev/tty > /dev/tty" \
    --bind "ctrl-l:execute:docker logs -f {1} < /dev/tty > /dev/tty" \
    --bind "ctrl-s:reload(docker stop {1} > /dev/null; bash \"$__fzf_docker\" --list containers)" \
    --bind "ctrl-r:reload(docker restart {1} > /dev/null; bash \"$__fzf_docker\" --list containers)" \
    --bind "alt-a:change-border-label(🐳 Containers (All))+reload:bash \"$__fzf_docker\" --list all-containers" \
    --preview "echo '=== Container Info ==='; docker inspect {1} | jq -C '.[0] | {Name, Image, State, NetworkSettings}'; echo; echo '=== Recent Logs ==='; docker logs --tail 50 {1}" "$@" |
  awk '{print $1}'
}

_fzf_docker_all_containers() {
  _fzf_docker_check || return

  bash "$__fzf_docker" --list all-containers |
  _fzf_docker_fzf --ansi \
    --border-label '🐳 Containers (All) ' \
    --header-lines 1 \
    --tiebreak begin \
    --preview-window down,border-top,40% \
    --no-hscroll \
    --bind 'ctrl-/:change-preview-window(down,70%|hidden|)' \
    --bind "ctrl-e:execute:docker exec -it {1} sh < /dev/tty > /dev/tty" \
    --bind "ctrl-l:execute:docker logs -f {1} < /dev/tty > /dev/tty" \
    --bind "ctrl-x:reload(docker rm -f {1} > /dev/null; bash \"$__fzf_docker\" --list all-containers)" \
    --bind "ctrl-s:reload(docker start {1} > /dev/null; bash \"$__fzf_docker\" --list all-containers)" \
    --bind "ctrl-r:reload(docker restart {1} > /dev/null; bash \"$__fzf_docker\" --list all-containers)" \
    --preview "echo '=== Container Info ==='; docker inspect {1} | jq -C '.[0] | {Name, Image, State, NetworkSettings}'; echo; echo '=== Recent Logs ==='; docker logs --tail 50 {1}" "$@" |
  awk '{print $1}'
}

_fzf_docker_running_containers() {
  _fzf_docker_check || return

  bash "$__fzf_docker" --list running-containers |
  _fzf_docker_fzf --ansi \
    --border-label '🐳 Containers (Running) ' \
    --header-lines 1 \
    --tiebreak begin \
    --preview-window down,border-top,40% \
    --no-hscroll \
    --bind 'ctrl-/:change-preview-window(down,70%|hidden|)' \
    --bind "ctrl-s:reload(docker stop {1} > /dev/null; bash \"$__fzf_docker\" --list running-containers)" \
    --bind "ctrl-r:reload(docker restart {1} > /dev/null; bash \"$__fzf_docker\" --list running-containers)" \
    --bind "ctrl-l:execute:docker logs -f {1} < /dev/tty > /dev/tty" \
    --bind "alt-a:change-border-label(🐳 Containers (All))+reload:bash \"$__fzf_docker\" --list all-containers" \
    --preview "echo '=== Container Info ==='; docker inspect {1} | jq -C '.[0] | {Name, Image, State, NetworkSettings}'; echo; echo '=== Recent Logs ==='; docker logs --tail 50 {1}" "$@" |
  awk '{print $1}'
}

_fzf_docker_stopped_containers() {
  _fzf_docker_check || return

  bash "$__fzf_docker" --list stopped-containers |
  _fzf_docker_fzf --ansi \
    --border-label '🐳 Containers (Stopped) ' \
    --header-lines 1 \
    --tiebreak begin \
    --preview-window down,border-top,40% \
    --no-hscroll \
    --bind 'ctrl-/:change-preview-window(down,70%|hidden|)' \
    --bind "ctrl-s:reload(docker start {1} > /dev/null; bash \"$__fzf_docker\" --list stopped-containers)" \
    --bind "ctrl-x:reload(docker rm -f {1} > /dev/null; bash \"$__fzf_docker\" --list stopped-containers)" \
    --bind "ctrl-l:execute:docker logs -f {1} < /dev/tty > /dev/tty" \
    --bind "alt-a:change-border-label(🐳 Containers (All))+reload:bash \"$__fzf_docker\" --list all-containers" \
    --preview "echo '=== Container Info ==='; docker inspect {1} | jq -C '.[0] | {Name, Image, State, NetworkSettings}'; echo; echo '=== Recent Logs ==='; docker logs --tail 50 {1}" "$@" |
  awk '{print $1}'
}

_fzf_docker_images() {
  _fzf_docker_check || return

  bash "$__fzf_docker" --list images |
  _fzf_docker_fzf --ansi \
    --border-label '📦 Images ' \
    --header-lines 1 \
    --tiebreak begin \
    --preview-window right,70% \
    --no-hscroll \
    --bind 'ctrl-/:change-preview-window(right,90%|hidden|)' \
    --bind "ctrl-x:reload(docker rmi {1} > /dev/null; bash \"$__fzf_docker\" --list images)" \
    --bind "ctrl-r:execute:docker run -it --rm {2} < /dev/tty > /dev/tty" \
    --bind "ctrl-i:execute:docker inspect {1} | jq -C '.[0]' | less -R" \
    --preview "docker inspect {1} | jq -C '.[0] | {RepoTags, Size, Created, Architecture, Os, Config}'" "$@" |
  awk '{print $1}'
}

_fzf_docker_volumes() {
  _fzf_docker_check || return

  bash "$__fzf_docker" --list volumes |
  _fzf_docker_fzf --ansi \
    --border-label '💾 Volumes ' \
    --header-lines 1 \
    --tiebreak begin \
    --preview-window right,70% \
    --no-hscroll \
    --bind 'ctrl-/:change-preview-window(right,90%|hidden|)' \
    --bind "ctrl-x:reload(docker volume rm {1} > /dev/null 2>&1; bash \"$__fzf_docker\" --list volumes)" \
    --bind "ctrl-i:execute:docker volume inspect {1} | jq -C | less -R" \
    --bind "ctrl-p:reload(docker volume prune -f > /dev/null; bash \"$__fzf_docker\" --list volumes)" \
    --preview "docker volume inspect {1} | jq -C '.[0]'" "$@" |
  awk '{print $1}'
}

_fzf_docker_networks() {
  _fzf_docker_check || return

  bash "$__fzf_docker" --list networks |
  _fzf_docker_fzf --ansi \
    --border-label '🌐 Networks ' \
    --header-lines 1 \
    --tiebreak begin \
    --preview-window right,70% \
    --no-hscroll \
    --bind 'ctrl-/:change-preview-window(right,90%|hidden|)' \
    --bind "ctrl-x:reload(docker network rm {1} > /dev/null 2>&1; bash \"$__fzf_docker\" --list networks)" \
    --bind "ctrl-i:execute:docker network inspect {1} | jq -C | less -R" \
    --bind "ctrl-p:reload(docker network prune -f > /dev/null; bash \"$__fzf_docker\" --list networks)" \
    --preview "docker network inspect {1} | jq -C '.[0] | {Name, Driver, Scope, Containers}'" "$@" |
  awk '{print $2}'
}

_fzf_docker_compose_services() {
  _fzf_docker_check || return

  if ! command -v docker-compose > /dev/null 2>&1 && ! docker compose version > /dev/null 2>&1; then
    [[ -n $TMUX ]] && tmux display-message "Docker Compose not available"
    return 1
  fi

  # Find docker-compose.yml in current or parent directories
  local compose_file=$(find . -maxdepth 3 -name "docker-compose.yml" -o -name "docker-compose.yaml" 2>/dev/null | head -n 1)

  if [[ -z $compose_file ]]; then
    [[ -n $TMUX ]] && tmux display-message "No docker-compose.yml found"
    return 1
  fi

  # Use docker compose (v2) if available, otherwise docker-compose (v1)
  local compose_cmd="docker compose"
  if ! docker compose version > /dev/null 2>&1; then
    compose_cmd="docker-compose"
  fi

  $compose_cmd -f "$compose_file" config --services |
  _fzf_docker_fzf \
    --border-label '🎼 Compose Services ' \
    --preview-window right,70% \
    --no-hscroll \
    --bind 'ctrl-/:change-preview-window(right,90%|hidden|)' \
    --bind "ctrl-u:execute:$compose_cmd -f \"$compose_file\" up -d {1} < /dev/tty > /dev/tty" \
    --bind "ctrl-s:execute:$compose_cmd -f \"$compose_file\" stop {1} < /dev/tty > /dev/tty" \
    --bind "ctrl-r:execute:$compose_cmd -f \"$compose_file\" restart {1} < /dev/tty > /dev/tty" \
    --bind "ctrl-l:execute:$compose_cmd -f \"$compose_file\" logs -f {1} < /dev/tty > /dev/tty" \
    --preview "$compose_cmd -f \"$compose_file\" config | yq -C '.services.{1}' 2>/dev/null || $compose_cmd -f \"$compose_file\" config | grep -A 20 '^  {1}:'" "$@"
}

_fzf_docker_list_bindings() {
  cat <<'EOF'

CTRL-D ? to show this list
CTRL-D CTRL-C for Containers (running)
CTRL-D CTRL-A for All Containers
CTRL-D CTRL-I for Images
CTRL-D CTRL-V for Volumes
CTRL-D CTRL-N for Networks
CTRL-D CTRL-S for Compose Services
EOF
}

fi # --------------------------------------------------------------------------

if [[ $1 = --run ]]; then
  shift
  type=$1
  shift
  eval "_fzf_docker_$type" "$@"

elif [[ $- =~ i ]]; then # ------------------------------------------------------
if [[ -n "${BASH_VERSION:-}" ]]; then
  __fzf_docker_init() {
    bind -m emacs-standard '"\er":  redraw-current-line'
    bind -m emacs-standard '"\C-z": vi-editing-mode'
    bind -m vi-command     '"\C-z": emacs-editing-mode'
    bind -m vi-insert      '"\C-z": emacs-editing-mode'

    local o c
    for o in "$@"; do
      c=${o:0:1}
      if [[ $c == '?' ]]; then
        bind -x "\"\C-d$c\": _fzf_docker_list_bindings"
        continue
      fi
      bind -m emacs-standard '"\C-d\C-'$c'": " \C-u \C-a\C-k`_fzf_docker_'$o'`\e\C-e\C-y\C-a\C-y\ey\C-h\C-e\er \C-h"'
      bind -m vi-command     '"\C-d\C-'$c'": "\C-z\C-d\C-'$c'\C-z"'
      bind -m vi-insert      '"\C-d\C-'$c'": "\C-z\C-d\C-'$c'\C-z"'
      bind -m emacs-standard '"\C-d'$c'":    " \C-u \C-a\C-k`_fzf_docker_'$o'`\e\C-e\C-y\C-a\C-y\ey\C-h\C-e\er \C-h"'
      bind -m vi-command     '"\C-d'$c'":    "\C-z\C-d'$c'\C-z"'
      bind -m vi-insert      '"\C-d'$c'":    "\C-z\C-d'$c'\C-z"'
    done
  }
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  __fzf_docker_join() {
    local item
    while read -r item; do
      echo -n -E "${(q)${(Q)item}} "
    done
  }

  __fzf_docker_init() {
    setopt localoptions no_glob
    local m o
    for o in "$@"; do
      if [[ ${o[1]} == "?" ]];then
        eval "fzf-docker-$o-widget() { zle -M '$(_fzf_docker_list_bindings)' }"
      else
        eval "fzf-docker-$o-widget() { local result=\$(_fzf_docker_$o | __fzf_docker_join); zle reset-prompt; LBUFFER+=\$result }"
      fi
      eval "zle -N fzf-docker-$o-widget"
      for m in emacs vicmd viins; do
        eval "bindkey -M $m '^d^${o[1]}' fzf-docker-$o-widget"
        eval "bindkey -M $m '^d${o[1]}' fzf-docker-$o-widget"
      done
    done
  }
fi
__fzf_docker_init containers all_containers running_containers stopped_containers images volumes networks compose_services '?list_bindings'

fi # --------------------------------------------------------------------------
