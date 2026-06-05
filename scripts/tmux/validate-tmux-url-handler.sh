#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HANDLER="$ROOT/scripts/tmux/tmux-url-handler.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

fail() {
    echo "FAIL $1" >&2
    if [ -f "$TMUX_LOG" ]; then
        echo "--- tmux log ---" >&2
        cat "$TMUX_LOG" >&2
    fi
    if [ -f "$NVIM_LOG" ]; then
        echo "--- nvim log ---" >&2
        cat "$NVIM_LOG" >&2
    fi
    exit 1
}

FAKEBIN="$TMPDIR/fakebin"
PROJECT="$TMPDIR/project"
HOME_DIR="$TMPDIR/home"
TMUX_LOG="$TMPDIR/tmux.log"
NVIM_LOG="$TMPDIR/nvim.log"
CAPTURE_CONTENT="$TMPDIR/capture.txt"

mkdir -p "$FAKEBIN" "$PROJECT/docs" "$PROJECT/screens" "$HOME_DIR/dotfiles/scripts"
touch "$PROJECT/docs/report.pdf" "$PROJECT/README.md" "$PROJECT/screens/failure.png"

cat >"$FAKEBIN/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cmd="${1:-}"
if [ "$#" -gt 0 ]; then
  shift
fi

printf '%s\t%s\n' "$cmd" "$*" >>"$TMUX_LOG"

case "$cmd" in
display-message)
  if [ "${1:-}" = "-p" ]; then
    format="${2:-}"
    case "$format" in
    *pane_current_path*) printf '%s\n' "$PROJECT" ;;
    *pane_id*) printf '%%ai-pane\n' ;;
    *) printf 'session:1\n' ;;
    esac
  fi
  ;;
capture-pane)
  cat "$CAPTURE_CONTENT"
  ;;
display-menu | display-popup)
  :
  ;;
*)
  :
  ;;
esac
EOF
chmod +x "$FAKEBIN/tmux"

cat >"$HOME_DIR/dotfiles/scripts/nvim-open-file.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NVIM_LOG"
EOF
chmod +x "$HOME_DIR/dotfiles/scripts/nvim-open-file.sh"

export PATH="$FAKEBIN:$PATH"
export PROJECT TMUX_LOG CAPTURE_CONTENT NVIM_LOG
export HOME="$HOME_DIR"
export TMUX="/tmp/tmux-test,1,0"
export TMUX_PANE="%ai-pane"

cat >"$CAPTURE_CONTENT" <<EOF
Open https://github.com/example/repo and example.com/docs.
Markdown PDF: [report](docs/report.pdf)
Markdown note: [readme](README.md:12)
Image artifact: screens/failure.png
EOF

"$HANDLER"

if ! grep -Fq -- 'display-menu' "$TMUX_LOG"; then
    fail "multiple targets should preserve the tmux selection menu"
fi

for expected in 'URL  github.com/example/repo' 'URL  example.com/docs' 'PDF  docs/report.pdf' 'MD   README.md:12' 'MED  screens/failure.png'; do
    if ! grep -Fq -- "$expected" "$TMUX_LOG"; then
        fail "missing menu target: $expected"
    fi
done

if ! grep -Fq -- 'scripts/nvim-open-file.sh' "$TMUX_LOG"; then
    fail "markdown/text targets should route through the Neovim opener"
fi

if ! grep -Fq -- '/usr/bin/open' "$TMUX_LOG"; then
    fail "URL/PDF/media targets should route through system open commands"
fi

: >"$TMUX_LOG"
: >"$NVIM_LOG"
cat >"$CAPTURE_CONTENT" <<EOF
Only one referenced markdown file: README.md:8
EOF

"$HANDLER"
sleep 0.2

if ! grep -Fq -- "$PROJECT/README.md --line 8 --target %ai-pane" "$NVIM_LOG"; then
    fail "single markdown target did not open through Neovim with line number"
fi

if grep -Fq -- 'display-menu' "$TMUX_LOG"; then
    fail "single target should not show the selection menu"
fi

echo "PASS tmux URL/file handler validation complete"
