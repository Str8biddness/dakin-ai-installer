#!/usr/bin/env bash
#
# component_installer.sh
# Installs individual components: core, mirror, local
# Idempotent and uses simple checks to avoid re-running work.
#

set -euo pipefail
IFS=$'\n\t'

COMPONENTS=${1:-all}
WORKDIR=${WORKDIR:-/opt/dakin_ai}
LOGFILE=${LOGFILE:-/var/log/dakin_installer.log}

log() { echo "$(date -Is) [component] $*" | tee -a "$LOGFILE"; }
err() { echo "$(date -Is) [component][ERROR] $*" | tee -a "$LOGFILE" >&2; }

install_core() {
  log "Installing core components..."
  mkdir -p "$WORKDIR/core"
  if [ -f "$WORKDIR/core/.installed" ]; then
    log "Core already installed — skipping."
    return 0
  fi

  # Example: create a virtualenv and install base packages
  python3 -m venv "$WORKDIR/core/venv"
  "$WORKDIR/core/venv/bin/pip" install --upgrade pip
  if [ -f requirements.txt ]; then
    "$WORKDIR/core/venv/bin/pip" install -r requirements.txt
  fi

  touch "$WORKDIR/core/.installed"
  log "Core installed."
}

install_mirror_sync() {
  log "Installing mirror-sync-system..."
  if [ -d /opt/mirror-sync-system ]; then
    log "mirror-sync-system already present — updating."
    git -C /opt/mirror-sync-system pull || true
  else
    git clone https://github.com/Str8biddness/mirror-sync-system.git /opt/mirror-sync-system || true
  fi

  # Idempotent: install python deps
  if [ -f /opt/mirror-sync-system/requirements.txt ]; then
    python3 -m pip install -r /opt/mirror-sync-system/requirements.txt
  fi

  # Register systemd unit if present
  if [ -f /opt/mirror-sync-system/systemd/mirror-sync.service ]; then
    cp /opt/mirror-sync-system/systemd/mirror-sync.service /etc/systemd/system/mirror-sync.service
    systemctl daemon-reload || true
    systemctl enable --now mirror-sync.service || true
  fi

  log "mirror-sync-system installed."
}

install_local_mirror() {
  log "Installing local-mirror-manager..."
  if [ -d /opt/local-mirror-manager ]; then
    log "local-mirror-manager already present — updating."
    git -C /opt/local-mirror-manager pull || true
  else
    git clone https://github.com/Str8biddness/local-mirror-manager.git /opt/local-mirror-manager || true
  fi

  if [ -f /opt/local-mirror-manager/requirements.txt ]; then
    python3 -m pip install -r /opt/local-mirror-manager/requirements.txt
  fi

  # Example service registration (optional)
  if [ -f /opt/local-mirror-manager/systemd/local-mirror.service ]; then
    cp /opt/local-mirror-manager/systemd/local-mirror.service /etc/systemd/system/local-mirror.service
    systemctl daemon-reload || true
    systemctl enable --now local-mirror.service || true
  fi

  log "local-mirror-manager installed."
}

main() {
  log "Component installer invoked for: $COMPONENTS"
  case "$COMPONENTS" in
    all)
      install_core
      install_mirror_sync
      install_local_mirror
      ;;
    core)
      install_core
      ;;
    mirror)
      install_mirror_sync
      ;;
    local)
      install_local_mirror
      ;;
    *)
      log "Unknown component spec: $COMPONENTS"
      exit 1
      ;;
  esac
  log "Component installation finished."
}

main "$@"
