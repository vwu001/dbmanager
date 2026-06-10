#!/bin/bash
# Check whether the environment variables the Guidewire suite needs are set.
# Reports SET / MISSING per variable. Shows values for non-secret vars; secrets are masked.
#
# Usage: ./localconfig-checkenv.sh
# Reads variable names + tags from localconfig/required-env.txt.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
LIST="${LC_ENV_LIST:-$DIR/localconfig/required-env.txt}"

missing=0
while IFS= read -r line; do
  case "$line" in ''|\#*) continue ;; esac
  name="${line%%[[:space:]]*}"
  case "$line" in
    *"[user-show]"*) tag="user-show" ;;
    *"[user]"*)      tag="user" ;;
    *)               tag="set" ;;
  esac

  val="${!name:-}"
  if [ -n "$val" ]; then
    if [ "$tag" = "user" ]; then
      printf '  SET      %-28s (hidden)\n' "$name"
    else
      printf '  SET      %-28s = %s\n' "$name" "$val"
    fi
  else
    case "$tag" in
      set)       hint="skill can help set" ;;
      user-show) hint="you set this (e.g. DEPLOYMENT_ID env segment)" ;;
      user)      hint="you must obtain & export" ;;
    esac
    printf '  MISSING  %-28s [%s]\n' "$name" "$hint"
    missing=$((missing + 1))
  fi
done < "$LIST"

echo ""
if [ "$missing" -eq 0 ]; then
  echo "All required env vars are set."
  exit 0
fi
echo "$missing missing. [set] = skill can help set; others you provide and export yourself."
exit 1
