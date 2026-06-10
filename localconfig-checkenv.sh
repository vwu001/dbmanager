#!/bin/bash
# Check whether the environment variables the Guidewire suite needs are set.
# Reports set / missing per variable ONLY — never prints values (they stay masked in chat).
# Required vars missing -> non-zero exit. Optional (live-integration) vars never fail.
#
# Usage: ./localconfig-checkenv.sh
# Reads variable names + tags from localconfig/required-env.txt.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
LIST="${LC_ENV_LIST:-$DIR/localconfig/required-env.txt}"

missing_required=0
while IFS= read -r line; do
  case "$line" in ''|\#*) continue ;; esac
  name="${line%%[[:space:]]*}"
  case "$line" in
    *"[set]"*)        tag="set" ;;
    *"[req]"*)        tag="req" ;;
    *"[opt-secret]"*) tag="opt-secret" ;;
    *"[opt]"*)        tag="opt" ;;
    *)                tag="set" ;;
  esac

  if [ -n "${!name:-}" ]; then
    printf '  SET       %s\n' "$name"
    continue
  fi

  case "$tag" in
    set)        printf '  MISSING   %-28s (required — skill can help set)\n' "$name"; missing_required=$((missing_required + 1)) ;;
    req)        printf '  MISSING   %-28s (required — you set this)\n' "$name"; missing_required=$((missing_required + 1)) ;;
    opt)        printf '  optional  %-28s (live integrations; else mock)\n' "$name" ;;
    opt-secret) printf '  optional  %-28s (live integrations, secret; else mock)\n' "$name" ;;
  esac
done < "$LIST"

echo ""
if [ "$missing_required" -eq 0 ]; then
  echo "All REQUIRED env vars are set. Optional integration vars are only needed for live servers."
  exit 0
fi
echo "$missing_required required env var(s) missing."
exit 1
