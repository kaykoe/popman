#!/bin/env zsh

extract_commands() {
  local cmd_line=$1
  # TODO: subshells in expressions, maybe in double quotes and backticks, maaaaybe in curly braces
  # TODO: split fields before seding, this will allow easier parsing
  echo "$cmd_line" \
    | sed -E 's/(['\''])[^\1]*\1//g
    s/^(.*[^"' \
    | sed -E \
    's/-\S*(\s+[^-]\S*)?//g
    s/\$\{[^}]*\}//g
    s/\$\({2}[^\)?=\)]*\){2,}//g
    s/\$\w+//g' \
    | tr -d "=!" \
    | xargs \
    | awk -F'\\$\\(|)|\\||&&|;|{|}' 'BEGIN {
        empty_or_whitespace = @/^\s*$|^$/
        has_subcommands["git"]++
        has_subcommands["apt-get"]++
        }
        {
        for (i=1; i<=NF; i++) {
          split($i, a, " ");
          j=1
          while (j<=length(a)) {
            if (a[j] in ENVIRON) {
              delete a[j]
            }
            else {
                j++
            }
          }
      if ((a[1] == "sudo" || a[1] == "xargs") && a[2] !~ empty_or_whitespace) {
            print a[1]
            print a[2]
          }
          else if (a[1] in has_subcommands && a[2] !~ empty_or_whitespace) {
            print a[1]" "a[2]
            print a[1]
          }
          else if (a[1] !~ empty_or_whitespace) {
            print a[1]
          }
        }
      }' \
    | cat -n \
    | sort -uk2 \
    | sort -n \
    | cut -f2- \
    | tac
}

popman() {
  local curr_buffer=$BUFFER

  local choice
  choice=$(extract_commands "$curr_buffer" | fzf --height=15% --min-height 5+ --tmux --layout=reverse --exit-0 --select-1 --prompt="Select the tool you need help with: ")

  if [ $? -ne 0 ]; then
    return
  fi

  local command
  if man -w "$choice" &>/dev/null; then
    command="man $choice"
  elif builtin whence -p "$choice" &>/dev/null && "$choice" --help &>/dev/null; then
    command="$choice --help | less"
  else
    command="echo 'no manpage or --help available for command: "\"$choice\""' | less"
  fi

  if [ "${TMUX}" ]; then
    tmux popup -EE -h 90% -w 90% "$command"
  else
    BUFFER=""
    zle redisplay
    "$command"
  fi

  BUFFER=$curr_buffer
  CURSOR=$#BUFFER
  zle redisplay
}

zle -N popman
bindkey '^K' popman
