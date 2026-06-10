#!/bin/bash
# Launch a Guidewire Studio environment with the correct IntelliJ + Java.
# Usage: ./launchstudio.sh <root> <center> [--ultimate]
# Set DRY_RUN=1 to print the resolved environment and command without launching.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/launch-config.sh"

if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  echo "Usage: $0 <root> <center> [--ultimate]" >&2
  exit 1
fi

root="$1"
center="$2"
edition="${3:-}"

for excluded in $EXCLUDED_ROOTS; do
  if [ "$root" = "$excluded" ]; then
    echo "Error: '$root' is snapshot-only and is not a launch target." >&2
    exit 1
  fi
done

if [ "$edition" = "--ultimate" ]; then
  idea_home="$IDEA_UT_HOME"
elif [ -z "$edition" ]; then
  idea_home="$IDEA_CE_HOME"
else
  echo "Error: unknown option '$edition' (expected --ultimate)." >&2
  exit 1
fi

studio_dir="${BAMBOO_ROOT}/${root}/${center}"
if [ ! -x "${studio_dir}/gwb" ]; then
  echo "Error: ${studio_dir}/gwb not found or not executable." >&2
  exit 1
fi

if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "IDEA_HOME=${idea_home}"
  echo "JAVA_HOME=${STUDIO_JAVA_HOME}"
  echo "CMD=${studio_dir}/gwb studio"
  exit 0
fi

export IDEA_HOME="$idea_home"
export JAVA_HOME="$STUDIO_JAVA_HOME"
cd "$studio_dir" || exit 1
exec ./gwb studio
