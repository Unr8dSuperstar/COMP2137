#!/bin/bash

hostnamectl | awk -F: '/Static hostname/ {print "Hostname:" $2}' | sed 's/^[ \t]*//'

ip -4 addr show | awk '/inet/ && !/127.0.0.1/ {print "IP Address:" $2}' | cut -d/ -f1

ip route | awk '/default/ {print "Gateway IP:" $3}'

