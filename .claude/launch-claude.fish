#!/usr/bin/env fish
set -l prompt Fix\ ticket\ TASK:\ gitcheckout\n\nWhen\ I\ do\ git\ checkout\ origin,\ and\ then\ I\ want\ the\ auto-complete\ to\ be\ the\ branch\ that\ I\'m\ already\ on\ by\ default.\n\nInstructions:\n1.\ Work\ in\ this\ worktree\ \(/Users/shahe/dotfiles-gitcheckout\)\n2.\ Understand\ the\ existing\ codebase\ first\n3.\ Implement\ the\ fix/feature\n4.\ Write\ tests\ if\ applicable\n5.\ Run\ tests\ to\ verify\n6.\ Create\ atomic\ commits\ with\ descriptive\ messages\n7.\ When\ complete,\ output\ TICKET_TASK_COMPLETE\n\nDo\ not\ ask\ questions\ -\ make\ reasonable\ decisions\ and\ iterate.

claude --dangerously-skip-permissions "/ralph-wiggum:ralph-loop \"$prompt\" --max-iterations 20 --completion-promise TICKET_TASK_COMPLETE"
