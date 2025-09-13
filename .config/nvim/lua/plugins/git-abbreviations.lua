-- Git command abbreviations for Neovim command line
-- Similar to shell aliases but for Neovim's command mode

return {
  {
    "tpope/vim-fugitive",
    config = function()
      -- Define command abbreviations for Git commands
      -- These will auto-expand when typed in command mode
      
      -- Abbreviation for git -> Git (will work when you type :git<space>)
      vim.cmd("cnoreabbrev <expr> git (getcmdtype() == ':' && getcmdline() =~ '^git$') ? 'Git' : 'git'")
      
      -- Basic Git commands
      vim.cmd("cnoreabbrev ga Git add")
      vim.cmd("cnoreabbrev gaa Git add --all")
      vim.cmd("cnoreabbrev gap Git add --patch")
      vim.cmd("cnoreabbrev gau Git add --update")
      
      -- Commit commands
      vim.cmd("cnoreabbrev gc Git commit -m")
      vim.cmd("cnoreabbrev gca Git commit -v -a")
      vim.cmd("cnoreabbrev gcm Git commit -m")
      vim.cmd("cnoreabbrev gcam Git commit -a -m")
      vim.cmd("cnoreabbrev gcs Git commit -S")
      vim.cmd("cnoreabbrev gcsm Git commit -s -m")
      vim.cmd("cnoreabbrev gcmsg Git commit -m")
      vim.cmd("cnoreabbrev gcan! Git commit -v -a --no-edit --amend")
      vim.cmd("cnoreabbrev gcans! Git commit -v -a -s --no-edit --amend")
      
      -- Checkout/Switch commands
      vim.cmd("cnoreabbrev gco Git checkout")
      vim.cmd("cnoreabbrev gcb Git checkout -b")
      vim.cmd("cnoreabbrev gcm Git checkout master")
      vim.cmd("cnoreabbrev gcd Git checkout develop")
      vim.cmd("cnoreabbrev gsw Git switch")
      vim.cmd("cnoreabbrev gswc Git switch -c")
      vim.cmd("cnoreabbrev gswm Git switch master")
      
      -- Branch commands
      vim.cmd("cnoreabbrev gb Git branch")
      vim.cmd("cnoreabbrev gba Git branch -a")
      vim.cmd("cnoreabbrev gbd Git branch -d")
      vim.cmd("cnoreabbrev gbD Git branch -D")
      vim.cmd("cnoreabbrev gbr Git branch --remote")
      vim.cmd("cnoreabbrev gbnm Git branch --no-merged")
      vim.cmd("cnoreabbrev gbm Git branch -m")
      
      -- Diff commands
      vim.cmd("cnoreabbrev gd Git diff")
      vim.cmd("cnoreabbrev gds Git diff --staged")
      vim.cmd("cnoreabbrev gdca Git diff --cached")
      vim.cmd("cnoreabbrev gdcw Git diff --cached --word-diff")
      vim.cmd("cnoreabbrev gdct Git describe --tags")
      vim.cmd("cnoreabbrev gdt Git diff-tree --no-commit-id --name-only -r")
      vim.cmd("cnoreabbrev gdw Git diff --word-diff")
      
      -- Fetch commands
      vim.cmd("cnoreabbrev gf Git fetch")
      vim.cmd("cnoreabbrev gfa Git fetch --all --prune")
      vim.cmd("cnoreabbrev gfo Git fetch origin")
      
      -- Log commands
      vim.cmd("cnoreabbrev gl Git log")
      vim.cmd("cnoreabbrev gll Git pull")
      vim.cmd("cnoreabbrev glol Git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --abbrev-commit")
      vim.cmd("cnoreabbrev glola Git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset' --abbrev-commit --all")
      vim.cmd("cnoreabbrev glog Git log --oneline --decorate --graph")
      vim.cmd("cnoreabbrev gloga Git log --oneline --decorate --graph --all")
      vim.cmd("cnoreabbrev glg Git log --stat")
      vim.cmd("cnoreabbrev glgp Git log --stat -p")
      vim.cmd("cnoreabbrev glgg Git log --graph")
      vim.cmd("cnoreabbrev glgga Git log --graph --decorate --all")
      vim.cmd("cnoreabbrev glgm Git log --graph --max-count=10")
      vim.cmd("cnoreabbrev glo Git log --oneline --decorate")
      vim.cmd("cnoreabbrev gcount Git shortlog -sn")
      
      -- Merge commands
      vim.cmd("cnoreabbrev gm Git merge")
      vim.cmd("cnoreabbrev gma Git merge --abort")
      vim.cmd("cnoreabbrev gmom Git merge origin/master")
      vim.cmd("cnoreabbrev gmum Git merge upstream/master")
      
      -- Pull commands
      vim.cmd("cnoreabbrev gp Git push")
      vim.cmd("cnoreabbrev gpr Git pull --rebase")
      vim.cmd("cnoreabbrev gpu Git pull upstream")
      vim.cmd("cnoreabbrev gpv Git pull -v")
      vim.cmd("cnoreabbrev gpum Git pull upstream master")
      vim.cmd("cnoreabbrev gpom Git pull origin master")
      
      -- Push commands
      vim.cmd("cnoreabbrev gps Git push")
      vim.cmd("cnoreabbrev gpsup Git push --set-upstream origin")
      vim.cmd("cnoreabbrev gpsu Git push --set-upstream")
      vim.cmd("cnoreabbrev gpsf Git push --force-with-lease")
      vim.cmd("cnoreabbrev gpsf! Git push --force")
      vim.cmd("cnoreabbrev gpsd Git push --dry-run")
      vim.cmd("cnoreabbrev gpst Git push --tags")
      vim.cmd("cnoreabbrev gpoat Git push origin --all && git push origin --tags")
      
      -- Rebase commands
      vim.cmd("cnoreabbrev grb Git rebase")
      vim.cmd("cnoreabbrev grba Git rebase --abort")
      vim.cmd("cnoreabbrev grbc Git rebase --continue")
      vim.cmd("cnoreabbrev grbi Git rebase -i")
      vim.cmd("cnoreabbrev grbm Git rebase master")
      vim.cmd("cnoreabbrev grbs Git rebase --skip")
      
      -- Reset commands
      vim.cmd("cnoreabbrev grh Git reset")
      vim.cmd("cnoreabbrev grhh Git reset --hard")
      vim.cmd("cnoreabbrev groh Git reset origin/$(git_current_branch) --hard")
      vim.cmd("cnoreabbrev grm Git rm")
      vim.cmd("cnoreabbrev grmc Git rm --cached")
      
      -- Remote commands
      vim.cmd("cnoreabbrev gr Git remote")
      vim.cmd("cnoreabbrev gra Git remote add")
      vim.cmd("cnoreabbrev grv Git remote -v")
      vim.cmd("cnoreabbrev grrm Git remote remove")
      vim.cmd("cnoreabbrev grmv Git remote rename")
      vim.cmd("cnoreabbrev grset Git remote set-url")
      vim.cmd("cnoreabbrev grup Git remote update")
      
      -- Stash commands
      vim.cmd("cnoreabbrev gst Git status")
      vim.cmd("cnoreabbrev gss Git status -s")
      vim.cmd("cnoreabbrev gsta Git stash")
      vim.cmd("cnoreabbrev gstaa Git stash apply")
      vim.cmd("cnoreabbrev gstc Git stash clear")
      vim.cmd("cnoreabbrev gstd Git stash drop")
      vim.cmd("cnoreabbrev gstl Git stash list")
      vim.cmd("cnoreabbrev gstp Git stash pop")
      vim.cmd("cnoreabbrev gsts Git stash show --text")
      vim.cmd("cnoreabbrev gstu Git stash --include-untracked")
      vim.cmd("cnoreabbrev gstall Git stash --all")
      
      -- Show commands
      vim.cmd("cnoreabbrev gsh Git show")
      vim.cmd("cnoreabbrev gsps Git show --pretty=short --show-signature")
      
      -- Tag commands
      vim.cmd("cnoreabbrev gts Git tag -s")
      vim.cmd("cnoreabbrev gtv Git tag")  -- Removed sort -V as it causes issues in non-modifiable buffer
      vim.cmd("cnoreabbrev gtl Git tag -l")
      
      -- What changed commands
      vim.cmd("cnoreabbrev gwch Git whatchanged -p --abbrev-commit --pretty=medium")
      
      -- Clean commands
      vim.cmd("cnoreabbrev gclean Git clean -id")
      vim.cmd("cnoreabbrev gpristine Git reset --hard && git clean -dffx")
      
      -- Additional useful commands
      vim.cmd("cnoreabbrev gignore Git update-index --assume-unchanged")
      vim.cmd("cnoreabbrev gunignore Git update-index --no-assume-unchanged")
      -- vim.cmd("cnoreabbrev gignored Git ls-files -v | grep '^[[:lower:]]'") -- Commented out due to grep issues
      
      -- Cherry-pick commands
      vim.cmd("cnoreabbrev gcp Git cherry-pick")
      vim.cmd("cnoreabbrev gcpa Git cherry-pick --abort")
      vim.cmd("cnoreabbrev gcpc Git cherry-pick --continue")
      
      -- Bisect commands
      vim.cmd("cnoreabbrev gbs Git bisect")
      vim.cmd("cnoreabbrev gbsb Git bisect bad")
      vim.cmd("cnoreabbrev gbsg Git bisect good")
      vim.cmd("cnoreabbrev gbsr Git bisect reset")
      vim.cmd("cnoreabbrev gbss Git bisect start")
      
      -- Work in progress commit (simplified to avoid shell command issues)
      -- vim.cmd("cnoreabbrev gwip Git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign -m '--wip-- [skip ci]'")
      -- vim.cmd("cnoreabbrev gunwip Git log -n 1 | grep -q -c '--wip--' && git reset HEAD~1")
    end,
  },
}