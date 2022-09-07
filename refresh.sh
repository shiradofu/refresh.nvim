#!/bin/bash

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SERVER="$REPO_ROOT/refresh.sh"

process() {
  log info "data: $data"
  i=1
  get() { echo "$data" | cut -d$'\n' -f$i; }

  dir=$(get);(( i++ ))
  log info "dir: $dir"
  if [ -z "$dir" ] || [ ! -d "$dir/.git" ]; then
    log error "$dir is not a git dir"
    return 1
  fi

  cd "$dir" || return 1

  branch=$(get);(( i++ ))
  current_branch=$(git branch --show-current)
  log info "branch: $branch"
  log info "current_branch: $current_branch"
  if [ -n "$branch" ] && [ "$branch" != "$current_branch" ]; then
    log error "branch check failed"
    return 1
  fi

  task=$(get);(( i++ ))
  while [ -n "$task" ]; do
    log info "task: $task"
    case "$task" in
      delete_empty )
        arg=$(get);(( i++ ))
        log info "delete_empty first arg: $arg"
        if [ "$arg" = '*' ]; then
          log info 'delete all empty files'
          find . -type f -not -path "./.git/*" -empty -print -delete
          find . -type d -not -path "./.git/*" -empty -print -delete
          (( i++ ))
        else
          while [ -n "$arg" ]; do
            log info rm "$arg"
            [ -w "$arg" ] && ! [ -s "$arg" ] && rm "$arg"
            arg=$(get);(( i++ ))
          done
        fi
        ;;
      push )
        commit_msg=$(get);(( i++ ))
        log info "commit_msg: $commit_msg"
        if [ -z "$commit_msg" ]; then
          log error 'commit message is empty'
          return 1
        fi
        file=$(get);(( i++ ))
        log info "git-add first argument: $file"
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
    task=$(get);(( i++ ))
  done
}

stop() { pkill -9 -f "$SERVER"; }

LOG_LEVEL=
log() {
  case "$LOG_LEVEL" in
    error ) if [ "$1" = 'error' ]; then shift; echo "$*"; fi;;
    info ) shift; echo "$*";;
    * );;
  esac
}

mock_for_debug() {
  rm() { log info "rm $*"; }
  find() { :; }
  git() {
    case "$1" in
      add | commit | push ) echo "git $*" ;;
      *) command git "$@" ;;
    esac
  }
}

mock_for_test() {
  git() {
    case "$1" in
      push ) echo "git push" ;;
      *) command git "$@" ;;
    esac
  }
}

main() {
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
    process "$data"
    continue
  done
}

case "$1" in
  restart )
    stop
    nohup "$SERVER" >/dev/null 2>&1 &
    exit
    ;;
  stop )
    stop
    exit $?
    ;;
  test )
    [ -z "$2" ] && LOG_LEVEL=error || LOG_LEVEL="$2"
    mock_for_test
    data=$(cat -)
    process "$data"
    exit $?
    ;;
  debug )
    printf "\n ==========\n DEBUG MODE\n ==========\n\n"
    LOG_LEVEL=info
    [ "$2" = 'mock' ] && mock_for_debug
    ;;
esac

main
