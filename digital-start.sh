#!/bin/bash
# Start the digital UI apps in the correct order, after the suite is up.
# Order: agentquotehome (:3001) -> agentexperience (:3000). Both need the local suite
# (PolicyCenter on :8180) already running.
#
# Usage: ./digital-start.sh
# Apps run in the background; logs in digital/logs/<repo>.log, PIDs in <repo>.pid.
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/digital-lib.sh"

SUITE_PORT="${SUITE_PORT:-8180}"
LOG_DIR="${DIGITAL_LOG_DIR:-$DIR/digital/logs}"
mkdir -p "$LOG_DIR"

port_up() {  # <port>
  nc -z localhost "$1" >/dev/null 2>&1
}

if ! port_up "$SUITE_PORT"; then
  echo "Warning: nothing is listening on localhost:$SUITE_PORT (PolicyCenter)."
  echo "The digital apps need the suite running. Continuing anyway."
fi

start_repo() {  # <repo> <port>
  local repo="$1" port="$2" d
  d="$(dg_repo_dir "$repo")"
  if [ ! -d "$d" ]; then
    echo "Error: repo not found: $d" >&2
    return 1
  fi
  if port_up "$port"; then
    echo "$repo already running on :$port — skipping."
    return 0
  fi
  echo "Starting $repo on :$port ..."
  ( cd "$d" && nohup npm start > "$LOG_DIR/$repo.log" 2>&1 & echo $! > "$LOG_DIR/$repo.pid" )
  echo "  log: $LOG_DIR/$repo.log   pid: $(cat "$LOG_DIR/$repo.pid" 2>/dev/null)"
}

wait_for_port() {  # <port> <seconds>
  local port="$1" secs="$2" i=0
  while [ "$i" -lt "$secs" ]; do
    port_up "$port" && return 0
    sleep 2
    i=$((i + 2))
  done
  return 1
}

start_repo agentquotehome 3001 || exit 1
echo "Waiting up to 90s for agentquotehome (:3001)..."
if wait_for_port 3001 90; then
  echo "  agentquotehome is up."
else
  echo "  still starting (check $LOG_DIR/agentquotehome.log); continuing."
fi

start_repo agentexperience 3000 || exit 1
echo ""
echo "Digital UI starting. Tail logs in $LOG_DIR (agentquotehome.log, agentexperience.log)."
echo "URLs: agentexperience http://localhost:3000  |  agentquotehome https://localhost:3001"
