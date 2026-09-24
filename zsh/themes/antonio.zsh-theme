# Antonio

PROMPT=$'%{$fg_bold[black]%}
%{$bg[cyan]%} %D{%H:%M:%S} 
%{$bg[green]%} %n@%m % %{$bg[blue]%} %~%{$(git_prompt_info)%} %{$reset_color%}

'
PS2=$' %{$reset_color%} '

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[black]%} %{$bg[magenta]%} %{$fg[black]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX=""
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}⚡% %{$fg[black]%}"
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}✗% %{$fg[black]%}"
ZSH_THEME_GIT_PROMPT_CLEAN=" %{$fg[green]%}✔% %{$fg[black]%}"
