#!/usr/bin/env bash
#
# install_dakin_ai.sh
# Master installation orchestrator for Dakin AI platform.
# Idempotent. Implements logging, progress feedback, rollback on failure.
#
# Usage: sudo ./install_dakin_ai.sh [--components "core,mirror,local"] [--no-start]
#

set -euo pipefail
IFS=$'\n\t'

# Configurable
LOGFILE=${LOGFILE:-/var/log/dakin_installer.log}
WORKDIR=${WORKDIR:-/opt/dakin_ai}
COMPONENTS=${1:-all}   # "all" or comma-separated list
NO_START=0

# Simple progress / spinner util
spinner() {
  local pid=$1
  local delay=0.08
  local spinstr='|/-\'
  while kill -0 "$pid" 2>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

log() { echo "$(date -Is) [install] $*" | tee -a "$LOGFILE"; }
err() { echo "$(date -Is) [ERROR] $*" | tee -a "$LOGFILE" >&2; }

# Rollback states
ROLLBACK_CMDS=()

register_rollback() {
  ROLLBACK_CMDS+=("$*")
}

run_with_rollback() {
  local cmd="$*"
  log "RUN: $cmd"
  eval "$cmd" || { err "Command failed: $cmd"; rollback_and_exit 1; }
}

rollback_and_exit() {
  local rc=${1:-1}
  err "Initiating rollback..."
  # Run registered rollback commands in reverse order
  for (( idx=${#ROLLBACK_CMDS[@]}-1 ; idx>=0 ; idx-- )) ; do
    log "ROLLBACK: ${ROLLBACK_CMDS[$idx]}"
    eval "${ROLLBACK_CMDS[$idx]}" || err "Rollback command failed: ${ROLLBACK_CMDS[$idx]}"
  done
  err "Installation failed. See $LOGFILE"
  exit "$rc"
}

preflight_checks() {
  log "Starting system check..."
  bash ./system_check.sh || rollback_and_exit 2
  log "System check passed."
}

install_dependencies() {
  log "Installing dependencies..."
  bash ./dependency_installer.sh || rollback_and_exit 3
  log "Dependencies installed."
}

install_components() {
  log "Installing components..."
  bash ./component_installer.sh "$COMPONENTS" || rollback_and_exit 4
}

post_config() {
  log "Running post-install configuration..."
  bash ./post_install_config.sh || rollback_and_exit 5
  log "Post-install configuration complete."
}

finish() {
  log "Installation completed successfully."
  printf "\nInstallation completed successfully. Logs: %s\n" "$LOGFILE"
}

# Trap unexpected errors
trap 'err "Unexpected error on line $LINENO"; rollback_and_exit 99' ERR

main() {
  mkdir -p "$WORKDIR"
  chown "${SUDO_USER:-root}" "$WORKDIR" || true
  log "Working directory: $WORKDIR"
  preflight_checks &
  spinner $!
  install_dependencies &
  spinner $!
  install_components &
  spinner $!
  post_config &
  spinner $!
  finish
}

main "$@"
