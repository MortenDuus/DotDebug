#!/bin/bash

# Network Connectivity Debug Script for Sidecar Containers
# Usage: ./debug-network.sh [target-host] [target-port]

TARGET_HOST=${1:-google.com}
TARGET_PORT=${2:-443}

echo "Network Connectivity Debug"
echo "============================="
echo "Target: $TARGET_HOST:$TARGET_PORT"
echo "Timestamp: $(date)"
echo ""

echo "Basic Connectivity Tests:"
echo "----------------------------"

# Ping test
echo "Ping test to $TARGET_HOST:"
ping -c 4 $TARGET_HOST
echo ""

# DNS resolution
echo "DNS Resolution:"
nslookup $TARGET_HOST
echo ""
dig $TARGET_HOST
echo ""

# Port connectivity
echo "Port Connectivity Test:"
if command -v telnet &> /dev/null; then
    timeout 5 telnet $TARGET_HOST $TARGET_PORT
else
    timeout 5 nc -zv $TARGET_HOST $TARGET_PORT
fi
echo ""

# Traceroute
echo "Network Path (traceroute):"
traceroute $TARGET_HOST
echo ""

# MTR for better network diagnostics
echo "MTR Network Report:"
mtr --report --report-cycles 10 $TARGET_HOST
echo ""

# Check local networking
echo "Local Network Configuration:"
echo "------------------------------"
echo "Routing table:"
ip route show
echo ""

echo "Network interfaces:"
ip addr show
echo ""

echo "ARP table:"
arp -a
echo ""

echo "Network statistics:"
ss -tuln
echo ""

echo "Network debugging complete"
