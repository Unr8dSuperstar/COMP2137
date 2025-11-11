#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this script as root"
  exit 1
  fi
  
NETPLAN="/etc/netplan/00-installer-config.yaml"
TARGET_IP="192.168.16.21/24"
HOSTS="/etc/hosts"

if ! grep -q "$TARGET_IP" "$NETPLAN"; then
  sed -i '/addresses:/c\      addresses: [192.168.16.21/24]' "$NETPLAN"
  netplan apply
  
fi

sed -i '/server1/d' "$HOSTS"
echo "192.168.16.21 server1" >> "$HOSTS"

apt-get update
apt-get install -y apache2 squid

USERS="dennis aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda"
EXTRA_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI curtis@generic-vm"

for USER in $USERS; do
  if ! id "$USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$USER"
  fi
  
  mkdir -p /home/"$USER"/.ssh
  chmod 700 /home/"$USER"/.ssh
  touch /home/"$USER"/.ssh/authorized_keys
  chmod 600 /home/"$USER"/.ssh/authorized_keys
  
  if [ "$USER" = "dennis" ]; then
    usermod -aG sudo dennis
    grep -qF "$EXTRA_KEY" /home/dennis/.ssh/authorized_keys || echo "$EXTRA_KEY" >> /home/dennis/.ssh/authorized_keys
  fi
  
  if [ ! -f /home/"$USER"/.ssh/id_rsa.pub ]; then
    sudo -u "$USER" ssh-keygen -t rsa -N "" -f /home/"$USER"/.ssh/id_rsa
  fi
  
  if [ ! -f /home/"$USER"/.ssh/id_ed25519.pub ]; then
    sudo -u "$USER" ssh-keygen -t ed25519 -N "" -f /home/"$USER"/.ssh/id_ed25519
  fi
  
  grep -qF "$(cat /home/"$USER"/.ssh/id_rsa.pub)" /home/"$USER"/.ssh/authorized_keys || cat /home/"$USER"/.ssh/id_rsa.pub >> /home/"$USER"/.ssh/authorized_keys
  grep -qF "$(cat /home/"$USER"/.ssh/id_ed25519.pub)" /home/"$USER"/.ssh/authorized_keys || cat /home/"$USER"/.ssh/id_ed25519.pub >> /home/"$USER"/.ssh/authorized_keys
  
  chown -R "$USER":"$USER" /home/"$USER"/.ssh
done
