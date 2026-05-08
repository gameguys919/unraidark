#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Author: gameguys919
# License: GPL 3.0
# Source: https://www.adminer.org

APP="adminer"
var_tags="${var_tags:-adminer;database}"
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
  if [[ ! -f /var/www/adminer/adminer.php ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Updating Adminer"
  wget -qO /var/www/adminer/adminer.php https://www.adminer.org/latest.php
  if [[ $? -ne 0 ]]; then
    msg_error "Could not download latest Adminer."
    exit 1
  fi
  msg_ok "Updated to latest version"
  msg_info "Restarting nginx"
  systemctl restart nginx
  msg_ok "Restarted nginx"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

# ── Port abfragen ─────────────────────────────────────────────────────────────
ADMINER_PORT=$(whiptail --backtitle "Proxmox VE Helper Scripts" \
  --title "ADMINER PORT" \
  --inputbox "\nEnter port for Adminer Web UI\n(default: 8080)" 12 58 "8080" \
  3>&1 1>&2 2>&3) || exit 1

# ── Im Container installieren ─────────────────────────────────────────────────
msg_info "Installing Dependencies"
pct exec "$CTID" -- bash -c "
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -o Acquire::ForceIPv4=true -qq

  # PHP Version dynamisch ermitteln
  PHP_VERSION=\$(apt-cache search --names-only '^php[0-9]+\.[0-9]+-fpm$' \
    | grep -oP 'php\K[0-9]+\.[0-9]+' | sort -V | tail -1)

  apt-get install -y -qq wget curl nginx \
    php\${PHP_VERSION}-fpm \
    php\${PHP_VERSION}-mysql \
    php\${PHP_VERSION}-pgsql \
    php\${PHP_VERSION}-sqlite3 \
    php\${PHP_VERSION}-mbstring
" &>/dev/null
msg_ok "Dependencies Installed"

msg_info "Downloading Adminer"
pct exec "$CTID" -- bash -c "
  mkdir -p /var/www/adminer
  wget -qO /var/www/adminer/adminer.php https://www.adminer.org/latest.php
  if [[ \$? -ne 0 ]]; then
    echo 'Could not download Adminer!'
    exit 1
  fi
" &>/dev/null
msg_ok "Adminer Downloaded"

msg_info "Configuring nginx"
pct exec "$CTID" -- bash -c "
  PHP_VERSION=\$(apt-cache search --names-only '^php[0-9]+\.[0-9]+-fpm$' \
    | grep -oP 'php\K[0-9]+\.[0-9]+' | sort -V | tail -1)

  cat > /etc/nginx/sites-available/adminer << EOF
server {
    listen ${ADMINER_PORT};
    server_name _;
    root /var/www/adminer;
    index adminer.php;

    location / {
        try_files \\\$uri \\\$uri/ /adminer.php\\\$is_args\\\$args;
    }

    location ~ \\.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php\${PHP_VERSION}-fpm.sock;
    }
}
EOF

  ln -sf /etc/nginx/sites-available/adminer /etc/nginx/sites-enabled/adminer
  rm -f /etc/nginx/sites-enabled/default
  systemctl enable nginx php\${PHP_VERSION}-fpm &>/dev/null
  systemctl restart php\${PHP_VERSION}-fpm
  systemctl restart nginx
" &>/dev/null
msg_ok "nginx Configured"

msg_info "Setting up Auto-Login"
pct exec "$CTID" -- bash -c "
  mkdir -p /etc/systemd/system/container-getty@1.service.d/
  cat > /etc/systemd/system/container-getty@1.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I \$TERM
EOF
  systemctl daemon-reload
" &>/dev/null
msg_ok "Auto-Login Configured"

IP=$(pct exec "$CTID" -- hostname -I | awk '{print $1}')

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Adminer Web UI available at:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:${ADMINER_PORT}/adminer.php${CL}"
echo -e "${INFO}${YW} Supported databases: MySQL/MariaDB, PostgreSQL, SQLite${CL}"
