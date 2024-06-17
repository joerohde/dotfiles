# Personal Zsh configuration file. It is strongly recommended to keep all
# shell customization and configuration (including exported environment
# variables such as PATH) in this file or in files sourced from it.
#
# Documentation: https://github.com/romkatv/zsh4humans/blob/v5/README.md.

# Periodic auto-update on Zsh startup: 'ask' or 'no'.
# You can manually run `z4h update` to update everything.
zstyle ':z4h:' auto-update 'no'
# Ask whether to auto-update this often; has no effect if auto-update is 'no'.
zstyle ':z4h:' auto-update-days '28'

# Keyboard type: 'mac' or 'pc'.
zstyle ':z4h:bindkey' keyboard 'pc'

# Do start tmux. (Turn off if things get weird)
zstyle ':z4h:' start-tmux 'no'

# Mark up shell's output with semantic information.
zstyle ':z4h:' term-shell-integration 'yes'

# Right-arrow key accepts one character ('partial-accept') from
# command autosuggestions or the whole thing ('accept')?
zstyle ':z4h:autosuggestions' forward-char 'accept'

# Recursively traverse directories when TAB-completing files.
zstyle ':z4h:fzf-complete' recurse-dirs 'no'

# use 'tab' to accept
# zstyle ':z4h:*' fzf-flags --bind 'tab:accept'

# Enable direnv to automatically source .envrc files.
zstyle ':z4h:direnv' enable 'no'
# Show "loading" and "unloading" notifications from direnv.
zstyle ':z4h:direnv:success' notify 'yes'

# Enable ('yes') or disable ('no') automatic teleportation of z4h over
# SSH when connecting to these hosts.
#zstyle ':z4h:ssh:example-hostname1' enable 'yes'
#zstyle ':z4h:ssh:*.example-hostname2' enable 'no'
# The default value if none of the overrides above match the hostname.
zstyle ':z4h:ssh:*' enable 'yes'
zstyle ':z4h:ssh:joe-win*' enable no
zstyle ':z4h:ssh:homeserver*' enable no
zstyle ':z4h:ssh:homeserver*' enable no
zstyle ':z4h:ssh:gram-2023*' enable no

# Send these files over to the remote host when connecting over SSH to the
# enabled hosts.
#zstyle ':z4h:ssh:*' send-extra-files '~/.nanorc' '~/.env.zsh'

# Clone additional Git repositories from GitHub.
#
# This doesn't do anything apart from cloning the repository and keeping it
# up-to-date. Cloned files can be used after `z4h init`. This is just an
# example. If you don't plan to use Oh My Zsh, delete this line.
z4h install ohmyzsh/ohmyzsh || return
z4h install lukechilds/zsh-nvm || return

# Install or update core components (fzf, zsh-autosuggestions, etc.) and
# initialize Zsh. After this point console I/O is unavailable until Zsh
# is fully initialized. Everything that requires user interaction or can
# perform network I/O must be done above. Everything else is best done below.
z4h init || return

# Export environment variables.
export GPG_TTY=$TTY

# Source additional local files if they exist.
z4h source ~/.env.zsh

# Use additional Git repositories pulled in with `z4h install`.
#
# This is just an example that you should delete. It does nothing useful.
# z4h source ohmyzsh/ohmyzsh/lib/diagnostics.zsh  # source an individual file
z4h load $Z4H/ohmyzsh/ohmyzsh/plugins/aws

export NVM_LAZY_LOAD=true
export NVM_AUTO_USE=true
export NVM_COMPLETION=true
z4h load lukechilds/zsh-nvm

# Define key bindings.
z4h bindkey z4h-backward-kill-word Ctrl+Backspace Ctrl+H
z4h bindkey z4h-backward-kill-zword Ctrl+Alt+Backspace

z4h bindkey undo Ctrl+/ Shift+Tab Ctrl+Z # undo the last command line change
z4h bindkey redo Alt+/                   # redo the last undone command line change

z4h bindkey z4h-cd-back Alt+Left     # cd into the previous directory
z4h bindkey z4h-cd-forward Alt+Right # cd into the next directory
z4h bindkey z4h-cd-up Alt+Up         # cd into the parent directory
z4h bindkey z4h-cd-down Alt+Down     # cd into a child directory

# make instant-prompt play nice with ssh exit hotkey
z4h bindkey z4h-eof Ctrl+D
setopt ignore_eof

# pre-scroll the terminal so 2nd line of prompt doesn't cause a 2nd scroll
POSTEDIT=$'\n\e[A'

# z4h bindkey doesn't do shift casing name parse (Alt+z vs Alt+Z)
bindkey '^[z' undo
bindkey '^[Z' redo

# stop accidentally doing 'quoted-insert'
bindkey -r '^v'             # stop the mysterious raw char quoting
bindkey '^Xv' quoted-insert # map it to unused ^X v

bindkey '^ ' end-of-line
bindkey '^U' backward-kill-line
bindkey '^[^[' kill-whole-line

# del on end of line drops suggestion
# this is done so 'enter' can accept suggestion
# automatically if it's there
function my-delete-char() {
    if [[ $CURSOR == ${#BUFFER} ]]; then
        zle autosuggest-clear
    else
        ${WRAPPED}
    fi
}

# hitting enter when there is a suggestion and the wuggestion
# does not start with a space, just autocomplete the line.
# function my-accept-line() {
#     if ([[ -n ${POSTDISPLAY} ]] && [[ ${POSTDISPLAY:0:1} != ' ' ]]); then
#         zle end-of-line
#         # both to keep typing and to force a redraw to colorize
#         zle -U ' '
#     else
#         ${WRAPPED}
#     fi
# }

function my-backward-kill-word() {
    ${WRAPPED}
    zle autosuggest-clear
}
function my-backward-delete-char() {
    ${WRAPPED}
    zle autosuggest-clear
}
# TODO
#  - Make ctrl-space do z4h-fzf-complete
#  - Make tab/^I a new function that:
#    invokes z4h-fzf-complete when no autosuggest, or cursor on whitespace.
#    and does partial-accept if there is autosuggest

# only works mapped to builtin's using the '.' syntax
function restore-autosuggest() {
    if [[ $CURSOR == ${#BUFFER} ]] && [[ -z ${POSTDISPLAY} ]]; then
        # zle autosuggest-fetch or anything like it doesn't work.
        # z4h's overriddes know there's no current suggestion and don't
        # reset enough on 'clear' - so they short circuit the fetch/suggest.
        # So call autosuggests direct fn().  Slower, but more 'documented' work
        # around would be to toggle twice. :/
        _zsh_autosuggest_fetch
        #zle autosuggest-toggle
        #zle autosuggest-toggle
    fi
    ${WRAPPED}
}

function my-tab-completion() {
    # if we want any special overridden tab completion, it can go here.
    ${WRAPPED}
}

function my-space-completion() {
    if [[ -n ${POSTDISPLAY} ]] && [[ ${POSTDISPLAY:0:1} != ' ' ]]; then
        zle z4h-forward-word
    else
        zle -U ' '
    fi
}
zle -N my-space-completion
bindkey '^@' my-space-completion

# allows wrapping user widgets and not just builtins.  Provides a dynamic scoped variable
# 'WRAPPED' to the replacement function that can be used to call the orginal backing function/builtin.
function wrap-widget() {
    readonly wrapped_widget=${1:?"widget to wrap be specified."}
    readonly wrapper=${2:?"function wrapping be specified."}
    local wrapped=${widgets[$wrapped_widget]}

    if [[ ${wrapped} =~ "user:*" ]] && [[ ${wrapped} != "user:${wrapper}" ]]; then
        wrapped="${wrapped#"user:"}"
    elif [[ ${wrapped} == "builtin" ]]; then
        eval "_my_wrapped-builtin-${wrapped_widget}() { zle .${wrapped_widget} }"
        wrapped="_my_wrapped-builtin-${wrapped_widget}"
    else
        return
    fi

    if [[ -n ${wrapped} ]]; then
        eval "_my_wrapped-${wrapped_widget}() {
            local WRAPPED=${wrapped}
            ${wrapper}
        }"
        zle -N ${wrapped_widget} _my_wrapped-${wrapped_widget}
    fi
}

# wrap-widget accept-line my-accept-line
wrap-widget delete-char my-delete-char
wrap-widget backward-delete-char my-backward-delete-char
wrap-widget z4h-backward-kill-word my-backward-kill-word
wrap-widget forward-char restore-autosuggest
wrap-widget forward-word restore-autosuggest
wrap-widget end-of-line restore-autosuggest
wrap-widget z4h-forward-zword restore-autosuggest
wrap-widget z4h-fzf-complete my-tab-completion

# Autoload functions.
# autoload -Uz zmv

[[ -r "$HOME/.env" ]] && . "$HOME/.env"

# Define functions and completions.
function md() {
    [[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1"
}
compdef _directories md

# Define named directories: ~w <=> Windows home directory on WSL.
[[ -z $z4h_win_home ]] || hash -d w=$z4h_win_home

# Define aliases.
alias tree='tree -a -I .git'
command -v lsd >/dev/null && alias ls="lsd"

function path_remove() { export PATH=$(echo -n $PATH | awk -v RS=: -v ORS=: '$0 != "'$1'"' | sed 's/:$//'); }
function prepend_path() {
    path_remove "$2"
    if [[ -d "$2" ]]; then
        eval "export $1=$2:\$$1"
    fi
}
function append_path() {
    path_remove "$2"
    if [[ -d "$2" ]]; then
        eval "export $1=\$$1:$2"
    fi
}

# These sourced files are bash and zsh compat. No need to emulate in zsh
[[ -r "$HOME/.aliases" ]] && . "$HOME/.aliases"
[[ -r "$HOME/.functions" ]] && . "$HOME/.functions"
[[ -r "$HOME/.bashrc.local" ]] && . "$HOME/.bashrc.local"

# Add flags to existing aliases.
alias ls="${aliases[ls]:-ls} --color=always -A"
alias dir="${aliases[ls]} -l"

# Set shell options: http://zsh.sourceforge.net/Doc/Release/Options.html.
setopt glob_dots    # no special treatment for file names with a leading dot
setopt no_auto_menu # require an extra TAB press to open the completion menu
setopt nonomatch    # frowned upon, but handy for interactive

if type brew &>/dev/null; then
    FPATH=$(brew --prefix)/share/zsh-completions:$FPATH

    autoload -Uz compinit
    compinit
fi

compdef _env goos
compdef _golang god
