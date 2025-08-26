# Developer Productivity Tools Guide

These are the command-line tools I use daily that have made a real difference in my development workflow.

## Environment Management

### [direnv](https://github.com/direnv/direnv)
Automatically loads environment variables when you enter a directory and unloads them when you leave. I mainly use this for switching between different AWS profiles and API keys across projects.

**Why I like it**: No more accidentally running commands against production when I meant to use staging.

### [mise](https://github.com/jdx/mise)
Manages different versions of programming languages per project. It handles Node.js, Python, Ruby, Go, and pretty much everything else. It's basically a faster, more modern version of asdf.

**Why I like it**: Everyone on the team uses the exact same versions, so we don't waste time debugging version differences.

## Navigation & Search

### [zoxide](https://github.com/ajeetdsouza/zoxide)
A smarter cd command that remembers which directories you use most often. Instead of typing out long paths, you can jump around with just a few characters.

**Why I like it**: I can type `z controllers` instead of `cd ~/projects/client/backend/src/controllers`.

### [fzf](https://github.com/junegunn/fzf)
A fuzzy finder that makes searching through anything interactive and fast. Works with files, command history, git branches, or any list you throw at it.

**Why I like it**: Ctrl+R gives me smart command history search, and I can quickly find any file with Ctrl+T.

## File & Output Enhancement

### [bat](https://github.com/sharkdp/bat)
It's cat but with syntax highlighting, line numbers, and git integration. Makes reading code files in the terminal actually nice.

**Why I like it**: I can quickly check files without opening an editor, and the syntax highlighting helps me spot issues faster.

### [splash](https://github.com/splash-cli/splash-cli)
Adds color to log output, highlighting things like ERROR, WARN, HTTP status codes, and timestamps. Makes logs much easier to scan through.

**Why I like it**: Errors and important information actually stand out instead of getting lost in walls of text.

## AWS & Cloud

### [granted](https://github.com/common-fate/granted)
Makes switching between AWS profiles and roles simple. Also handles MFA without any hassle and can open the AWS Console with the right credentials.

**Why I like it**: I just type `assume production` and I'm in the right AWS account. No more messing with credentials files.

## Terminal Multiplexing

### [tmux](https://github.com/tmux/tmux)
Lets you create terminal sessions that keep running even if your connection drops. You can split your terminal into panes, create multiple windows, and organize your workspace.

**Why I like it**: When my SSH connection drops, I can reconnect and pick up exactly where I left off. Also great for keeping long-running processes going.

## Quick Setup

```bash
# macOS (using Homebrew)
brew install direnv mise zoxide fzf bat tmux granted
brew tap joshi4/splash && brew install splash

# Add these to your shell config file
eval "$(direnv hook bash)"  # or fish/zsh
eval "$(zoxide init bash)"   # or fish/zsh
eval "$(fzf --bash)"         # or fish/zsh
alias assume="source $(which assume)"  # for granted
```

## How They Work Together

Here's what happens when I start working on a project:

```bash
z project          # zoxide jumps to my project directory
                   # direnv loads my environment variables
                   # mise switches to the right Node and Python versions
assume production  # granted switches my AWS credentials
tmux new -s work   # start a tmux session for this project
fzf                # quickly find the file I need
bat config.yaml    # check the config with nice highlighting
kubectl logs api | splash  # watch logs with color coding
```

## Why These Specific Tools?

I picked these because each one solves a real problem I was having:
- **direnv**: I kept forgetting to switch environments
- **mise**: Team members had different versions causing bugs
- **zoxide**: Got tired of typing long directory paths
- **fzf**: Needed faster ways to find things
- **bat**: Wanted to quickly check files without opening vim
- **splash**: Couldn't spot errors in plain log output
- **granted**: AWS profile switching was a pain
- **tmux**: Lost work too many times from disconnections

You don't need to adopt all of these at once. I'd suggest starting with one or two that address your biggest pain points, then adding more as you get comfortable.

## Additional Resources

- [My Dotfiles](https://github.com/yourusername/dotfiles) - My configurations for these tools
- [Modern Unix](https://github.com/ibraheemdev/modern-unix) - List of other great command-line tools
- [Awesome Shell](https://github.com/alebcay/awesome-shell) - Curated collection of shell resources