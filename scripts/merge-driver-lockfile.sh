#!/usr/bin/env bash
#
# merge-driver-lockfile.sh - "Ours" merge driver for lockfiles
#
# Keeps the current branch's version of lockfiles during merge.
# Lockfiles like lazy-lock.json are auto-generated and should be
# regenerated after merge rather than manually resolved.
#
# Registered via .gitattributes:
#   .config/nvim/lazy-lock.json merge=lockfile
#
# Git config (set by setup.sh):
#   [merge "lockfile"]
#       name = Keep ours for lockfiles
#       driver = scripts/merge-driver-lockfile.sh %A %O %B %L %P
#
# Parameters (from git):
#   $1 = %A = ours (current branch, result written here)
#   $2-$5 = unused (ours is already in %A)
#
# Exit codes:
#   0 - Always succeeds (keeps ours as-is)

# %A already contains our version, and git writes the result from %A.
# By doing nothing, we keep ours.
exit 0
