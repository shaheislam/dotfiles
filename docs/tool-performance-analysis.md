# Terminal Tool Performance Analysis

> **Date**: 2026-02-14
> **Purpose**: Evaluate whether migrating from current tools would yield significant performance benefits
> **Current Stack**: Fish + Starship + tmux + WezTerm/Ghostty

---

## TL;DR - Recommendations

| Tool | Current | Migrate To? | Verdict |
|------|---------|-------------|---------|
| **Shell** | Fish | Stay with Fish | **NO MIGRATION** - Fish is faster than configured Zsh, and you have 20K+ lines of Fish investment |
| **Prompt** | Starship | Stay with Starship | **NO MIGRATION** - ~30ms overhead is negligible; switching to Tide/Hydro saves ~25ms but loses cross-shell support |
| **Multiplexer** | tmux | Stay with tmux | **NO MIGRATION** - tmux uses 6MB vs Zellij's 80MB; battle-tested stability wins |
| **Terminal** | WezTerm + Ghostty | **Ghostty as primary** | **MINOR CHANGE** - Ghostty has native Metal, 2-5x faster throughput on macOS; already configured |

**Bottom line**: Your current stack is already well-optimized. The only actionable change is making Ghostty your primary terminal (which you already have configured). Everything else would be a downgrade or lateral move given your investment level.

---

## 1. Shell: Fish vs Zsh vs Bash

### Performance Data (Bare Shell Startup)

| Shell | Startup (unconfigured) | Source |
|-------|----------------------|--------|
| Bash | 3.3 ms | Tratt 2024 |
| Zsh | 4.2 ms | Tratt 2024 |
| Fish | 14.0 ms | Tratt 2024 |

### Real-World Performance (With Configuration)

| Configuration | Startup Time |
|---------------|-------------|
| Fish (typical user) | 50-100 ms |
| Fish (your config, with caching) | ~60-90 ms (estimated) |
| Zsh + Oh My Zsh (your 7 plugins) | 420-600 ms |
| Zsh (optimized, no OMZ) | ~50 ms |
| Bash (your minimal config) | ~10 ms |

### Why Fish Wins for Your Setup

**Fish is 4-6x faster than your Zsh config** in real-world startup because:

1. **Lazy function loading**: Fish only loads a function when called. Your 222 functions cost zero startup time.
2. **Built-in features**: Fish includes syntax highlighting and autosuggestions natively. Zsh needs plugins (`zsh-syntax-highlighting`, `zsh-autosuggestions`) that add ~100ms+ each.
3. **No framework overhead**: Oh My Zsh adds ~250ms just to load its core. You'd need to replace it with zinit/antidote and lazy-load everything.
4. **Your caching layer**: `__cache_tool_init` already caches starship (~20ms), fzf (~50ms), thefuck (~557ms), carapace (~230ms) = **~857ms saved**.

### Migration Cost Analysis

| Factor | Impact |
|--------|--------|
| 222 custom Fish functions | ~20,000 lines to rewrite in POSIX-compatible syntax |
| `conf.d/` configs (28 files) | All need Zsh equivalents |
| Fish-specific syntax | `set -gx`, `string`, `test`, `and/or` all differ from Bash/Zsh |
| Claude Code integration | 14+ functions deeply tied to Fish |
| Worktree/Devcontainer system | `gwt-*` family (1,073+ lines in gwt-ticket alone) |

**Estimated migration effort**: 2-4 weeks of full-time work, for a net performance gain of approximately **0ms** (or negative, if Zsh plugins aren't perfectly optimized).

### Verdict: Stay with Fish

- The 10ms bare-startup difference is imperceptible
- Fish's lazy loading makes 222 functions cost zero
- Your caching layer already eliminates the main bottlenecks
- Migration would cost weeks of effort for zero measurable gain
- Bash/Zsh would lose Fish's superior interactive features (inline help, web-based config, native autosuggestions)

---

## 2. Prompt: Starship vs Alternatives

### Render Time Per Prompt

| Prompt | Render Time | Architecture |
|--------|------------|--------------|
| Powerlevel10k (Zsh) | ~2-6 ms | In-process (Zsh only) |
| Hydro (Fish-native) | <5 ms | In-process (Fish only) |
| Tide (Fish-native) | ~5-10 ms | In-process (Fish only) |
| Pure (Fish/Zsh) | Near-instant | In-process + async git |
| **Starship** | **~30-80 ms** | External Rust binary |
| Oh-My-Posh | ~50-90 ms | External Go binary |

### Your Starship Config Analysis

Your config is lean and well-optimized:
- **Left prompt**: directory + git_branch + git_status + character (4 modules)
- **Right prompt**: runtime languages + aws/azure/k8s/terraform + cmd_duration (8 modules, most dormant)
- **Timeout**: 1000ms (generous, prevents blocking)
- **Disabled modules**: os, docker_context, time

**Estimated render time**: ~30-50ms (lean config, most right-side modules inactive unless in relevant project)

### Would Switching Help?

| Switch To | Time Saved | Trade-offs |
|-----------|-----------|------------|
| Hydro | ~25-45 ms/prompt | Lose cross-shell support, simpler appearance |
| Tide | ~20-40 ms/prompt | Fish-only, more setup needed |
| Pure | ~25-45 ms/prompt | Lose rich right-prompt modules |

### Verdict: Stay with Starship

- 30-50ms per prompt is below the 50ms human perception threshold for "first prompt lag"
- You'd lose the rich right-side context (aws, k8s, terraform) that provides real value
- Cross-shell support matters for your Zsh fallback
- The prompt is not your bottleneck

---

## 3. Terminal Multiplexer: tmux vs Zellij

### Resource Comparison

| Metric | tmux | Zellij |
|--------|------|--------|
| Memory (empty session) | **6 MB** | 80 MB (13x more) |
| Binary size | ~900 KB | ~38 MB |
| Startup time | ~55 ms | Slower (Rust runtime + WASM) |
| Throughput (2M lines) | 5.6s | 5.3s (after optimization) |
| Pane switching | Instant | Generally fast, lag on remote |
| Stability (long-running) | Rock-solid | Memory growth reported (2-4 GB after weeks) |

### Your tmux Investment

| Component | Details |
|-----------|---------|
| Config lines | 370+ lines of `.tmux.conf` |
| Plugins (TPM) | 15 active plugins |
| Custom integrations | Claude watcher daemon, activity monitoring |
| History limit | 1,000,000 lines |
| Key bindings | Extensively customized (Ctrl-s prefix, vi mode) |
| Agent orchestration | `gwt-*` family relies heavily on tmux sessions/windows |

### What Zellij Offers

Pros over tmux:
- Built-in discoverable UI (keybinding hints)
- First-class WASM plugin system
- Floating panes
- Better default experience for new users

Cons vs tmux:
- 13x more memory per session
- Your entire agent orchestration system (`gwt-ticket`, `gwt-parallel`, `gwt-doctor`, `tmux-claude-watcher.sh`) relies on tmux's session/window/pane model
- No equivalent to your 15 TPM plugins
- Stability concerns for long-running sessions (critical for ralph-loop)
- Smaller ecosystem and community

### Verdict: Stay with tmux

- Your agent orchestration system is deeply married to tmux
- Memory overhead is 13x worse with Zellij
- Stability matters for long-running autonomous agent sessions
- tmux's 30+ year maturity provides reliability that Zellij hasn't yet achieved

---

## 4. Terminal Emulator: WezTerm vs Ghostty vs Kitty

### Performance Comparison (macOS/Apple Silicon)

| Metric | WezTerm | Ghostty | Kitty | Alacritty |
|--------|---------|---------|-------|-----------|
| **Input latency** | ~26 ms avg | ~13 ms avg | **~10-11 ms** (tuned) | ~7 ms avg |
| **Text throughput** | Slowest (16-26 MB/s) | **2-5x faster** (Metal) | 2nd fastest (OpenGL) | Mid-range |
| **Memory (idle)** | ~60 MB | ~50 MB | ~40-50 MB | ~30 MB |
| **GPU backend** | WebGPU | **Native Metal** | OpenGL | OpenGL |
| **Ligatures** | Yes | Yes | Yes | No |
| **Lua scripting** | Yes | No | Partial (kitten) | No |
| **Image protocol** | Yes (Kitty protocol) | Yes | Yes (native) | No |

### Your Current Setup

You already have **both WezTerm and Ghostty configured** with feature parity:
- Same font (JetBrainsMono Nerd Font)
- Same theme (Catppuccin Mocha)
- Same opacity (0.90)
- Matching keybindings
- Matching scrollback (10,000 lines)

### Analysis: Ghostty vs WezTerm

**Ghostty advantages on macOS**:
- **Native Metal rendering**: 2-5x faster text throughput than WezTerm
- **Lower input latency**: ~13ms vs ~26ms
- **Less memory**: ~50 MB vs ~60 MB
- **Native macOS integration**: Transparent titlebar, system font rendering
- **Simpler config**: 112 lines vs 200+ Lua lines

**WezTerm advantages**:
- **Lua scripting**: Dynamic configuration, custom keybindings, event hooks
- **Multiplexing built-in**: Can replace tmux for some use cases
- **Cross-platform**: Same config on macOS/Linux/Windows
- **Mature & stable**: Longer track record

### What About Kitty?

Kitty has the **lowest input latency** on macOS (~10-11ms tuned) and excellent throughput. However:
- You'd need to create a new config from scratch
- No equivalent to WezTerm's Lua extensibility
- You already have Ghostty configured (13ms latency, Metal throughput)
- The 2-3ms difference between Ghostty and Kitty is imperceptible

### Verdict: Use Ghostty as Primary

You already have Ghostty fully configured. It provides:
- 2x lower input latency than WezTerm (13ms vs 26ms)
- 2-5x faster text throughput via native Metal
- Native macOS feel
- All the same features you use

Keep WezTerm as a secondary for its Lua extensibility when needed.

---

## 5. Other Tools Worth Noting

### Tools You're Already Using That Are Optimal

| Tool | Category | Why It's Already Best-in-Class |
|------|----------|-------------------------------|
| eza | ls replacement | Rust, fast, git-aware |
| fd | find replacement | Rust, 5-10x faster than find |
| bat | cat replacement | Rust, syntax highlighting |
| zoxide | cd replacement | Rust, frequency-based |
| fzf | fuzzy finder | Go, sub-millisecond filtering |
| delta | git diff | Rust, syntax-aware |
| mise | version manager | Rust, faster than asdf |
| Starship | prompt | Rust, cross-shell |

These are already the performance-optimal choices. No changes needed.

### Potential Minor Optimizations

| Optimization | Impact | Effort |
|-------------|--------|--------|
| Ghostty as primary terminal | ~13ms less input latency per keystroke | Already configured |
| Disable unused Starship right-prompt modules | ~5-10ms per prompt in irrelevant directories | Low |
| Audit tmux plugins for unused ones | Marginal startup improvement | Low |

---

## 6. Summary

### Performance Priority Matrix

| Area | Current Performance | Potential Gain from Migration | Recommendation |
|------|--------------------|-----------------------------|----------------|
| Shell startup | ~60-90ms (excellent) | 0ms (Zsh would be worse) | **Keep Fish** |
| Prompt render | ~30-50ms (good) | ~25ms (with Fish-native) | **Keep Starship** |
| Multiplexer memory | 6MB (optimal) | Negative (Zellij: 80MB) | **Keep tmux** |
| Terminal throughput | WezTerm: slow | 2-5x with Ghostty | **Switch to Ghostty primary** |
| Terminal latency | WezTerm: 26ms | 13ms with Ghostty | **Switch to Ghostty primary** |

### The Real Performance Bottlenecks

Your terminal tool stack is **not** your performance bottleneck. The real bottlenecks in a developer workflow are:
1. **Network I/O**: API calls, git fetches, package installs
2. **Build times**: Compilation, bundling, test execution
3. **Context switching**: Task management, tool discovery
4. **Cognitive load**: Understanding code, debugging

Your dotfiles already optimize for #3 and #4 with 222 Fish functions, FZF integration everywhere, and agent orchestration. The terminal tools are already in the top tier.

---

## Sources

- [Laurence Tratt: Faster Shell Startup With Shell Switching (2024)](https://tratt.net/laurie/blog/2024/faster_shell_startup_with_shell_switching.html)
- [romkatv/zsh-bench - Benchmark for Interactive Zsh](https://github.com/romkatv/zsh-bench)
- [Terminal Latency Benchmarks - beuke.org](https://beuke.org/terminal-latency/)
- [Ghostty Performance Discussion #4837](https://github.com/ghostty-org/ghostty/discussions/4837)
- [Kitty Performance Documentation](https://sw.kovidgoyal.net/kitty/performance/)
- [Zellij Memory Discussion #3594](https://github.com/zellij-org/zellij/issues/3594)
- [Zellij Performance Blog - poor.dev](https://poor.dev/blog/performance/)
- [Oh My Zsh Startup Optimization](https://blog.jonlu.ca/posts/speeding-up-zsh)
