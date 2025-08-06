#!/bin/env zsh

(( $+aliases[run-help] )) && unalias run-help && autoload -Uz run-help
(( $+functions[run-help] )) || autoload -Uz run-help

extract_commands() {
  local cmd_line=$1
  echo "$cmd_line" \
    | sed "s/'[^']*'//g; s/-\S*//g" \
    | xargs \
    | awk -F'\\$\\(|)|\\|' '{
        for (i=1; i<=NF; i++) {
          split($i, a, " ");
          if (a[1] == "sudo" || a[1] == "xargs" && a[2] != "") {
            print a[1]
            print a[2]
          }
          else if (a[1] != "") {
            print a[1]
          }
        }
      }' \
    | uniq \
    | tac
}

has-run-help() {
    local choice="$1"
    ! run-help "$choice" 2>&1 | grep -q '^No manual entry for'
}

popman() {
  local curr_buffer="$BUFFER"

  local choice
  choice=$(extract_commands "$curr_buffer" | fzf --height=15% --min-height 5+ --tmux --layout=reverse --exit-0 --select-1 --prompt="Select the tool you need help with: ")

  if [ $? -ne 0 ]; then
    return
  fi

  local command
  if has-run-help "$choice"; then
    command="/usr/share/zsh/functions/Misc/run-help $choice"
  elif man -w "$choice" &>/dev/null; then
    command="man $choice"
  elif builtin whence -p "$choice" &>/dev/null && "$choice" --help &>/dev/null; then
    command="$choice --help | less"
  else
	command="echo 'no manpage or help available for command: "\"$choice\""' | less"
  fi

  if [ "${TMUX}" ]; then
    tmux popup -EE -h 90% -w 90% "$command"
  else
    BUFFER=""
    zle redisplay
    "$command"
  fi

  BUFFER="$curr_buffer"
  CURSOR=$#BUFFER
  zle redisplay
}

zle -N popman
bindkey '^K' popman
