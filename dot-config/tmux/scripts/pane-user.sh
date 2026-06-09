#!/usr/bin/env bash

tty=$(tmux display-message -p "#{pane_tty}")
tty=${tty#/dev/}

cmd=$(ps -t "$tty" -o command= | tail -1)

if [[ "$cmd" =~ ^ssh[[:space:]] ]]; then
    target=$(echo "$cmd" | awk '{print $NF}')

    if [[ "$target" == *"@"* ]]; then
        echo "${target%@*}"
    else
        echo "$USER"
    fi
else
    echo "$USER"
fi