#!/usr/bin/env fish
<<<<<<< HEAD
<<<<<<< HEAD
<<<<<<< HEAD
set -l prompt Fix\ ticket\ TASK:\ diffview-split\n\nmodify\ the\ default\ view\ when\ gwtt\ /\ gwt-ticket\ runs\ \(and\ any\ other\ gwt\ function\ so\ that\ instead\ of\ a\ two\ split\ with\ the\ terminal\ and\ claude\ code\ there\ is\ claude\ code\ on\ one\ side\ and\ then\ there\ is\ a\ horizontal\ split\ on\ the\ other\ side\ with\ ther\ terminal\ at\ the\ bottom\ and\ the\ diffview\ \<leader\>gP\ at\ the\ top\)\n\nInstructions:\n1.\ Work\ in\ this\ worktree\ \(/Users/shahe/dotfiles-diffviewsplit\)\n2.\ Understand\ the\ existing\ codebase\ first\n3.\ Implement\ the\ fix/feature\n4.\ Write\ tests\ if\ applicable\n5.\ Run\ tests\ to\ verify\n6.\ Create\ atomic\ commits\ with\ descriptive\ messages\n7.\ When\ complete,\ output\ TICKET_TASK_COMPLETE\n\nDo\ not\ ask\ questions\ -\ make\ reasonable\ decisions\ and\ iterate.
||||||| c6b065e
=======
set -l prompt Fix\ ticket\ TASK:\ rmgitrm\n\nmake\ rm\ commands\ have\ parity\ with\ git\ rm,\ so\ that\ when\ i\ press\ rm\ \<TAB\>\ it\ shows\ the\ same\ as\ git\ rm\ \<TAB\>\n\nInstructions:\n1.\ Work\ in\ this\ worktree\ \(/Users/shahe/dotfiles-rmgitrm\)\n2.\ Understand\ the\ existing\ codebase\ first\n3.\ Implement\ the\ fix/feature\n4.\ Write\ tests\ if\ applicable\n5.\ Run\ tests\ to\ verify\n6.\ Create\ atomic\ commits\ with\ descriptive\ messages\n7.\ When\ complete,\ output\ TICKET_TASK_COMPLETE\n\nDo\ not\ ask\ questions\ -\ make\ reasonable\ decisions\ and\ iterate.
>>>>>>> rmgitrm
||||||| c6b065e
=======
set -l prompt Fix\ ticket\ TASK:\ gitcheckout\n\nWhen\ I\ do\ git\ checkout\ origin,\ and\ then\ I\ want\ the\ auto-complete\ to\ be\ the\ branch\ that\ I\'m\ already\ on\ by\ default.\n\nInstructions:\n1.\ Work\ in\ this\ worktree\ \(/Users/shahe/dotfiles-gitcheckout\)\n2.\ Understand\ the\ existing\ codebase\ first\n3.\ Implement\ the\ fix/feature\n4.\ Write\ tests\ if\ applicable\n5.\ Run\ tests\ to\ verify\n6.\ Create\ atomic\ commits\ with\ descriptive\ messages\n7.\ When\ complete,\ output\ TICKET_TASK_COMPLETE\n\nDo\ not\ ask\ questions\ -\ make\ reasonable\ decisions\ and\ iterate.
>>>>>>> gitcheckout
||||||| c6b065e
=======
set -l prompt Fix\ ticket\ TASK:\ gitworktree-dhh\n\nInspect\ these\ git\ worktrees\ from\ DHH\ and\ tell\ me\ if\ we\ can\ optimise\ our\ own\ setup\ based\ on\ it\ or\ if\ ours\ is\ more\ comprehensive\ https://gist.github.com/dhh/18575558fc5ee10f15b6cd3e108ed844\n\nInstructions:\n1.\ Work\ in\ this\ worktree\ \(/Users/shahe/dotfiles-gitworktreedhh\)\n2.\ Understand\ the\ existing\ codebase\ first\n3.\ Implement\ the\ fix/feature\n4.\ Write\ tests\ if\ applicable\n5.\ Run\ tests\ to\ verify\n6.\ Create\ atomic\ commits\ with\ descriptive\ messages\n7.\ When\ complete,\ output\ TICKET_TASK_COMPLETE\n\nDo\ not\ ask\ questions\ -\ make\ reasonable\ decisions\ and\ iterate.
>>>>>>> gitworktreedhh

claude --dangerously-skip-permissions "/ralph-wiggum:ralph-loop \"$prompt\" --max-iterations 20 --completion-promise TICKET_TASK_COMPLETE"
