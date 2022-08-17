#!/bin/bash

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SERVER="$REPO_ROOT/server.sh"

stop() {
  pkill -9 -f "$SERVER"
}

if [ "$1" = 'restart' ]; then
  stop
  nohup "$SERVER" >/dev/null 2>&1 &
  exit
fi

if [ "$1" = 'stop' ]; then
  stop
  exit $?
fi

DEBUG=false
log() { if "$DEBUG"; then echo "$1"; fi; }
if [ "$1" = 'debug' ]; then
  printf "\n ==========\n DEBUG MODE\n ==========\n\n"
  DEBUG=true
  rm() { log "rm $*"; }
  find() { :; }
  git() {
    case "$1" in
      add | commit | push ) echo "git $*" ;;
      *) command git "$@" ;;
    esac
  }
fi

#
# main
#
DATA_DIR="$(nvim --headless -c 'echo stdpath("data")' -c 'q' 2>&1)/fresh"
FIFO="$DATA_DIR/fifo"
if [ ! -p "$FIFO" ]; then
  rm -f "$FIFO"
  mkdir -p "$DATA_DIR"
  mkfifo "$FIFO"
fi

while true; do
  cd "$REPO_ROOT" || continue
  data=$(cat "$FIFO")

  i=1
  get() {
    echo "$data" | cut -d$'\n' -f$i
  }

  dir=$(get);(( i++ ))
  log "dir: $dir"
  if [ -z "$dir" ] || [ ! -d "$dir/.git" ]; then
    log "$dir is not a git dir"
    continue
  fi

  cd "$dir" || continue

  branch=$(get);(( i++ ))
  current_branch=$(git rev-parse --abbrev-ref HEAD)
  log "branch: $branch"
  log "current_branch: $current_branch"
  if [ -n "$branch" ] && [ "$branch" != "$current_branch" ]; then
    log "branch check failed"
    continue
  fi

  task=$(get);(( i++ ))
  while [ -n "$task" ]; do
    log "task: $task"
    case "$task" in
      delete_empty )
        arg=$(get);(( i++ ))
        log "delete_empty first arg: $arg"
        if [ "$arg" = '*' ]; then
          log 'delete all empty files'
          find . -type f -empty -print -delete
          find . -type d -empty -print -delete
          (( i++ ))
        else
          while [ -n "$arg" ]; do
            [ -w "$arg" ] && ! [ -s "$arg" ]&& rm "$arg"
            arg=$(get);(( i++ ))
          done
        fi
        ;;
      push )
        commit_msg=$(get);(( i++ ))
        log "commit_msg: $commit_msg"
        if [ -z "$commit_msg" ]; then
          log 'commit message check failed'
          continue
        fi
        # shellcheck disable=1083
        if ! git name-rev @{u} >/dev/null; then
          log 'upstream check failed'
          continue
        fi
        file=$(get);(( i++ ))
        log "git-add first argument: $file"
        if [ "$file" = '*' ]; then
          git add -A
          (( i++ ))
        else
          while [ -n "$file" ]; do
            git add "$file"
            file=$(get);(( i++ ))
          done
        fi
        git commit -m "$commit_msg"
        git push
        ;;
      * ) ;;
    esac
  done
  task=$(get);(( i++ ))
done
