#!/bin/bash

# Create plugins directory if it doesn't exist
mkdir -p ~/.tmux/plugins

# Clone each plugin
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
git clone https://github.com/tmux-plugins/tmux-sensible ~/.tmux/plugins/tmux-sensible
git clone https://github.com/tmux-plugins/tmux-resurrect ~/.tmux/plugins/tmux-resurrect
git clone https://github.com/tmux-plugins/tmux-continuum ~/.tmux/plugins/tmux-continuum
git clone https://github.com/tmux-plugins/tmux-yank ~/.tmux/plugins/tmux-yank
git clone https://github.com/tmux-plugins/tmux-prefix-highlight ~/.tmux/plugins/tmux-prefix-highlight
git clone https://github.com/folke/tmux-which-key ~/.tmux/plugins/tmux-which-key
git clone https://github.com/tmux-plugins/tmux-open ~/.tmux/plugins/tmux-open
git clone https://github.com/tmux-plugins/tmux-copycat ~/.tmux/plugins/tmux-copycat
git clone https://github.com/tmux-plugins/tmux-pain-control ~/.tmux/plugins/tmux-pain-control
git clone https://github.com/tmux-plugins/tmux-sidebar ~/.tmux/plugins/tmux-sidebar
git clone https://github.com/Morantron/tmux-fingers ~/.tmux/plugins/tmux-fingers
git clone https://github.com/tmux-plugins/tmux-battery ~/.tmux/plugins/tmux-battery

echo "All plugins have been installed!"
echo "Now run: tmux source ~/.tmux.conf"
