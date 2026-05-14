# Bero-OS brand prompt - two-cursor operator marker
__bero_prompt() {
  local R='\[\e[38;2;200;16;46m\]'
  local P='\[\e[38;2;233;220;193m\]'
  local M='\[\e[38;2;122;116;104m\]'
  local X='\[\e[0m\]'
  PS1="${R}▮${X} ${P}\u${M}@${P}\h ${M}\w${X} ${R}❯${X} "
}
PROMPT_COMMAND=__bero_prompt
