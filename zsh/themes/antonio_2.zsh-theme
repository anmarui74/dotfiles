# Antonio 2

PROMPT=$'%{$fg[red]%}
╭%{$fg[red]%}[%{$fg[cyan]%}%D{%H:%M:%S}%{$fg[red]%}] [%{$fg_bold[green]%}%n@%m%{$reset_color%}%{$fg[red]%}] %{$(git_prompt_info)%}%(?,,%{$fg[red]%}[%{$fg_bold[blue]%}%?%{$reset_color%}%{$fg[red]%}])
%{$fg[red]%}╰[%{$fg_bold[cyan]%}%~%{$reset_color%}%{$fg[red]%}] ▷%{$reset_color%} '
PS2=$' %{$fg[red]%}|>%{$reset_color%} '

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[red]%}[%{$fg_bold[magenta]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}%{$fg[red]%}] "
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}⚡%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}✗%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=" %{$fg[green]%}✔%{$reset_color%}"
