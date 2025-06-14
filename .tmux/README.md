# ~/.config/tmux/tmux.conf

## Install

Once everything has been installed it's time to run TPM, install first:

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

## Run

`Ctrl+I`

# tmux Plugin Installation

## Installing Plugins with TPM

1. Start or attach to a tmux session:
   ```sh
   tmux
   ```
2. Reload your tmux config:
   ```sh
   tmux source ~/.tmux.conf
   ```
3. Press your tmux prefix (e.g., `Ctrl-Space` or `Ctrl-b`), then `Shift+I` (capital i) to install plugins interactively.

## Manual Plugin Installation (if interactive method fails)

If the interactive method does not work, you can manually install plugins by running:

```sh
cd ~/.tmux/plugins/tpm/scripts
./install_plugins.sh
```

This will install all plugins listed in your `.tmux.conf`.
