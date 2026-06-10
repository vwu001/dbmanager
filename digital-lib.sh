#!/bin/bash
# Shared helpers for the digital UI repos (agentquotehome, agentexperience).
# Sourced by digital-backup.sh, digital-restore.sh, digital-start.sh.
# Paths are overridable via environment (handy for testing).
set -u

DG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DIGITAL_ROOT="${DIGITAL_ROOT:-$HOME/dev/bamboo/gw}"
DIGITAL_MANIFEST="${DIGITAL_MANIFEST:-$DG_SCRIPT_DIR/digital/manifest.txt}"
DIGITAL_BACKUP_DIR="${DIGITAL_BACKUP_DIR:-$DG_SCRIPT_DIR/digital/backups}"

# Absolute path to a digital repo checkout.
dg_repo_dir() {  # <repo>
  echo "${DIGITAL_ROOT}/$1"
}

# Print manifest pathspecs (skip comments and blank lines).
dg_pathspecs() {
  grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$DIGITAL_MANIFEST"
}

# Relative paths of tracked files under the manifest pathspecs that differ from HEAD.
dg_modified_files() {  # <repo_dir>
  local repo="$1" specs
  specs="$(dg_pathspecs)"
  ( cd "$repo" && git diff --name-only HEAD -- $specs 2>/dev/null )
}
