#!/usr/bin/env fish
set -l prompt Fix\ ticket\ TASK:\ rmgitrm\n\nmake\ rm\ commands\ have\ parity\ with\ git\ rm,\ so\ that\ when\ i\ press\ rm\ \<TAB\>\ it\ shows\ the\ same\ as\ git\ rm\ \<TAB\>\n\nInstructions:\n1.\ Work\ in\ this\ worktree\ \(/Users/shahe/dotfiles-rmgitrm\)\n2.\ Understand\ the\ existing\ codebase\ first\n3.\ Implement\ the\ fix/feature\n4.\ Write\ tests\ if\ applicable\n5.\ Run\ tests\ to\ verify\n6.\ Create\ atomic\ commits\ with\ descriptive\ messages\n7.\ When\ complete,\ output\ TICKET_TASK_COMPLETE\n\nDo\ not\ ask\ questions\ -\ make\ reasonable\ decisions\ and\ iterate.

claude --dangerously-skip-permissions "/ralph-wiggum:ralph-loop \"$prompt\" --max-iterations 20 --completion-promise TICKET_TASK_COMPLETE"
