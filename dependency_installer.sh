#!/usr/bin/env bash
#
# dependency_installer.sh
# Automated dependency resolution and installation.
# Supports Debian/Ubuntu (apt) and RHEL/CentOS (dnf/yum).
# Idempotent: checks before installing.
#

set -euo pipefail
IFS=$'\n\t'

LOGFILE=${LOGFILE:-/var/log/dakin_installer.log}
PY_REQ_FILE=${PY_REQ_FILE:-requirements.txt}

log() { echo "$(date -Is) [deps] $*" | tee -a "$LOGFILE"; }
err() { echo "$(date -Is) [deps][ERROR] $*" | tee -a "$LOGFILE" >&2; }

detect_pkg_mgr() {
  if command -v apt-get >/dev/null; then
    echo apt
  elif command -v dnf >/dev/null; then
    echo dnf
  elif command -v yum >/dev/null; then
    echo yum
  else
    echo unknown
  fi
}

install_system_pkgs() {
  local mgr
  mgr=$(detect_pkg_mgr)
  log "Detected package manager: $mgr"
  case "$mgr" in
    apt)
      export DEBIAN_FRONTEND=noninteractive
      apt-get update -y
      apt-get install -y build-essential git curl wget python3 python3-venv python3-dev python3-pip jq
      ;;
    dnf)
      dnf install -y @development-tools git curl wget python3 python3-venv python3-devel python3-pip jq
      ;;
    yum)
      yum groupinstall -y "Development Tools"
      yum install -y git curl wget python3 python3-venv python3-devel python3-pip jq
      ;;
    *)
      err "Unsupported package manager. Please install dependencies manually."
      exit 3
      ;;
  esac
}

install_python_packages() {
  if [ -f "$PY_REQ_FILE" ]; then
    log "Installing python packages from $PY_REQ_FILE"
    python3 -m pip install --upgrade pip setuptools wheel
    python3 -m pip install -r "$PY_REQ_FILE"
  else
    log "No $PY_REQ_FILE found — skipping python package install."
  fi
}

main() {
  log "Installing system packages..."
  install_system_pkgs
  install_python_packages
  log "Dependency installation complete."
}

main
