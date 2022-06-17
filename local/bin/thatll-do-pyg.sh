#!/bin/bash

if [[ "${*: -1}" == "-" ]]; then
    pygmentize "${@:1:$#-1}"
else
    echo "${@}"
    exec pygmentize "${@}"
fi
