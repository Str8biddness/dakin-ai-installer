#!/usr/bin/env bash
#
# post_install_config.sh
# Post-installation automation: creates users, config files, log rotation, basic TLS hints
#

set -euo pipefail
IFS=$'\n\t'

LOGFILE=${LOGFILE:-/var/log/dakin_installer.log}
WORKDIR=${WORKDIR:-/opt/dakin_ai}
DAEMON_USER=${DAEMON_USER:-dakin}

log() { echo "$(date -Is) [postcfg] $*" | tee -a "$LOGFILE"; }
err() { echo "$(date -Is) [postcfg][ERROR] $*" | tee -a "$LOGFILE" >&2; }

create_service_user() {
  if id "$DAEMON_USER" >/dev/null 2>&1; then
    log "Service user $DAEMON_USER already exists."
  else
    useradd --system --home "$WORKDIR" --shell /usr/sbin/nologin "$DAEMON_USER"
    log "Created service user $DAEMON_USER."
  fi
}

setup_logrotate() {
  cat >/etc/logrotate.d/dakin <<'EOF'
/var/log/dakin_*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root adm
}
EOF
  log "Installed logrotate config for Dakin logs."
}

finalize_permissions() {
  mkdir -p "$WORKDIR"
  chown -R "$DAEMON_USER":"$DAEMON_USER" "$WORKDIR" || true
  log "Permissions set for $WORKDIR."
}

main() {
  create_service_user
  setup_logrotate
  finalize_permissions
  log "Post-install configuration finished."
}

main
