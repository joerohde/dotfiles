# color-ls initialization

#when USER_LS_COLORS defined do not override user LS_COLORS, but use them.
if [ -z "$USER_LS_COLORS" ]; then
  alias ll='ls -l' 2>/dev/null
  alias l.='ls -d .*' 2>/dev/null


  # Skip the rest for noninteractive shells.
  [ -z "$PS1" ] && return

  COLORS=
  for colors in "$HOME/.dir_colors.$TERM" "$HOME/.dircolors.$TERM" \
      "$HOME/.dir_colors" "$HOME/.dircolors"; do
    [ -e "$colors" ] && COLORS="$colors" && break
  done

  [ -z "$COLORS" ] && [ -e "$HOME/.local/etc/DIR_COLORS.256color" ] && \
      [ "$(tput colors 2>/dev/null)" = "256" ] && \
      COLORS="$HOME/.local/etc/DIR_COLORS.256color"

  if [ -z "$COLORS" ]; then
    for colors in "$HOME/.local/etc/DIR_COLORS.$TERM" "$HOME/.local/etc/DIR_COLORS" ; do
      [ -e "$colors" ] && COLORS="$colors" && break
    done
  fi

  # Existence of $COLORS already checked above.
  [ -n "$COLORS" ] || return

  eval "$(dircolors --sh "$COLORS" 2>/dev/null)"
  [ -z "$LS_COLORS" ] && return
  grep -Eqi "^COLOR.*none" "$COLORS" >/dev/null 2>/dev/null && return
fi

color=always

LS="ls"
if hash gls 2>/dev/null; then
        LS="gls"
fi

alias ll="$LS -l --color=$color" 2>/dev/null
alias l.="$LS -d .* --color=$color" 2>/dev/null
alias ls="$LS --color=$color" 2>/dev/null
alias gls="$LS --color=$color" 2>/dev/null
alias grep="grep --color=$color" 2>/dev/null
alias fgrep="fgrep --color=$color" 2>/dev/null
alias egrep="egrep --color=$color" 2>/dev/null
