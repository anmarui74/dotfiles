syntax on

set title
set mouse=a
set noerrorbells
set sw=2
set expandtab
set smartindent
set number
set rnu
set numberwidth=1
"set nowrap
set wrap
set noswapfile
set nobackup
set incsearch
set ignorecase
set clipboard=unnamedplus
set encoding=utf-8
set cursorline
set termguicolors
set splitbelow
set splitright
set showcmd
set showmatch
syntax enable




call plug#begin('~/.local/share/nvim/plugged')


" Themes
Plug 'morhetz/gruvbox'
Plug 'ayu-theme/ayu-vim'
Plug 'joshdick/onedark.vim'

" Status Bar
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" Tree
Plug 'preservim/nerdtree'
Plug 'ryanoasis/vim-devicons'

" Plugin
Plug 'lilydjwg/colorizer'
Plug 'yggdroot/indentline'

" Tmux
Plug 'christoomey/vim-tmux-navigator'

" Typing
Plug 'jiangmiao/auto-pairs'

" Syntax
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'vim-python/python-syntax'
Plug 'rust-lang/rust.vim'
Plug 'sheerun/vim-polyglot'

" Indent Blankline
Plug 'lukas-reineke/indent-blankline.nvim'


call plug#end()




" Themes
set background=dark
let asucolor="mirage"
let g:ggrubbox_contrast_dark="hard"
colorscheme onedark

" Airline
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#left_sep = ' '
let g:airline#extensions#tabline#left_alt_sep = '|'
let g:airline#extensions#tabline#formatter = 'default'

" Añadir banderas a NERDTree
let g:webdevicons_enable_nerdtree = 1

" Vim devicons
if exists("g:loaded_webdevicons")
  call webdevicons#refresh()
endif




" Mappings

" Definir espacio como tecla líder
let mapleader = ' '

" Guardar con <líder> + w
nnoremap w :w<CR> 

" Cerrar con <líder> + q
nnoremap q :q<CR> 

" Abrir el archivo init.vim con <líder> +e
nnoremap <leader>e :e $MYVIMRC<CR>   

" Redimensionar ventanas
nnoremap <leader><right> :vertical resize +5<CR>
nnoremap <leader><left> :vertical resize -5<CR>
nnoremap <leader><up> :resize +5<CR>
nnoremap <leader><down> :resize -5<CR>

" Terminar la busqueda
nnoremap <leader>b :nohlsearch<CR>

" Moverse al buffer siguiente con <líder> + k
nnoremap <leader>k :bnext<CR>

" Moverse al buffer anterior con <líder> + j
nnoremap <leader>j :bprevious<CR>

" Cerrar el buffer actual con <líder> + q
nnoremap <leader>q :bdelete<CR>

" Crear una ventana nueva con <líder> + t
nnoremap <leader>t :tabe<CR>

" Hacer un split vertical con <líder> + vs
nnoremap <leader>vs :vsp<CR>

" Hacer un split horizontal con <líder> + sp
nnoremap <leader>sp :sp<CR>

" Para copiar al porta papeles con <líder> + y
vnoremap <leader>y "+y
nnoremap <leader>y "+y

" Para cortar al porta papeles con <líder> + d
vnoremap <leader>d "+d
nnoremap <leader>d "+d

" Para pegar desde el porta papeles con <líder> + p
nnoremap <leader>p "+p
vnoremap <leader>p "+p
nnoremap <leader>P "+P
vnoremap <leader>P "+P

" Abrir NERDTree <líder> + n
nnoremap <leader>n :NERDTreeToggle<CR>

" Split de terminal <c-t>
vnoremap <c-t> :split<CR>:ter<CR>:resize 15<CR>
nnoremap <c-t> :split<CR>:ter<CR>:resize 15<CR>

" Diccionario para NeoVim
:setlocal spell spelllang=es
:set nospell
nnoremap <leader>a :set spell<CR>
nnoremap <leader>aa :set nospell<CR>

