#!/bin/bash

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Run this script as root"
  exit 1
fi

# Configure static IP using netplan
NETPLAN="/etc/netplan/00-installer-config.yaml"
TARGET_IP="192.168.16.21/24"
if ! grep -q "$TARGET_IP" "$NETPLAN"; then
  sed -i '/^\s*addresses:/c\      addresses: [192.168.16.21/24]' "$NETPLAN"
  netplan apply
fi

# Update /etc/hosts
HOSTS="/etc/hosts"
grep -q "server1" "$HOSTS" && sed -i '/server1/d' "$HOSTS"
echo "192.168.16.21 server1" >> "$HOSTS"

# Install required packages
apt-get update
apt-get install -y apache2 squid

# Create users and configure SSH
USERS="dennis aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda"
EXTRA_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"

for USER in $USERS; do
  # Create user if missing, or enforce shell if exists
  if ! id "$USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$USER"
  else
    usermod -s /bin/bash "$USER"
  fi

  SSH_DIR="/home/$USER/.ssh"
  AUTH_KEYS="$SSH_DIR/authorized_keys"

  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  touch "$AUTH_KEYS"
  chmod 600 "$AUTH_KEYS"

  # Generate RSA key if missing
  if [ ! -f "$SSH_DIR/id_rsa.pub" ]; then
    sudo -u "$USER" ssh-keygen -t rsa -N "" -f "$SSH_DIR/id_rsa"
  fi

  # Generate ED25519 key if missing
  if [ ! -f "$SSH_DIR/id_ed25519.pub" ]; then
    sudo -u "$USER" ssh-keygen -t ed25519 -N "" -f "$SSH_DIR/id_ed25519"
  fi

  # Append keys only if not already present
  grep -qF "$(cat "$SSH_DIR/id_rsa.pub")" "$AUTH_KEYS" || cat "$SSH_DIR/id_rsa.pub" >> "$AUTH_KEYS"
  grep -qF "$(cat "$SSH_DIR/id_ed25519.pub")" "$AUTH_KEYS" || cat "$SSH_DIR/id_ed25519.pub" >> "$AUTH_KEYS"

  # Add instructor key for dennis if missing
  if [ "$USER" = "dennis" ]; then
    grep -qF "$EXTRA_KEY" "$AUTH_KEYS" || echo "$EXTRA_KEY" >> "$AUTH_KEYS"
    usermod -aG sudo dennis
  fi

  chown -R "$USER:$USER" "$SSH_DIR"
done
