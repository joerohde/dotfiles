#!/bin/bash
### Uncomment the following section to profile bash startup.
### then run mergescriptprofile <pid> with the pid of the file generated in /tmp

#exec 3>&2 2> >( tee /tmp/sample-$$.log |
#                  sed -u 's/^.*$/now/' |
#                  date -f - +%s.%N >/tmp/sample-$$.tim)
#set -x
#set -o xtrace

export NVM_DIR="$HOME/.nvm"

MYHOST=${MYHOST:-$(hostname)}
MYHOST=${MYHOST%%.*}
MYUNAME=${MYUNAME:-$(uname)}
MYUNAME=${MYUNAME%%_*}

# If not running interactively, don't do anything elsem except hard init
# nvm.  Kind of sucks, but when vscode remote-ssh jumps in, it doesn't give
# any conditional context/options to know it's vscode - which will need nvm access
[[ $- == *i* ]] || [[ $TERM_PROGRAM == "vscode" ]] || { . "$NVM_DIR/nvm.sh"; return; }

[[ -n "${GREP_COLORS}" ]] || exec env bash -l

[ -s "$NVM_DIR/nvm.sh" ] && \. ~/.local/bin/lazynvm # This lazy loads nvm, not optional if nvm is installed


function path_remove() { export PATH=$(echo -n $PATH | awk -v RS=: -v ORS=: '$0 != "'$1'"' | sed 's/:$//'); }
function prepend_path() {
    path_remove "$2"
    eval "export $1=$2:\$$1"
}
function append_path() {
    path_remove "$2"
    eval "export $1=\$$1:$2"
}

# MacPorts Installer addition on 2009-12-15_at_20:30:37: adding an appropriate PATH/MANPATH variable for use with MacPorts.
# take out /opt/local/libexec/gnubin since it screws with HBO build's use of 'cp' Grrr!!! Probably need to use 'gcp' and such in my local scripts
[[ -d /opt/local/libexec ]] &&
    export PATH=/opt/local/libexec/gnubin:/opt/local/bin:/opt/local/sbin:$PATH

[[ -d /usr/local/opt ]] &&
    export PATH=/usr/local/opt/coreutils/libexec/gnubin:/usr/local/sbin:$PATH

[[ -d /usr/local/share/man ]] &&
    export MANPATH=/opt/local/share/man:$MANPATH

prepend_path PATH ~/.local/bin

[[ -n $SSH_CLIENT || -n $SSH_CONNECTION || -n $SSH_TTY ]] && isSSH=true

[[ -r ~/.aliases ]] && . ~/.aliases

[[ -r ~/.functions ]] && . ~/.functions

if [ ${SHLVL} -le 1 ]; then
    IGNOREEOF=16
fi

history -a

BOLD="\[\e[1m\]"
NOBOLD="\[\e[21m\]"
UNDERLINE="\[\e[4m\]"
NOUNDERLINE="\[\e[24m\]"
INVERT="\[\e[7m\]"
NOINVERT="\[\e[27m\]"
RED="\[\e[1;31m\]"
GREEN="\[\e[32;1m\]"
YELLOW="\[\e[93;1m\]"
BLUE="\[\e[94;1m\]"
MAGENTA="\[\e[95;1m\]"
CYAN="\[\e[96;1m\]"
OFF="\[\e[0m\]"

function _buildprompt() {
    EXITSTATUS="${__bp_last_ret_value:-$?}"
    local extdebug="$(shopt -p extdebug)"
    local trapdebug="$(trap -p DEBUG)"
    trap DEBUG
    shopt -u extdebug
    # NOTE: HACK: YUCK: Detecting iterm2 required tossing the terminal into raw
    # mode to not leave garbage on the screen for non-iterm2 terminals.  vscode
    # remote (especially when installing) seems to be 'feeding' the command into
    # the terminal as if it was a keyboard.  The stty to raw interacts poorly.
    # As such we do some deferred iterm2 detection outside startup, the 2nd time
    # we build the prompt.  Yeah... gross.
    if [[ -n "$TABCOLOR" ]] && [[ -z $isiTerm2  ]]; then
    	# echo "checking isIterm2..."
        if hash isiterm2.sh >& /dev/null && isiterm2.sh &&[[ -r ~/.iterm2_shell_integration.bash ]]; then
            . ~/.iterm2_shell_integration.bash
            isiTerm2=true
        else
            isiTerm2=false
        fi
    fi

    STAT=""
    SHLSTAT=""

    if [ "${EXITSTATUS}" -ne "0" ]; then
        STAT="${BOLD}${RED} [${EXITSTATUS}]${OFF}"
    fi

    if [ ${SHLVL} -gt 1 ]; then
        SHLSTAT="${BOLD}${YELLOW} (${SHLVL})${OFF}"
    fi

    RAWREPO="$(basename "$(git config --get remote.origin.url)" .git)"
    RAWBRANCH="$(command git branch --show-current 2>/dev/null)"

    RAWGITSTATUS="[${RAWREPO}/${RAWBRANCH}]"

    GITSTATUS="${GREEN}${RAWGITSTATUS}${OFF}"
    [[ $isiTerm2 == true ]] && iterm2_set_user_var gitBranch "$RAWGITSTATUS"

    TABCOLOR='\e]6;1;bg;*;default\a'
    local HOSTCOLOR=${CYAN}${MYHOST}${OFF}
    local UNAMECOLOR=${CYAN}${MYUNAME}${OFF}
    local ROOTCOLOR=${OFF}
    [[ $EUID -eq 0 ]] && ROOTCOLOR=${RED}
    if [[ $isSSH ]]; then
        HOSTCOLOR=${MAGENTA}${UNDERLINE}*${MYHOST}*${OFF}
        TABCOLOR='\e]6;1;bg;red;brightness;64\a\e]6;1;bg;green;brightness;64\a\e]6;1;bg;blue;brightness;96\a'
    fi
    echo -ne "${TABCOLOR}"

    TABTITLE="$PWD"
    [[ "${RAWGITSTATUS}" != "[/]" ]] && TABTITLE="${RAWGITSTATUS}"

    #xterm title; hostname; shell depth if > 0; date; exit code if non-zero, second line: cwd.
    PS1="\e]0;${TABTITLE}\a[${HOSTCOLOR}/${UNAMECOLOR}]:${ROOTCOLOR} \d, \T${OFF}${SHLSTAT}${STAT}\n$GITSTATUS\w/"
    PS2="${BOLD}>${OFF} "

    lazy_nvm_use_check

    eval "$extdebug"
    eval "$trapdebug"

    (exit "$EXITSTATUS")
}

export n=~

function lazy_nvm_use_check() {
    # finally - a better performing auto-use-nvm hack...
    # nvm is lazy loaded for startup perf. Don't check if it hasn't loaded yet.
    local LOADED_NVM
    LOADED_NVM=$(builtin type -t "nvm_find_nvmrc")

    # if there's a known nvm home directory, get it's current mod time to see if it changed
    [[ -f "$LKG_NVMRC" ]] && CURRENT_CHANGED=$(stat -c "%y" "$LKG_NVMRC")

    # if we changed directory, or the mod time changed, see if we need to do 'nvm use'
    if [[ -n "$LOADED_NVM" && ( "$PWD" != "$LKG_PWD" || "$CURRENT_CHANGED" != "$LKG_CHANGED"  ) ]]; then
        # find where nvm thinks the rc file is
        local CURRENT_NVMRC
        CURRENT_NVMRC=$(nvm_find_nvmrc)

        # we won't load it if it hasn't changed
        [[  "$CURRENT_NVMRC" != "$LKG_NVMRC" ]]
        local location_changed=$?

        [[ -z "$CURRENT_NVMRC" ]] && LKG_CHANGED=0

        # unless it was modified since the last check
        [[ -n "$CURRENT_CHANGED" && "$CURRENT_CHANGED" != "$LKG_CHANGED" ]]
        local lastchanged_changed=$?

        if [[ -n "$CURRENT_NVMRC" && ($location_changed == 0 || $lastchanged_changed == 0) ]]; then
            # ok, we probably have to load it. Final check, see if the .nvmrc we are
            # about to load has a strong match to what is already loaded.
            read -r local_version <"$CURRENT_NVMRC"
            if [[ $(nvm_ls_current) != "$local_version" && $(nvm_ls_current) != "v$local_version" ]]; then
                nvm use
                source "$NVM_BIN/../lib/node_modules/npm/lib/utils/completion.sh"
                if [[ "$CURRENT_NVMRC" != "$LKG_NVMRC" ]]; then
                    echo "Setting \$n to '${CURRENT_NVMRC%/*}'"
                    n="${CURRENT_NVMRC%/*}"
                fi
            fi
            LKG_NVMRC="$CURRENT_NVMRC"
            LKG_CHANGED=$(stat -c "%y" "$CURRENT_NVMRC")
        fi
        LKG_PWD="$PWD"
    fi
}

#function try_it { echo `echo -n $PATH | awk -v RS=: -v ORS=: '$0 != "'$1'"' | sed 's/:$//'`; }

[[ -r ${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh ]] && . ${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh
[[ -r ${HOMEBREW_PREFIX}/etc/profile.d/cdargs-bash.sh ]] && . ${HOMEBREW_PREFIX}/etc/profile.d/cdargs-bash.sh
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

if [ -n "$PS1" ]; then
    shopt -s autocd cdspell cmdhist direxpand dirspell globstar histappend histreedit nocaseglob no_empty_cmd_completion
    export HISTFILESIZE=1024
    export HISTCONTROL=ignoreboth
    export HISTIGNORE="dir;ls:bg:fg:history:.:..:cd .."

    if [[ $TERM == 'dumb' ]]; then
        PS1='\d, \T\n\w/'
    else
        PROMPT_COMMAND=_buildprompt
    fi

    # [ -z "$TMUX" ] && tmux -u -2
fi

[[ -r "$HOME/.bashrc.local" ]] && . "$HOME/.bashrc.local"
[[ -r "$HOME/.local/bin/cd.sh" ]] && . "$HOME/.local/bin/cd.sh"

echo -n

#set +x
#exec 2>&3 3>&-

