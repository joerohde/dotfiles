#!/bin/bash

# coalesce trailing non switch parameters so 'cd My Source Code' works.
# Note that this hack only flies for single space. Double quotes
# would still be needed for: "My  Really  Annoying Source Code"
# args are then dynamic scope name of 3 arrays:
# dynamic scope: flags [out]: inclusively up to the last flag/switch as an array
# dynamic scope: directory [out]: remaining arguments as a string
# "$@" [in]: command line to munge
function _cd_dirname()
{
    local count
    count=1
    for arg in "$@"; do
        # it's flag for our purposes if it starts with + or -
        if [[ "$arg" =~ ^[+-].* ]]; then
            flags+=("$arg")
            (( count++ ))
        else
            break
        fi
    done
    directory="${*:${count}}"
}

function _cd_pushd()
{
    [[ "$1" == "" ]] && shift
    # dirs is empty (+0 is cwd)
    if dirs +1 &> /dev/null; then
        local dest
        local top
        dest="${*:-1}"
        top="$(dirs | head -1)"
        top="${top/#\~/$HOME}"

        if [[ "$dest" == "$top" ]]; then
            builtin cd "$dest"
            return $?
        fi
    fi
    builtin pushd "$@" >/dev/null
}

# shellcheck disable=SC2120
function cd()
{
    #dynamic scope parameters
    local flags directory
    flags=()
    directory=
    _cd_dirname "$@"

    #local IFS='|'
    #echo "Flags: ${flags[*]}"
    #echo "Path: $directory"

    # show directory stand and return if no args
    [[ $# -eq 0 ]] && dirs -v | tail +2 && return

    local rc=1
    if [[ -f "$directory" ]]; then
	    local dir=$(dirname "$directory")
	    [[ -d $dir ]] && directory="$dir"
    fi

    if [[ "$directory" =~ ^\.\.+$ ]]; then
        rc=$?
        local i=${#directory}
        _cd_pushd ..
        while [ $i -gt 2 ]; do
            (( i-- ))
            builtin cd .. || builtin cd "$(dirname "PWD")" || return $?
            rc=$?
        done
        return $rc
    elif [[ "$directory" =~ ^\d+$ ]]; then
        local n
        n="$directory"
        _cd_pushd ~+${n}
        (( n++ ))
        buildin popd "+${n}" >/dev/null
    fi
    _cd_pushd "${flags[*]}" "$directory"
    return $?
}

function _cdd_find()
{
    mdfind -onlyin . "kMDItemDisplayName == '$1'c && kMDItemContentTypeTree == 'public.folder'c" \
		  | while read -r line; do echo "$(stat -c %Z "$line")" "$line"; done | sort -rn | cut -f 2- -d ' '
}
function cdd()
{
    local flags directory
    flags=()
    directory=
    _cd_dirname "$@"

    if [ -d "$directory" ]; then
        _cd_pushd "${flags[*]}" "$directory"
	    return $?
    fi

    # find best match directories and sort them by 'last change' stat
    local dirs prefix fuzzy
    dirs=$(_cdd_find "$1")

    # if the list is a little short, add in prefix matches, below exact matches
    if (( $(wc -l <<< "$dirs") < 32 )); then
        prefix=$(_cdd_find "$1*")
        dirs+=$'\n'$(awk 'FNR==NR {a[$0]++; next} !($0 in a)' <(echo "$dirs") <(echo "$prefix") )
    fi

    # still too low? Add any general match to the bottom
    if (( $(wc -l <<< "$dirs") < 32 )); then
        fuzzy=$(_cdd_find "*$1*")
        dirs+=$'\n'$(awk 'FNR==NR {a[$0]++; next} !($0 in a)' <(echo "$dirs") <(echo "$fuzzy") )
    fi

    dirs=${dirs//$PWD\//.\/}

    local -a lines=()
    local txt
    while read -r txt ; do
        lines+=("$txt")
    done <<EOF
$(printf "%s" "$dirs")
EOF
    if [ "${#lines[@]}" == "0" ]; then
        echo "cdd: no subdirectory found: ${directory}"
	    cd
	    return $?
    elif [ "${#lines[@]}" == "1" ]; then
	    _cd_pushd "${flags[*]}" "${lines[$item]}"
	    return $?
    fi

    which dialog > /dev/null 2>&1
    if [ "$?" != "0" ]; then
	    echo -e "cdd requires dialog package\nInstall with: [brew|sudo port] install dialog" 1>&2
	    return 100
    fi

    dirs=$(printf "%s" "$dirs" | awk '{ printf "\"%d\" \"" $0 "\"\n", NR }')
    local item
    item=$(eval dialog --stdout --keep-tite --menu \"Select Directory\" 0 0 0 $dirs)
    if [[ "$?" != "0" ]] || [[ -z "$item" ]]; then
	    return $?
    fi

    (( item-- ))
    _cd_pushd "${flags[*]}" "${lines[$item]}"
    return $?
}

function cd_debug_trap()
{
    local CMD="$BASH_COMMAND"
    if [[ "$CMD" == "." ]]; then
	    builtin pushd >/dev/null
        return 1
    elif [[ "$CMD" =~ ^\.+$ ]]; then
        local i=${#CMD}
        while [[ $i -gt 1 ]]; do
            test "$(dirs -p | wc -l)" -eq 1 && break
            builtin popd >/dev/null
            [[ "$?" == "0" ]] || { builtin popd -n >/dev/null; (( i++ )); }
            (( i-- ))
        done
        return 1
    fi
    return 0
}

if [[ -n "$preexec_functions" ]]; then
    preexec_functions+=(cd_debug_trap)
    shopt -s extdebug
else
    shopt -s extdebug
    trap cd_debug_trap DEBUG
fi
