#!/usr/bin/env bash

# Authentik LDAP Outpost - Proxmox LXC Installer
# Inspired by community-scripts/ProxmoxVE
# Usage: bash -c "$(wget -qLO - https://...)"

set -euo pipefail

# ─── Farben ───────────────────────────────────────────────────────────────────
YW="\033[33m"
GN="\033[1;92m"
RD="\033[01;31m"
CL="\033[m"
BFR="\\r\\033[K"
HOLD=" "
CM="${GN}✔${CL}"
CROSS="${RD}✗${CL}"

# ─── Hilfsfunktionen ──────────────────────────────────────────────────────────
msg_info()  { local msg="$1"; echo -ne " ${HOLD} ${YW}${msg}...${CL}"; }
msg_ok()    { local msg="$1"; echo -e "${BFR} ${CM} ${GN}${msg}${CL}"; }
msg_error() { local msg="$1"; echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"; exit 1; }

# ─── Nur auf Proxmox Host ausführen ───────────────────────────────────────────
if [ ! -f /etc/pve/version ]; then
  msg_error "Dieses Script muss auf dem Proxmox Host ausgeführt werden!"
fi

# ─── Konfiguration abfragen ───────────────────────────────────────────────────
echo -e "\n${YW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
echo -e "${GN}        Authentik LDAP Outpost - LXC Installer${CL}"
echo -e "${YW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}\n"

read -rp " Authentik URL (z.B. http://192.168.20.101:9000): " AUTHENTIK_HOST
read -rp " Authentik Token (aus Outpost-Seite): " AUTHENTIK_TOKEN
read -rp " Container IP/CIDR (z.B. 192.168.20.103/24): " CT_IP
read -rp " Gateway (z.B. 192.168.20.1): " CT_GW
read -rp " VLAN Tag (leer = kein VLAN): " CT_VLAN
read -rp " Container ID (z.B. 110): " CT_ID
read -rp " Hostname (z.B. authentik-ldap): " CT_HOSTNAME
read -rp " Storage (z.B. local-lvm): " CT_STORAGE
read -rp " Node (z.B. nd01): " CT_NODE

CT_VLAN_OPT=""
if [ -n "$CT_VLAN" ]; then
  CT_VLAN_OPT=",tag=${CT_VLAN}"
fi

# ─── Authentik Version ermitteln ──────────────────────────────────────────────
msg_info "Ermittle Authentik Version"
AUTHENTIK_VERSION=$(curl -s "${AUTHENTIK_HOST}/api/v3/root/config/" | grep -oP '"authentik_version":"\K[^"]+' || echo "2026.2.2")
msg_ok "Version: ${AUTHENTIK_VERSION}"

BINARY_URL="https://github.com/goauthentik/authentik/releases/download/version%2F${AUTHENTIK_VERSION}/authentik-outpost-ldap_linux_amd64"

# ─── Debian 12 Template herunterladen ─────────────────────────────────────────
msg_info "Suche Debian 12 Template"
TEMPLATE=$(pveam available --section system | grep "debian-12" | tail -1 | awk '{print $2}')
if [ -z "$TEMPLATE" ]; then
  msg_error "Kein Debian 12 Template gefunden!"
fi

STORAGE_TYPE=$(pvesm status -storage "$CT_STORAGE" | awk 'NR>1 {print $2}')
if [ "$STORAGE_TYPE" = "dir" ] || [ "$STORAGE_TYPE" = "nfs" ]; then
  TEMPLATE_PATH="/var/lib/vz/template/cache/${TEMPLATE}"
else
  TEMPLATE_PATH="${CT_STORAGE}:vztmpl/${TEMPLATE}"
fi

if [ ! -f "/var/lib/vz/template/cache/${TEMPLATE}" ]; then
  msg_info "Lade Template herunter"
  pveam download local "$TEMPLATE" >/dev/null 2>&1
  msg_ok "Template heruntergeladen"
else
  msg_ok "Template bereits vorhanden"
fi

# ─── LXC Container erstellen ──────────────────────────────────────────────────
msg_info "Erstelle LXC Container ${CT_ID}"
pct create "$CT_ID" "local:vztmpl/${TEMPLATE}" \
  --hostname "$CT_HOSTNAME" \
  --cores 1 \
  --memory 256 \
  --swap 0 \
  --rootfs "${CT_STORAGE}:2" \
  --net0 "name=eth0,bridge=vmbr0,ip=${CT_IP},gw=${CT_GW}${CT_VLAN_OPT}" \
  --unprivileged 1 \
  --features nesting=0 \
  --onboot 1 \
  --start 0 \
  >/dev/null 2>&1
msg_ok "Container ${CT_ID} erstellt"

# ─── Container starten ────────────────────────────────────────────────────────
msg_info "Starte Container"
pct start "$CT_ID"
sleep 5
msg_ok "Container gestartet"

# ─── Pakete installieren ──────────────────────────────────────────────────────
msg_info "Installiere Abhängigkeiten"
pct exec "$CT_ID" -- bash -c "
  apt-get update -qq >/dev/null 2>&1
  apt-get install -y -qq wget curl >/dev/null 2>&1
"
msg_ok "Abhängigkeiten installiert"

# ─── Binary herunterladen ─────────────────────────────────────────────────────
msg_info "Lade Authentik LDAP Outpost Binary herunter (${AUTHENTIK_VERSION})"
pct exec "$CT_ID" -- bash -c "
  wget -qO /usr/local/bin/authentik-ldap '${BINARY_URL}'
  chmod +x /usr/local/bin/authentik-ldap
"
msg_ok "Binary heruntergeladen"

# ─── Systemd Service erstellen ────────────────────────────────────────────────
msg_info "Erstelle Systemd Service"
pct exec "$CT_ID" -- bash -c "cat > /etc/systemd/system/authentik-ldap.service << EOF
[Unit]
Description=Authentik LDAP Outpost
After=network.target
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

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable authentik-ldap >/dev/null 2>&1
systemctl start authentik-ldap
"
msg_ok "Service erstellt und gestartet"

# ─── Status prüfen ────────────────────────────────────────────────────────────
sleep 3
STATUS=$(pct exec "$CT_ID" -- systemctl is-active authentik-ldap 2>/dev/null || echo "unknown")

echo -e "\n${YW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}"
if [ "$STATUS" = "active" ]; then
  echo -e " ${CM} ${GN}Authentik LDAP Outpost erfolgreich installiert!${CL}"
else
  echo -e " ${CROSS} ${RD}Service Status: ${STATUS} - prüfe Logs mit:${CL}"
  echo -e "   pct exec ${CT_ID} -- journalctl -u authentik-ldap -n 30"
fi
echo -e "\n ${YW}LDAP Server läuft auf:${CL}"
echo -e "   ${GN}ldap://$(echo $CT_IP | cut -d'/' -f1):3389${CL}"
echo -e "   ${GN}ldaps://$(echo $CT_IP | cut -d'/' -f1):6636${CL}"
echo -e "\n ${YW}Base DN:${CL} ${GN}DC=ldap,DC=goauthentik,DC=io${CL}"
echo -e "${YW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CL}\n"
