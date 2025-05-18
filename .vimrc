syntax on        " Enable syntax highlighting
set number       " Show line numbers
set incsearch

" Necessary for cut operations from cutlass to be included in yank history
let g:yoinkIncludeDeleteOperations = 1
" Optional to enable indent on startup toggle to enable
let g:indent_guides_enable_on_vim_startup = 0 

" vim-cutlass using 'x' for cut (Separate cut and delete)
nnoremap x d
xnoremap x d
nnoremap xx dd
nnoremap X D

" vim-yoink mappings
" paste mappings (allow cycle through functionality)			\
nmap p <plug>(YoinkPaste_p)
nmap P <plug>(YoinkPaste_P)

" cycle mappings to cycle through yanks
nmap <c-n> <plug>(YoinkPostPasteSwapBack)
nmap <c-p> <plug>(YoinkPostPasteSwapForward)

" vim-subversive mappings
" Basic substitution operator (replacing text with current yank)
nmap s <plug>(SubversiveSubstitute)
nmap ss <plug>(SubversiveSubstituteLine)
nmap S <plug>(SubversiveSubstituteToEndOfLine)

" Range substitution (replacing one text with another across a range)
nmap <leader>s <plug>(SubversiveSubstituteRange)
xmap <leader>s <plug>(SubversiveSubstituteRange)
nmap <leader>ss <plug>(SubversiveSubstituteWordRange)

autocmd BufRead,BufNewFile *.tf set filetype=terraform

" Plugins
call plug#begin()
Plug 'ap/vim-css-color'
Plug 'hashivim/vim-terraform'
Plug 'junegunn/rainbow_parentheses.vim'
Plug 'michaeljsmith/vim-indent-object'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'psliwka/vim-smoothie'
Plug 'tpope/vim-abolish'
Plug 'tpope/vim-sleuth'
Plug 'tpope/vim-surround'

" Undo tree visualiser
Plug 'simnalamburt/vim-mundo'

" FZF for Vim
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" Allows traversing motions without numbers easier.
Plug 'easymotion/vim-easymotion'

" Allows unix readline commands in vim
Plug 'tpope/vim-rsi'

" Register sidebar '@ or "'
Plug 'junegunn/vim-peekaboo'

" Auto close brackets
Plug 'jiangmiao/auto-pairs'

" Use gs after indenting a block to sort (Useful for Terraform variables)
Plug 'christoomey/vim-sort-motion'

" Using Vim-EasyClip
Plug 'svermeulen/vim-cutlass'    " Separates delete and cut functionality
Plug 'svermeulen/vim-yoink'      " Maintains a yank history
Plug 'svermeulen/vim-subversive' " Provides substitute operator functionality

" Required dependency
Plug 'inkarkat/vim-ingo-library'

" The main plugin (depends on ReplaceWithRegister)
Plug 'inkarkat/vim-ReplaceWithRegister'
Plug 'inkarkat/vim-ReplaceWithSameIndentRegister'

" Optional dependencies for enhanced functionality
Plug 'tpope/vim-repeat'
Plug 'inkarkat/vim-visualrepeat'
call plug#end()

" Macros
let @f = "0cwfixup\<Esc>j"

