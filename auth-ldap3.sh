#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Author: gameguys919
# License: MIT
# Source: https://goauthentik.io

APP="authentik-ldap"
var_tags="${var_tags:-authentik;ldap}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-256}"
var_disk="${var_disk:-2}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -f /usr/local/bin/authentik-ldap ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Stopping Service"
  systemctl stop authentik-ldap
  msg_ok "Service Stopped"

  msg_info "Updating Authentik LDAP Outpost Binary"
  AUTHENTIK_VERSION=$(curl -s "$(cat /etc/authentik-ldap/host)/api/v3/root/config/" 2>/dev/null | grep -oP '"authentik_version":"\K[^"]+' || echo "")
  if [[ -z "$AUTHENTIK_VERSION" ]]; then
    msg_error "Could not determine Authentik version. Check /etc/authentik-ldap/host"
    exit 1
  fi
  wget -qO /usr/local/bin/authentik-ldap \
    "https://github.com/goauthentik/authentik/releases/download/version%2F${AUTHENTIK_VERSION}/authentik-outpost-ldap_linux_amd64"
  chmod +x /usr/local/bin/authentik-ldap
  msg_ok "Updated to version ${AUTHENTIK_VERSION}"

  msg_info "Starting Service"
  systemctl start authentik-ldap
  msg_ok "Started Service"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

# ── Authentik-Konfiguration abfragen ─────────────────────────────────────────
AUTHENTIK_HOST=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
  --title "AUTHENTIK HOST" \
  --inputbox "\nEnter Authentik URL\n(e.g. http://192.168.20.101:9000)" 12 58 \
  3>&1 1>&2 2>&3) || exit 1

AUTHENTIK_TOKEN=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
  --title "AUTHENTIK TOKEN" \
  --inputbox "\nEnter Authentik Outpost Token\n(from Applications → Outposts → your LDAP outpost)" 12 58 \
  3>&1 1>&2 2>&3) || exit 1

# ── Im Container installieren ─────────────────────────────────────────────────
msg_info "Detecting Authentik Version"
AUTHENTIK_VERSION=$(curl -s "${AUTHENTIK_HOST}/api/v3/root/config/" | grep -oP '"authentik_version":"\K[^"]+' || echo "2026.2.2")
msg_ok "Version: ${AUTHENTIK_VERSION}"

msg_info "Installing Dependencies"
pct exec "$CTID" -- bash -c "
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -o Acquire::ForceIPv4=true -qq
  apt-get install -y -qq wget curl
" &>/dev/null
msg_ok "Dependencies Installed"

msg_info "Downloading Authentik LDAP Outpost Binary"
pct exec "$CTID" -- bash -c "
  wget -qO /usr/local/bin/authentik-ldap \
    'https://github.com/goauthentik/authentik/releases/download/version%2F${AUTHENTIK_VERSION}/authentik-outpost-ldap_linux_amd64'
  chmod +x /usr/local/bin/authentik-ldap
"
msg_ok "Binary Downloaded"

msg_info "Creating Config"
pct exec "$CTID" -- bash -c "
  mkdir -p /etc/authentik-ldap
  echo '${AUTHENTIK_HOST}' > /etc/authentik-ldap/host
"
msg_ok "Config Created"

msg_info "Creating Systemd Service"
pct exec "$CTID" -- bash -c "cat > /etc/systemd/system/authentik-ldap.service << EOF
[Unit]
Description=Authentik LDAP Outpost
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Environment=AUTHENTIK_HOST=${AUTHENTIK_HOST}
Environment=AUTHENTIK_INSECURE=true
Environment=AUTHENTIK_TOKEN=${AUTHENTIK_TOKEN}
ExecStart=/usr/local/bin/authentik-ldap
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable authentik-ldap
systemctl start authentik-ldap
"
msg_ok "Service Created and Started"

IP=$(pct exec "$CTID" -- hostname -I | awk '{print $1}')

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} LDAP Server running at:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}ldap://${IP}:3389${CL}"
echo -e "${TAB}${GATEWAY}${BGN}ldaps://${IP}:6636${CL}"
echo -e "${INFO}${YW} Base DN: DC=ldap,DC=goauthentik,DC=io${CL}"
