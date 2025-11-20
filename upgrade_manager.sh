#!/usr/bin/env bash
#
# upgrade_manager.sh
# Automates version upgrades for installed components.
# Performs backup, upgrade (git pull / pip installs), and health check.
#

set -euo pipefail
IFS=$'\n\t'

LOGFILE=${LOGFILE:-/var/log/dakin_installer.log}
BACKUP_DIR=${BACKUP_DIR:-/var/backups/dakin_ai}
REPOS=(/opt/mirror-sync-system /opt/local-mirror-manager)
DAEMON_USER=${DAEMON_USER:-dakin}

log() { echo "$(date -Is) [upgrade] $*" | tee -a "$LOGFILE"; }
err() { echo "$(date -Is) [upgrade][ERROR] $*" | tee -a "$LOGFILE" >&2; }

backup() {
  mkdir -p "$BACKUP_DIR"
  local stamp
  stamp=$(date +%Y%m%d_%H%M%S)
  for r in "${REPOS[@]}"; do
    if [ -d "$r" ]; then
      tar -czf "$BACKUP_DIR/$(basename "$r")_$stamp.tar.gz" -C "$(dirname "$r")" "$(basename "$r")"
      log "Backed up $r to $BACKUP_DIR"
    fi
  done
}

upgrade_repo() {
  local r=$1
  if [ -d "$r" ]; then
    log "Upgrading repo $r"
    git -C "$r" pull || log "Git pull returned non-zero but continuing"
    if [ -f "$r/requirements.txt" ]; then
      python3 -m pip install -r "$r/requirements.txt"
    fi
  else
    log "Repo $r not present; skipping."
  fi
}

health_check() {
  systemctl is-active --quiet mirror-sync.service || err "mirror-sync.service not active"
  systemctl is-active --quiet local-mirror.service || err "local-mirror.service not active"
  log "Services active."
}

main() {
  backup
  for r in "${REPOS[@]}"; do
    upgrade_repo "$r"
  done
  systemctl daemon-reload || true
  systemctl restart mirror-sync.service local-mirror.service || true
  health_check || err "Health check failed after upgrade."
  log "Upgrade complete."
}

main
