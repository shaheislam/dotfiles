# The MIT License (MIT)
#
# Copyright (c) 2024 Junegunn Choi
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# shellcheck disable=SC2039
[[ $0 == - ]] && return

__fzf_git_color() {
  if [[ -n $NO_COLOR ]]; then
    echo never
  elif [[ $# -gt 0 ]] && [[ -n $FZF_GIT_PREVIEW_COLOR ]]; then
    echo "$FZF_GIT_PREVIEW_COLOR"
  else
    echo "${FZF_GIT_COLOR:-always}"
  fi
}

__fzf_git_cat() {
  if [[ -n $FZF_GIT_CAT ]]; then
    echo "$FZF_GIT_CAT"
    return
  fi

  # Sometimes bat is installed as batcat
  _fzf_git_bat_options="--style='${BAT_STYLE:-full}' --color=$(__fzf_git_color .) --pager=never"
  if command -v batcat > /dev/null; then
    echo "batcat $_fzf_git_bat_options"
  elif command -v bat > /dev/null; then
    echo "bat $_fzf_git_bat_options"
  else
    echo cat
  fi
}

__fzf_git_pager() {
  local pager
  pager="${FZF_GIT_PAGER:-${GIT_PAGER:-$(git config --get core.pager 2> /dev/null)}}"
  echo "${pager:-cat}"
}

if [[ $1 == --list ]]; then
  shift
  if [[ $# -eq 1 ]]; then
    branches() {
      git branch "$@" --sort=-committerdate --sort=-HEAD --format=$'%(HEAD) %(color:yellow)%(refname:short) %(color:green)(%(committerdate:relative))\t%(color:blue)%(subject)%(color:reset)' --color=$(__fzf_git_color) | column -ts$'\t'
    }
    refs() {
      git for-each-ref "$@" --sort=-creatordate --sort=-HEAD --color=$(__fzf_git_color) --format=$'%(if:equals=refs/remotes)%(refname:rstrip=-2)%(then)%(color:magenta)remote-branch%(else)%(if:equals=refs/heads)%(refname:rstrip=-2)%(then)%(color:brightgreen)branch%(else)%(if:equals=refs/tags)%(refname:rstrip=-2)%(then)%(color:brightcyan)tag%(else)%(if:equals=refs/stash)%(refname:rstrip=-2)%(then)%(color:brightred)stash%(else)%(color:white)%(refname:rstrip=-2)%(end)%(end)%(end)%(end)\t%(color:yellow)%(refname:short) %(color:green)(%(creatordate:relative))\t%(color:blue)%(subject)%(color:reset)' | column -ts$'\t'
    }
    hashes() {
      git log --date=short --format="%C(green)%C(bold)%cd %C(auto)%h%d %s (%an)" --graph --color=$(__fzf_git_color) "$@" $LIST_OPTS
    }
    case "$1" in
      branches)
        echo 'CTRL-O (open in browser) ╱ ALT-A (show all branches)'
        echo 'ALT-H (list commit hashes)'
        branches
        ;;
      all-branches)
        echo 'CTRL-O (open in browser) ╱ ALT-ENTER (accept without remote)'
        echo 'ALT-H (list commit hashes)'
        branches -a
        ;;
      hashes)
        echo 'CTRL-O (open in browser) ╱ CTRL-D (diff)'
        echo 'CTRL-S (toggle sort) ╱ ALT-A (show all hashes)'
        hashes
        ;;
      all-hashes)
        echo 'CTRL-O (open in browser) ╱ CTRL-D (diff)'
        echo 'CTRL-S (toggle sort)'
        hashes --all
        ;;
      refs)
        echo 'CTRL-O (open in browser) ╱ ALT-E (examine in editor) ╱ ALT-A (show all refs)'
        refs --exclude='refs/remotes'
        ;;
      all-refs)
        echo 'CTRL-O (open in browser) ╱ ALT-E (examine in editor)'
        refs
        ;;
      *) exit 1 ;;
    esac
  elif [[ $# -gt 1 ]]; then
    set -e

    branch=$(git rev-parse --abbrev-ref HEAD 2> /dev/null)
    if [[ $branch == HEAD ]]; then
      branch=$(git describe --exact-match --tags 2> /dev/null || git rev-parse --short HEAD)
    fi

    # Only supports GitHub for now
    case "$1" in
      commit)
        hash=$(grep -o "[a-f0-9]\{7,\}" <<< "$2" | head -n 1)
        path=/commit/$hash
        ;;
      branch|remote-branch)
        branch=$(sed 's/^[* ]*//' <<< "$2" | cut -d' ' -f1)
        remote=$(git config branch."${branch}".remote || echo 'origin')
        branch=${branch#$remote/}
        path=/tree/$branch
        ;;
      remote)
        remote=$2
        path=/tree/$branch
        ;;
      file) path=/blob/$branch/$(git rev-parse --show-prefix)$2 ;;
      tag)  path=/releases/tag/$2 ;;
      *)    exit 1 ;;
    esac

    remote=${remote:-$(git config branch."${branch}".remote || echo 'origin')}
    remote_url=$(git remote get-url "$remote" 2> /dev/null || echo "$remote")

    if [[ $remote_url =~ ^git@ ]]; then
      url=${remote_url%.git}
      url=${url#git@}
      url=https://${url/://}
    elif [[ $remote_url =~ ^http ]]; then
      url=${remote_url%.git}
    fi

    case "$OSTYPE" in
      darwin*)
        open "$url$path"
        ;;
      msys)
        # Git-Bash on Windows
        start "$url$path"
        ;;
      linux*)
        # Handle WSL on Windows
        if uname -a | grep -i -q Microsoft && command -v powershell.exe; then
          powershell.exe -NoProfile start "$url$path"
        else
          xdg-open "$url$path"
        fi
        ;;
      *)
        # fall back to xdg-open for BSDs, etc.
        xdg-open "$url$path"
        ;;
    esac
    exit 0
  fi
fi

if [[ $- =~ i ]] || [[ $1 = --run ]]; then # ----------------------------------

if [[ $__fzf_git_fzf ]]; then
  eval "$__fzf_git_fzf"
else
  # Redefine this function to change the options
  _fzf_git_fzf() {
    fzf --height 50% --tmux 90%,70% \
      --layout reverse --multi --min-height 20+ --border \
      --no-separator --header-border horizontal \
      --border-label-pos 2 \
      --color 'label:blue' \
      --preview-window 'right,50%' --preview-border line \
      --bind 'ctrl-/:change-preview-window(down,50%|hidden|)' \
      --query "${FZF_GIT_QUERY:-}" "$@"
  }
fi

# Strip ANSI escape codes from text
_fzf_git_strip_ansi() {
  sed 's/\x1b\[[0-9;]*m//g'
}

# Wrapper that auto-completes on single match, otherwise invokes FZF
# Filters input by FZF_GIT_QUERY prefix, returns directly if only 1 match
_fzf_git_select() {
  local input header_lines
  input=$(cat)

  # Check if --header-lines is specified (extract the number)
  header_lines=0
  for arg in "$@"; do
    if [[ $arg =~ ^--header-lines[[:space:]]*([0-9]+)$ ]] || [[ $arg == --header-lines ]]; then
      # Handle --header-lines N format
      continue
    fi
    if [[ $prev_arg == "--header-lines" ]]; then
      header_lines=$arg
    fi
    prev_arg=$arg
  done
  # Also check for --header-lines=N format
  for arg in "$@"; do
    if [[ $arg =~ ^--header-lines[=[:space:]]?([0-9]+)$ ]]; then
      header_lines="${BASH_REMATCH[1]}"
    fi
  done

  # Extract header and data lines
  local header_content data_lines
  if [[ $header_lines -gt 0 ]]; then
    header_content=$(echo "$input" | head -n "$header_lines")
    data_lines=$(echo "$input" | tail -n +"$((header_lines + 1))")
  else
    header_content=""
    data_lines="$input"
  fi

  # Filter by query if provided (strip ANSI for matching, keep original for display)
  # Skip grep pre-filter for fzf-specific syntax (! negation, ' exact, ^ prefix)
  # since grep can't handle these operators - let fzf process them directly
  if [[ -n "${FZF_GIT_QUERY:-}" ]] && [[ ! "${FZF_GIT_QUERY}" =~ ^[\!\'\^] ]]; then
    local filtered
    # Case-insensitive match anywhere in line (git output has varied formats)
    # Use -- to prevent query from being interpreted as grep options
    filtered=$(echo "$data_lines" | grep -i -- "${FZF_GIT_QUERY}")

    # Count non-empty lines
    local count
    count=$(printf '%s' "$filtered" | grep -c . 2>/dev/null || true)

    # Single match - return directly without FZF (strip ANSI codes)
    if [[ $count -eq 1 ]]; then
      echo "$filtered" | _fzf_git_strip_ansi
      return
    fi

    # No matches - return empty
    if [[ $count -eq 0 ]]; then
      return
    fi

    # Multiple matches - reassemble with header for FZF
    if [[ -n "$header_content" ]]; then
      input=$(printf '%s\n%s' "$header_content" "$filtered")
    else
      input="$filtered"
    fi
  fi

  # Multiple matches or no query - use FZF
  # Use --tiebreak=index to preserve original order (modified files first) when query is pre-filled
  if [[ -n "${FZF_GIT_QUERY:-}" ]]; then
    echo "$input" | _fzf_git_fzf --tiebreak=index "$@"
  else
    echo "$input" | _fzf_git_fzf "$@"
  fi
}

_fzf_git_check() {
  git rev-parse > /dev/null 2>&1 && return

  [[ -n $TMUX ]] && tmux display-message "Not in a git repository"
  return 1
}

__fzf_git=${BASH_SOURCE[0]:-${(%):-%x}}
__fzf_git=$(readlink -f "$__fzf_git" 2> /dev/null || /usr/bin/ruby --disable-gems -e 'puts File.expand_path(ARGV.first)' "$__fzf_git" 2> /dev/null)

_fzf_git_files() {
  _fzf_git_check || return
  local root query extract_file_name combined_query
  root=$(git rev-parse --show-toplevel)
  [[ -n "$(git rev-parse --show-prefix)" ]] && query='!../ '

  # Combine local query prefix with user's partial input
  combined_query="${query}${FZF_GIT_QUERY:-}"

  read -r -d "" extract_file_name <<'EOF'
"$(cut -c4- <<< {} | sed 's/.* -> //;s/^"//;s/"$//;s/\\"/"/g')"
EOF

  (
    git -c core.quotePath=false -c color.status=$(__fzf_git_color) status --short --no-branch --untracked-files=all
    git -c core.quotePath=false ls-files "$root" | grep -vxFf <(
      git -c core.quotePath=false status --short --untracked-files=no |
        cut -c4- | sed -e 's/.* -> //' -e '/^"[^"\\]*"$/ { s/^"//;s/"$//; }'
      echo :
    ) | sed 's/^/   /'
  ) |
    FZF_GIT_QUERY="$combined_query" _fzf_git_select -m --ansi --nth 2..,.. \
      --border-label '📁 Files ' \
      --header 'CTRL-O (open in browser) ╱ ALT-E (open in editor)' \
      --bind "ctrl-o:execute-silent:bash \"$__fzf_git\" --list file $extract_file_name" \
      --bind "alt-e:execute:${EDITOR:-vim} $extract_file_name < /dev/tty > /dev/tty" \
      --preview "git -c core.quotePath=false diff --no-ext-diff --color=$(__fzf_git_color .) -- $extract_file_name | $(__fzf_git_pager); $(__fzf_git_cat) $extract_file_name" "$@" |
    cut -c4- | sed 's/.* -> //'
}

_fzf_git_branches() {
  _fzf_git_check || return

  local shell
  [[ -n ${BASH_VERSION:-} ]] && shell=bash || shell=zsh

  bash "$__fzf_git" --list branches |
  __fzf_git_fzf=$(declare -f _fzf_git_fzf) _fzf_git_select --ansi \
    --border-label '🌲 Branches ' \
    --header-lines 2 \
    --header 'CTRL-O (open) ╱ CTRL-H (hashes) ╱ CTRL-T (tags) ╱ ALT-A (all) ╱ ALT-H (branch hashes) ╱ ALT-ENTER (no remote)' \
    --tiebreak begin \
    --preview-window down,border-top,40% \
    --color hl:underline,hl+:underline \
    --no-hscroll \
    --bind 'ctrl-/:change-preview-window(down,70%|hidden|)' \
    --bind "ctrl-o:execute-silent:bash \"$__fzf_git\" --list branch {}" \
    --bind "alt-a:change-border-label(🌳 All branches)+reload:bash \"$__fzf_git\" --list all-branches" \
    --bind "ctrl-h:become:$shell \"$__fzf_git\" --run hashes" \
    --bind "alt-h:become:LIST_OPTS=\$(cut -c3- <<< {} | cut -d' ' -f1) $shell \"$__fzf_git\" --run hashes" \
    --bind "alt-enter:become:printf '%s\n' {+} | cut -c3- | sed 's@[^/]*/@@'" \
    --bind "ctrl-t:become:$shell \"$__fzf_git\" --run tags" \
    --preview "git log --oneline --graph --date=short --color=$(__fzf_git_color .) --pretty='format:%C(auto)%cd %h%d %s' \$(cut -c3- <<< {} | cut -d' ' -f1) --" "$@" |
  sed 's/^\* //' | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $1}' # Strip ANSI codes before extraction
}

_fzf_git_tags() {
  _fzf_git_check || return

  local shell
  [[ -n ${BASH_VERSION:-} ]] && shell=bash || shell=zsh

  git tag --sort -version:refname |
  _fzf_git_select --preview-window right,70% \
    --border-label '📛 Tags ' \
    --header 'CTRL-B (branches) ╱ CTRL-H (hashes) ╱ CTRL-O (open in browser)' \
    --bind "ctrl-b:become:$shell \"$__fzf_git\" --run branches" \
    --bind "ctrl-h:become:$shell \"$__fzf_git\" --run hashes" \
    --bind "ctrl-o:execute-silent:bash \"$__fzf_git\" --list tag {}" \
    --preview "git show --color=$(__fzf_git_color .) {} | $(__fzf_git_pager)" "$@"
}

_fzf_git_hashes() {
  _fzf_git_check || return

  local shell
  [[ -n ${BASH_VERSION:-} ]] && shell=bash || shell=zsh

  bash "$__fzf_git" --list hashes |
  _fzf_git_select --ansi --no-sort --bind 'ctrl-s:toggle-sort' \
    --border-label '🍡 Hashes ' \
    --header-lines 2 \
    --header 'CTRL-O (open) ╱ CTRL-D (diff) ╱ CTRL-B (branches) ╱ CTRL-T (tags) ╱ CTRL-W (worktrees) ╱ ALT-A (all)' \
    --bind "ctrl-o:execute-silent:bash \"$__fzf_git\" --list commit {}" \
    --bind "ctrl-d:execute:grep -o '[a-f0-9]\{7,\}' <<< {} | head -n 1 | xargs git diff --color=$(__fzf_git_color) > /dev/tty" \
    --bind "alt-a:change-border-label(🍇 All hashes)+reload:bash \"$__fzf_git\" --list all-hashes" \
    --bind "ctrl-b:become:$shell \"$__fzf_git\" --run branches" \
    --bind "ctrl-t:become:$shell \"$__fzf_git\" --run tags" \
    --bind "ctrl-w:become:$shell \"$__fzf_git\" --run worktrees-branch" \
    --color hl:underline,hl+:underline \
    --preview "grep -o '[a-f0-9]\{7,\}' <<< {} | head -n 1 | xargs git show --color=$(__fzf_git_color .) | $(__fzf_git_pager)" "$@" |
  awk 'match($0, /[a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9][a-f0-9]*/) { print substr($0, RSTART, RLENGTH); next } { print }' # Pass through non-hash output (e.g., branch names from become)
}

_fzf_git_remotes() {
  _fzf_git_check || return

  local shell
  [[ -n ${BASH_VERSION:-} ]] && shell=bash || shell=zsh

  git remote -v | awk '{print $1 "\t" $2}' | uniq |
  _fzf_git_select --tac \
    --border-label '📡 Remotes ' \
    --header 'CTRL-O (open) ╱ CTRL-B (branches) ╱ CTRL-H (hashes) ╱ CTRL-T (tags)' \
    --bind "ctrl-o:execute-silent:bash \"$__fzf_git\" --list remote {1}" \
    --bind "ctrl-b:become:$shell \"$__fzf_git\" --run branches" \
    --bind "ctrl-h:become:$shell \"$__fzf_git\" --run hashes" \
    --bind "ctrl-t:become:$shell \"$__fzf_git\" --run tags" \
    --preview-window right,70% \
    --preview "git log --oneline --graph --date=short --color=$(__fzf_git_color .) --pretty='format:%C(auto)%cd %h%d %s' '{1}/$(git rev-parse --abbrev-ref HEAD)' --" "$@" |
  cut -d$'\t' -f1
}

_fzf_git_stashes() {
  _fzf_git_check || return

  local shell
  [[ -n ${BASH_VERSION:-} ]] && shell=bash || shell=zsh

  git stash list | _fzf_git_select \
    --border-label '🥡 Stashes ' \
    --header 'CTRL-X (drop) ╱ CTRL-B (branches) ╱ CTRL-H (hashes) ╱ CTRL-T (tags)' \
    --bind 'ctrl-x:reload(git stash drop -q {1}; git stash list)' \
    --bind "ctrl-b:become:$shell \"$__fzf_git\" --run branches" \
    --bind "ctrl-h:become:$shell \"$__fzf_git\" --run hashes" \
    --bind "ctrl-t:become:$shell \"$__fzf_git\" --run tags" \
    -d: --preview "git show --first-parent --color=$(__fzf_git_color .) {1} | $(__fzf_git_pager)" "$@" |
  cut -d: -f1
}

_fzf_git_lreflogs() {
  _fzf_git_check || return

  local shell
  [[ -n ${BASH_VERSION:-} ]] && shell=bash || shell=zsh

  git reflog --color=$(__fzf_git_color) --format="%C(blue)%gD %C(yellow)%h%C(auto)%d %gs" | _fzf_git_select --ansi \
    --border-label '📒 Reflogs ' \
    --header 'CTRL-B (branches) ╱ CTRL-H (hashes) ╱ CTRL-T (tags)' \
    --bind "ctrl-b:become:$shell \"$__fzf_git\" --run branches" \
    --bind "ctrl-h:become:$shell \"$__fzf_git\" --run hashes" \
    --bind "ctrl-t:become:$shell \"$__fzf_git\" --run tags" \
    --preview "git show --color=$(__fzf_git_color .) {1} | $(__fzf_git_pager)" "$@" |
  awk '{print $1}'
}

_fzf_git_each_ref() {
  _fzf_git_check || return

  local shell
  [[ -n ${BASH_VERSION:-} ]] && shell=bash || shell=zsh

  bash "$__fzf_git" --list refs | _fzf_git_select --ansi \
    --nth 2,2.. \
    --tiebreak begin \
    --border-label '☘️  Each ref ' \
    --header-lines 1 \
    --header 'CTRL-O (open) ╱ ALT-E (edit) ╱ ALT-A (all) ╱ CTRL-B (branches) ╱ CTRL-H (hashes) ╱ CTRL-T (tags)' \
    --preview-window down,border-top,40% \
    --color hl:underline,hl+:underline \
    --no-hscroll \
    --bind 'ctrl-/:change-preview-window(down,70%|hidden|)' \
    --bind "ctrl-o:execute-silent:bash \"$__fzf_git\" --list {1} {2}" \
    --bind "alt-e:execute:${EDITOR:-vim} <(git show {2}) < /dev/tty > /dev/tty" \
    --bind "alt-a:change-border-label(🍀 Every ref)+reload:bash \"$__fzf_git\" --list all-refs" \
    --bind "ctrl-b:become:$shell \"$__fzf_git\" --run branches" \
    --bind "ctrl-h:become:$shell \"$__fzf_git\" --run hashes" \
    --bind "ctrl-t:become:$shell \"$__fzf_git\" --run tags" \
    --preview "git log --oneline --graph --date=short --color=$(__fzf_git_color .) --pretty='format:%C(auto)%cd %h%d %s' {2} --" "$@" |
  awk '{print $2}'
}

_fzf_git_worktrees() {
  _fzf_git_check || return

  local shell
  [[ -n ${BASH_VERSION:-} ]] && shell=bash || shell=zsh

  git worktree list | _fzf_git_select \
    --border-label '🌴 Worktrees ' \
    --header 'CTRL-X (remove) ╱ CTRL-B (branches) ╱ CTRL-H (hashes) ╱ CTRL-T (tags)' \
    --bind 'ctrl-x:reload(git worktree remove {1} > /dev/null; git worktree list)' \
    --bind "ctrl-b:become:$shell \"$__fzf_git\" --run branches" \
    --bind "ctrl-h:become:$shell \"$__fzf_git\" --run hashes" \
    --bind "ctrl-t:become:$shell \"$__fzf_git\" --run tags" \
    --preview "
      git -c color.status=$(__fzf_git_color .) -C {1} status --short --branch
      echo
      git log --oneline --graph --date=short --color=$(__fzf_git_color .) --pretty='format:%C(auto)%cd %h%d %s' {2} --
    " "$@" |
  awk '{print $1}'
}

# Variant that returns branch name instead of path (for git difftool, etc.)
_fzf_git_worktrees-branch() {
  _fzf_git_check || return
  git worktree list | _fzf_git_select \
    --border-label '🌴 Worktrees (branch mode) ' \
    --header 'Select worktree → returns branch name' \
    --preview "
      git -c color.status=$(__fzf_git_color .) -C {1} status --short --branch
      echo
      git log --oneline --graph --date=short --color=$(__fzf_git_color .) --pretty='format:%C(auto)%cd %h%d %s' {2} --
    " "$@" |
  awk '{print $3}' | tr -d '[]'
}

_fzf_git_list_bindings() {
  cat <<'EOF'

CTRL-G ? to show this list
CTRL-G CTRL-F for Files
CTRL-G CTRL-B for Branches
CTRL-G CTRL-T for Tags
CTRL-G CTRL-R for Remotes
CTRL-G CTRL-H for commit Hashes
CTRL-G CTRL-S for Stashes
CTRL-G CTRL-L for reflogs
CTRL-G CTRL-W for Worktrees
CTRL-G CTRL-E for Each ref (git for-each-ref)
EOF
}

fi # --------------------------------------------------------------------------

if [[ $1 = --run ]]; then
  shift
  type=$1
  shift
  eval "_fzf_git_$type" "$@"

elif [[ $- =~ i ]]; then # ------------------------------------------------------
if [[ -n "${BASH_VERSION:-}" ]]; then
  __fzf_git_init() {
    bind -m emacs-standard '"\er":  redraw-current-line'
    bind -m emacs-standard '"\C-z": vi-editing-mode'
    bind -m vi-command     '"\C-z": emacs-editing-mode'
    bind -m vi-insert      '"\C-z": emacs-editing-mode'

    local o c
    for o in "$@"; do
      c=${o:0:1}
      if [[ $c == '?' ]]; then
        bind -x "\"\C-g$c\": _fzf_git_list_bindings"
        continue
      fi
      bind -m emacs-standard '"\C-g\C-'$c'": " \C-u \C-a\C-k`_fzf_git_'$o'`\e\C-e\C-y\C-a\C-y\ey\C-h\C-e\er \C-h"'
      bind -m vi-command     '"\C-g\C-'$c'": "\C-z\C-g\C-'$c'\C-z"'
      bind -m vi-insert      '"\C-g\C-'$c'": "\C-z\C-g\C-'$c'\C-z"'
      bind -m emacs-standard '"\C-g'$c'":    " \C-u \C-a\C-k`_fzf_git_'$o'`\e\C-e\C-y\C-a\C-y\ey\C-h\C-e\er \C-h"'
      bind -m vi-command     '"\C-g'$c'":    "\C-z\C-g'$c'\C-z"'
      bind -m vi-insert      '"\C-g'$c'":    "\C-z\C-g'$c'\C-z"'
    done
  }
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  __fzf_git_join() {
    local item
    while read -r item; do
      echo -n -E "${(q)${(Q)item}} "
    done
  }

  __fzf_git_init() {
    setopt localoptions no_glob
    local m o
    for o in "$@"; do
      if [[ ${o[1]} == "?" ]];then
        eval "fzf-git-$o-widget() { zle -M '$(_fzf_git_list_bindings)' }"
      else
        eval "fzf-git-$o-widget() { local result=\$(_fzf_git_$o | __fzf_git_join); zle reset-prompt; LBUFFER+=\$result }"
      fi
      eval "zle -N fzf-git-$o-widget"
      for m in emacs vicmd viins; do
        eval "bindkey -M $m '^g^${o[1]}' fzf-git-$o-widget"
        eval "bindkey -M $m '^g${o[1]}' fzf-git-$o-widget"
      done
    done
  }
fi
__fzf_git_init files branches tags remotes hashes stashes lreflogs each_ref worktrees '?list_bindings'

fi # --------------------------------------------------------------------------
