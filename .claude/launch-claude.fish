#!/usr/bin/env fish

# Helper to launch a ralph-loop session for a specific ticket/worktree.
# Note: This script should be edited per-ticket before use. It is not
# part of the general tmux bindings and should not contain merge markers.

set -l prompt "Fix ticket TASK: gmailclean\n\nGet Claude to build a script/agent to go through my inbox and unsubscribe to everything and have a system that centralises all of my emails and aligns everything, specifically my gmail\n\nInstructions:\n1. Work in this worktree (/Users/shahe/dotfiles-gmailclean)\n2. Understand the existing codebase first\n3. Implement the fix/feature\n4. Write tests if applicable\n5. Run tests to verify\n6. Create atomic commits with descriptive messages\n7. When complete, output TICKET_TASK_COMPLETE\n\nDo not ask questions - make reasonable decisions and iterate."

claude --dangerously-skip-permissions "/ralph-wiggum:ralph-loop \"$prompt\" --max-iterations 20 --completion-promise TICKET_TASK_COMPLETE"

# Optional: trigger post-completion actions (PR creation, ticket transition, notification)
# Only run manually after verifying completion to avoid side-effects.
# ~/dotfiles/scripts/ticket-complete.sh /Users/shahe/dotfiles-gmailclean
