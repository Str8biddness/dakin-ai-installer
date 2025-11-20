#!/usr/bin/env bash
#
# uninstall_dakin_ai.sh
# Complete system removal script for Dakin AI installer components.
# Prompts for confirmation, idempotent, logs actions.
#

set -euo pipefail
IFS=$'\n\t'

LOGFILE=${LOGFILE:-/var/log/dakin_installer.log}
WORKDIR=${WORKDIR:-/opt/dakin_ai}
DAEMON_USER=${DAEMON_USER:-dakin}

log() { echo "$(date -Is) [uninstall] $*" | tee -a "$LOGFILE"; }
err() { echo "$(date -Is) [uninstall][ERROR] $*" | tee -a "$LOGFILE" >&2; }

confirm() {
  read -r -p "This will remove Dakin AI installations and data under $WORKDIR. Continue? [y/N] " ans
  case "$ans" in
    [Yy]*) return 0;;
    *) echo "Aborted."; exit 1;;
  esac
}

stop_services() {
  systemctl stop mirror-sync.service local-mirror.service || true
  systemctl disable mirror-sync.service local-mirror.service || true
  rm -f /etc/systemd/system/mirror-sync.service /etc/systemd/system/local-mirror.service || true
  systemctl daemon-reload || true
  log "Stopped and disabled systemd services."
}

remove_files() {
  rm -rf /opt/mirror-sync-system /opt/local-mirror-manager "$WORKDIR" || true
  log "Removed installation directories."
}

remove_user() {
  if id "$DAEMON_USER" >/dev/null 2>&1; then
    userdel "$DAEMON_USER" || true
    log "Removed user $DAEMON_USER."
  else
    log "Service user $DAEMON_USER not present."
  fi
}

main() {
  confirm
  stop_services
  remove_files
  remove_user
  log "Uninstall complete."
}

main
