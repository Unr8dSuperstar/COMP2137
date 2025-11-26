#!/bin/bash
# Assignment 03 - COMP2137
# Script: lab3.sh
# Covers: loghost setup, web host setup, verbose mode, error handling

# Enable verbose mode if passed
VERBOSE_FLAG=""
if [[ "$1" == "-verbose" ]]; then
    VERBOSE_FLAG="-verbose"
fi

# Define hostnames and IPs
declare -A HOSTS
HOSTS["server1-mgmt"]="loghost 192.168.16.3"
HOSTS["server2-mgmt"]="webhost 192.168.16.4"
HOSTS["server3-mgmt"]="dbhost 192.168.16.5"
HOSTS["server4-mgmt"]="cachehost 192.168.16.6"

# Function to test remote connectivity
test_connection() {
    ssh -o ConnectTimeout=5 remoteadmin@"$1" "echo connected" &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error: Cannot connect to $1"
        exit 1
    fi
}

# Deploy and configure each server
for HOST in "${!HOSTS[@]}"; do
    read -r NAME IP <<< "${HOSTS[$HOST]}"
    test_connection "$HOST"
    scp configure-host.sh remoteadmin@"$HOST":/root
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to copy script to $HOST"
        exit 1
    fi
    ssh remoteadmin@"$HOST" -- /root/configure-host.sh -name "$NAME" -ip "$IP" $VERBOSE_FLAG
    if [[ $? -ne 0 ]]; then
        echo "Error: Configuration failed on $HOST"
        exit 1
    fi

    # Add host entries for all other servers
    for OTHER in "${!HOSTS[@]}"; do
        if [[ "$OTHER" != "$HOST" ]]; then
            read -r OTHER_NAME OTHER_IP <<< "${HOSTS[$OTHER]}"
            ssh remoteadmin@"$HOST" -- /root/configure-host.sh -hostentry "$OTHER_NAME" "$OTHER_IP" $VERBOSE_FLAG
        fi
    done
done

# Update local /etc/hosts
for HOST in "${!HOSTS[@]}"; do
    read -r NAME IP <<< "${HOSTS[$HOST]}"
    ./configure-host.sh -hostentry "$NAME" "$IP" $VERBOSE_FLAG
done

# Final test summary
echo "All servers configured successfully."
