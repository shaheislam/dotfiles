---
name: unfreeze
description: Remove the /freeze directory restriction, allowing edits to any file again
---

# Unfreeze

Remove the directory lock set by /freeze or /guard.

## Behavior

When invoked:

1. If freeze mode is active: deactivate it and confirm:
   ```
   Freeze mode deactivated. File edits are no longer restricted.
   ```
   If /guard was active, note that careful mode remains:
   ```
   Freeze mode deactivated. Careful mode is still active (destructive command warnings).
   ```

2. If freeze mode is NOT active:
   ```
   No freeze is active. File edits are already unrestricted.
   ```
