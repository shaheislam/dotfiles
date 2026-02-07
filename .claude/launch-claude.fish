#!/usr/bin/env fish
set -l prompt Fix\ ticket\ TASK:\ self-host-llm\n\nSelf\ hosting\ local\ LLMs\ as\ a\ mitigation\ if\ we\ were\ to\ lose\ claude\ /\ codex?\ Imagine\ these\ models\ went\ down\ and\ we\ wanted\ to\ use\ something\ locally\n\nInstructions:\n1.\ Work\ in\ this\ worktree\ \(/Users/shahe/dotfiles-selfhostllm\)\n2.\ Understand\ the\ existing\ codebase\ first\n3.\ Implement\ the\ fix/feature\n4.\ Write\ tests\ if\ applicable\n5.\ Run\ tests\ to\ verify\n6.\ Create\ atomic\ commits\ with\ descriptive\ messages\n7.\ When\ complete,\ output\ TICKET_TASK_COMPLETE\n\nDo\ not\ ask\ questions\ -\ make\ reasonable\ decisions\ and\ iterate.

claude --dangerously-skip-permissions "/ralph-wiggum:ralph-loop \"$prompt\" --max-iterations 20 --completion-promise TICKET_TASK_COMPLETE"

# Auto-trigger post-completion (PR creation, ticket transition, notification)
~/dotfiles/scripts/ticket-complete.sh /Users/shahe/dotfiles-selfhostllm
