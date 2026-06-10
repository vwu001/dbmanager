#!/bin/bash
# Minimal assertion helpers for plain-bash tests.
# Usage: source tests/assert.sh ; then call assert_* ; call done_tests at end.

ASSERT_FAILURES=0

assert_contains() {
  # assert_contains "<haystack>" "<needle>" "<message>"
  case "$1" in
    *"$2"*) printf 'ok   - %s\n' "$3" ;;
    *) printf 'FAIL - %s\n      expected to contain: %s\n      got: %s\n' "$3" "$2" "$1"
       ASSERT_FAILURES=$((ASSERT_FAILURES + 1)) ;;
  esac
}

assert_equals() {
  # assert_equals "<actual>" "<expected>" "<message>"
  if [ "$1" = "$2" ]; then
    printf 'ok   - %s\n' "$3"
  else
    printf 'FAIL - %s\n      expected: %s\n      got: %s\n' "$3" "$2" "$1"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
}

assert_status() {
  # assert_status "<actual_exit_code>" "<expected_exit_code>" "<message>"
  if [ "$1" -eq "$2" ]; then
    printf 'ok   - %s\n' "$3"
  else
    printf 'FAIL - %s\n      expected exit %s, got %s\n' "$3" "$2" "$1"
    ASSERT_FAILURES=$((ASSERT_FAILURES + 1))
  fi
}

done_tests() {
  if [ "$ASSERT_FAILURES" -eq 0 ]; then
    printf '\nAll assertions passed.\n'
    exit 0
  fi
  printf '\n%s assertion(s) failed.\n' "$ASSERT_FAILURES"
  exit 1
}
