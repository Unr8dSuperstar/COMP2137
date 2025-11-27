#!/bin/bash

# Covers: hostname, IP, host entry, verbose option, syslog logging, error handling

# -------------------------------------------------------------------
# Termination signals
# The script ignores TERM, HUP, and INT signals so it cannot be
# accidentally stopped mid‑execution while making critical changes.
# -------------------------------------------------------------------
trap '' TERM HUP INT

# -------------------------------------------------------------------
# Command line arguments to be accepted:
#
# -verbose
#     Enables verbose output while the script runs
#
# -name desiredName
#     Confirms the host has the desired name, updating /etc/hostname
#     and /etc/hosts if necessary, and applies the change live
#
# -ip desiredIPAddress
#     Confirms the host's LAN interface has the desired IP address,
#     updating /etc/hosts and the netplan file if necessary, and
#     applies the change live
#
# -hostentry desiredName desiredIPAddress
#     Confirms the host entry exists in /etc/hosts, updating or
#     adding it if necessary
# -------------------------------------------------------------------

VERBOSE=0
HOSTNAME=""
IPADDR=""
HOSTENTRY_NAME=""
HOSTENTRY_IP=""

# -------------------------------------------------------------------
# Parse arguments
# -------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -verbose) VERBOSE=1; shift ;;
        -name) HOSTNAME="$2"; shift 2 ;;
        -ip) IPADDR="$2"; shift 2 ;;
        -hostentry) HOSTENTRY_NAME="$2"; HOSTENTRY_IP="$3"; shift 3 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# -------------------------------------------------------------------
# Logging function
# Logs changes to system log and echoes them if verbose mode is enabled
# -------------------------------------------------------------------
log_change() {
    logger "$1"
    if [[ $VERBOSE -eq 1 ]]; then
        echo "$1"
    fi
}

# -------------------------------------------------------------------
# Error checking function
# Exits with error message if last command failed
# -------------------------------------------------------------------
test_success() {
    if [[ $? -ne 0 ]]; then
        echo "Error: $1"
        exit 1
    fi
}

# -------------------------------------------------------------------
# Hostname update logic (-name)
# Confirms and applies hostname changes, updates /etc/hostname and /etc/hosts
# -------------------------------------------------------------------
if [[ -n "$HOSTNAME" ]]; then
    CURRENT_HOSTNAME=$(hostname)
    if [[ "$CURRENT_HOSTNAME" != "$HOSTNAME" ]]; then
        echo "$HOSTNAME" > /etc/hostname
        test_success "Failed to write /etc/hostname"
        hostnamectl set-hostname "$HOSTNAME"
        test_success "Failed to apply hostname"
        sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts
        test_success "Failed to update /etc/hosts"
        log_change "Hostname changed from $CURRENT_HOSTNAME to $HOSTNAME"
    elif [[ $VERBOSE -eq 1 ]]; then
        echo "Hostname already set to $HOSTNAME"
    fi
fi

# -------------------------------------------------------------------
# IP address update logic (-ip) — FIXED
# Confirms and applies IP changes, updates netplan and /etc/hosts safely
# -------------------------------------------------------------------
if [[ -n "$IPADDR" ]]; then
    INTERFACE=$(ip route | awk '/default/ {print $5; exit}')
    CURRENT_IP=$(ip -4 addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d/ -f1)
    CURRENT_CIDR=$(ip -4 addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d/ -f2)

    if [[ "$CURRENT_IP" != "$IPADDR" ]]; then
        # Safe netplan update
        netplan set "network.ethernets.${INTERFACE}.addresses=[${IPADDR}/${CURRENT_CIDR}]"
        test_success "Failed to set netplan address"

        netplan generate
        test_success "Netplan generate failed"

        netplan apply
        test_success "Failed to apply netplan"

        # Update /etc/hosts safely
        if grep -q "$(hostname)" /etc/hosts; then
            sed -i "s/^.*$(hostname)\$/${IPADDR}\t$(hostname)/" /etc/hosts
        else
            echo -e "${IPADDR}\t$(hostname)" >> /etc/hosts
        fi

        ip addr flush dev "$INTERFACE"
        ip addr add "${IPADDR}/${CURRENT_CIDR}" dev "$INTERFACE"
        ip link set "$INTERFACE" up

        log_change "IP address changed from $CURRENT_IP to $IPADDR/${CURRENT_CIDR} on $INTERFACE"
    elif [[ $VERBOSE -eq 1 ]]; then
        echo "IP address already set to $IPADDR"
    fi
fi

# -------------------------------------------------------------------
# Host entry update logic (-hostentry)
# Confirms entry exists in /etc/hosts, updates or adds if necessary
# -------------------------------------------------------------------
if [[ -n "$HOSTENTRY_NAME" && -n "$HOSTENTRY_IP" ]]; then
    if grep -q "$HOSTENTRY_NAME" /etc/hosts; then
        CURRENT_ENTRY=$(grep "$HOSTENTRY_NAME" /etc/hosts | awk '{print $1}')
        if [[ "$CURRENT_ENTRY" != "$HOSTENTRY_IP" ]]; then
            sed -i "s/^.*$HOSTENTRY_NAME\$/$HOSTENTRY_IP\t$HOSTENTRY_NAME/" /etc/hosts
            log_change "Updated host entry for $HOSTENTRY_NAME to $HOSTENTRY_IP"
        elif [[ $VERBOSE -eq 1 ]]; then
            echo "Host entry for $HOSTENTRY_NAME already correct"
        fi
    else
        echo -e "$HOSTENTRY_IP\t$HOSTENTRY_NAME" >> /etc/hosts
        test_success "Failed to add host entry"
        log_change "Added host entry: $HOSTENTRY_NAME -> $HOSTENTRY_IP"
    fi
fi
