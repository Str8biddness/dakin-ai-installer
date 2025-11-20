#!/usr/bin/env bash
#
# system_check.sh
# Pre-installation system requirements validator for Dakin AI
# Exits nonzero on failure. Writes summary to STDOUT and LOGFILE.
#

set -euo pipefail
IFS=$'\n\t'

LOGFILE=${LOGFILE:-/var/log/dakin_installer.log}
MIN_PYTHON_VERSION=${MIN_PYTHON_VERSION:-3.8}
REQUIREMENTS=(curl wget git python3 pip3 systemd)

log() { echo "$(date -Is) [syscheck] $*" | tee -a "$LOGFILE"; }
err() { echo "$(date -Is) [syscheck][ERROR] $*" | tee -a "$LOGFILE" >&2; }

check_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Required command missing: $1"; return 1; }
}

check_python() {
  if command -v python3 >/dev/null 2>&1; then
    local ver
    ver=$(python3 -c 'import platform,sys; v=platform.python_version(); print(v)')
    log "Detected python3 version $ver"
    # compare versions digit by digit
    IFS='.' read -r -a vparts <<< "$ver"
    if (( vparts[0] < 3 || (vparts[0]==3 && vparts[1] < 8) )); then
      err "Python3 >= $MIN_PYTHON_VERSION required."
      return 1
    fi
  else
    err "python3 not installed."
    return 1
  fi
}

main() {
  log "Running system checks..."
  local fail=0
  for cmd in "${REQUIREMENTS[@]}"; do
    if ! check_cmd "$cmd"; then
      fail=1
    fi
  done

  if ! check_python; then
    fail=1
  fi

  # Check free disk space on / (>=2GB)
  local freespace_kb
  freespace_kb=$(df --output=avail / | tail -1)
  if (( freespace_kb < 2000000 )); then
    err "Not enough free disk space on / (need >=2GB)."
    fail=1
  fi

  # Check systemd
  if ! pidof systemd >/dev/null 2>&1; then
    err "systemd not detected. Service integration will not be available."
    fail=1
  fi

  if (( fail )); then
    err "System checks failed. Address issues and re-run installer."
    exit 2
  fi

  log "All system checks passed."
  exit 0
}

main
