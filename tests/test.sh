#!/bin/bash

ret=0
SCRIPTPATH="$(cd "$(dirname "$0")" && pwd)/test.sh"
SERVER="$(cd "$(dirname "$0")/../" && pwd)/refresh.sh"
ASSETS_ROOT="$(cd "$(dirname "$0")/assets" && pwd)"
TESTDIR="$ASSETS_ROOT/testdir"
ERROR_MSG=''

reset() {
  rm -rf "$TESTDIR"
  mkdir -p "$TESTDIR"
  cd "$TESTDIR" || return
  git init >/dev/null 2>&1
  git branch -M main >/dev/null 2>&1
}
data() { IFS=$'\n' read -r -d '' DATA || true; }
do_test() { echo "$DATA" | "$SERVER" test "$1"; }
assert() {
  not=''
  if [ "$1" = 'not' ]; then not=' not'; shift; fi
  case "$1" in
    contained )
      message="'$2' should%s be contained in $3"
      echo "$3" | grep -q "$2"
      ;;
    deleted)
      message="$2 should%s be deleted."
      ! [ -e "$2" ]
      ;;
    committed )
      message="'$2' should%s be committed."
      status=$(git -C "$TESTDIR" status --short)
      ! echo "$status" | grep -q "$2"
      ;;
  esac
  code=$?
  if { [ $code != 0 ] && [ -z "$not" ]; } ||
    { [ $code == 0 ] && [ -n "$not" ]; }; then
    ERROR_MSG=$(printf "$message" "$not")
    return 1
  fi
  return 0
}

git_dir_validation_arrange() {
rm -rf "$TESTDIR/.git"
data <<EOF
$TESTDIR
EOF
}
git_dir_validation_assert() {
  assert contained 'is not a git dir' "$1"
}

branch_validation_arrange() {
data <<EOF
$TESTDIR
invalid_branch
EOF
}
branch_validation_assert() {
  assert contained 'branch check failed' "$1"
}

delete_empty_some_arrange() {
touch "$TESTDIR/one" "$TESTDIR/two" "$TESTDIR/three"
data <<EOF
$TESTDIR
main
delete_empty
one
two

EOF
}
delete_empty_some_assert() {
  assert deleted "$TESTDIR/one" &&
  assert deleted "$TESTDIR/two" &&
  assert not deleted "$TESTDIR/three"
}

delete_empty_all_arrange() {
touch "$TESTDIR/one" "$TESTDIR/two"
echo dont_delete > "$TESTDIR/three"
data <<EOF
$TESTDIR
main
delete_empty
*

EOF
}
delete_empty_all_assert() {
  assert deleted "$TESTDIR/one" &&
  assert deleted "$TESTDIR/two" &&
  assert not deleted "$TESTDIR/three"
}

commit_message_validation_arrange() {
data <<EOF
$TESTDIR
main
push
EOF
}
commit_message_validation_assert() {
  assert contained 'commit message is empty' "$1"
}

git_push_some_arrange() {
touch "$TESTDIR/one" "$TESTDIR/two"
data <<EOF
$TESTDIR
main
push
commit message
one

EOF
}
git_push_some_assert() {
  assert committed one &&
  assert not committed two &&
  assert contained 'git push' "$1"
}

git_push_all_arrange() {
touch "$TESTDIR/one" "$TESTDIR/two"
data <<EOF
$TESTDIR
main
push
commit message
*

EOF
}
git_push_all_assert() {
  assert committed one &&
  assert committed two &&
  assert contained 'git push' "$1"
}

delete_and_git_push_arrange() {
echo one > "$TESTDIR/one"
echo two > "$TESTDIR/two"
touch "$TESTDIR/three"

data <<EOF
$TESTDIR
main
delete_empty
*

push
commit message
*

EOF
}
delete_and_git_push_assert() {
  status=$(git -C "$TESTDIR" status --short)
  assert deleted "$TESTDIR/three" &&
  assert committed one &&
  assert committed two &&
  assert contained 'git push' "$1"
}


#
# main
#
test_names=$(grep -F '_assert()' "$SCRIPTPATH" | grep -v grep |
  rev | cut -d_ -f2- | rev)
if [ -n "$1" ]; then
  test_names=$(echo "$test_names" | grep "$1")
fi
for test_name in $test_names; do
  printf test_"%-30s" "$test_name"
  reset
  "${test_name}_arrange"
  output="$(do_test)"
  if ! "${test_name}_assert" "$output"; then
    printf "\033[0;31mFAILED\033[0m\n"
    printf "%s\n\n===== TEST LOG =====\n\n" "$ERROR_MSG"
    ret=1
    reset
    "${test_name}_arrange"
    do_test info
    printf "\n"
  else
    printf "\033[0;32mSUCCESS\033[0m\n"
  fi
done

rm -rf "$TESTDIR"
exit $ret
