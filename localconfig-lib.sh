#!/bin/bash
# Shared helpers for localconfig backup / restore.
# Sourced by localconfig-backup.sh and localconfig-restore.sh.
# Paths are overridable via environment (handy for testing).
set -u

LC_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
BAMBOO_ROOT="${BAMBOO_ROOT:-$HOME/dev/bamboo}"
LC_MANIFEST="${LC_MANIFEST:-$LC_SCRIPT_DIR/localconfig/manifest.txt}"
LC_BACKUP_DIR="${LC_BACKUP_DIR:-$LC_SCRIPT_DIR/localconfig/backups}"

# Absolute path to a suite checkout.
lc_suite_dir() {  # <root> <center>
  echo "${BAMBOO_ROOT}/$1/$2"
}

# Print manifest pathspecs (skip comments and blank lines).
lc_pathspecs() {
  grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$LC_MANIFEST"
}

# Relative paths of tracked files under the manifest pathspecs that differ from HEAD.
lc_modified_files() {  # <suite_dir>
  local suite="$1" specs
  specs="$(lc_pathspecs)"
  ( cd "$suite" && git diff --name-only HEAD -- $specs 2>/dev/null )
}
