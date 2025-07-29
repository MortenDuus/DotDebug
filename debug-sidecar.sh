#!/bin/bash

# Sidecar Container Debug Information Gatherer
# Usage: ./debug-sidecar.sh [target-host] [target-port]

echo "======================================"
echo "🔍 Sidecar Container Debug Information"
echo "======================================"
echo "Timestamp: $(date)"
echo "Container: $(hostname)"
echo "Pod IP: $(hostname -i 2>/dev/null || echo 'Unknown')"
echo ""

TARGET_HOST=${1:-}
TARGET_PORT=${2:-}

echo "� Container Environment:"
echo "------------------------"
echo "Environment variables:"
env | grep -E "(KUBERNETES_|SERVICE_|POD_|NAMESPACE)" | sort
echo ""

echo "� Mounted Volumes:"
echo "------------------"
df -h
echo ""

echo "� Process Information:"
echo "----------------------"
echo "Running processes:"
ps aux --width=200
echo ""

echo "📡 Network Services:"
echo "-------------------"
echo "Listening ports in this container:"
netstat -tlnp 2>/dev/null || ss -tlnp
echo ""

echo "🌐 Service Discovery:"
echo "--------------------"
echo "Available services (via environment):"
env | grep "_SERVICE_HOST" | sort
echo ""

echo "🔍 DNS and Service Mesh Detection:"
echo "----------------------------------"
echo "DNS servers:"
cat /etc/resolv.conf | grep nameserver
echo ""

echo "Checking for Istio sidecar:"
if netstat -tlnp 2>/dev/null | grep -q ":15000\|:15001\|:15006\|:15090"; then
    echo "✅ Istio Envoy proxy detected (ports 15000/15001/15006/15090 in use)"
    echo ""
    echo "Envoy admin interface (if accessible):"
    curl -s http://localhost:15000/stats/prometheus | head -20 2>/dev/null || echo "❌ Envoy admin not accessible"
    echo ""
    echo "Envoy clusters:"
    curl -s http://localhost:15000/clusters 2>/dev/null | head -20 || echo "❌ Envoy clusters not accessible"
else
    echo "❌ No Istio Envoy proxy detected"
fi
echo ""

echo "🌐 Network Information:"
echo "-----------------------"
echo "Network interfaces and IPs:"
ip addr show
echo ""

echo "Routing table:"
ip route show
echo ""

echo "ARP table (neighboring pods/services):"
arp -a 2>/dev/null || ip neigh show
echo ""

echo "Active network connections:"
netstat -tuln 2>/dev/null || ss -tuln
echo ""

if [ ! -z "$TARGET_HOST" ]; then
    echo "🔍 Connectivity Test to: $TARGET_HOST"
    if [ ! -z "$TARGET_PORT" ]; then
        echo "Testing: $TARGET_HOST:$TARGET_PORT"
        echo "------------------------"
    else
        echo "Testing: $TARGET_HOST (ping only)"
        echo "-------------------------"
    fi
    
    echo "📡 DNS Resolution:"
    nslookup $TARGET_HOST 2>/dev/null || echo "❌ nslookup failed"
    echo ""
    
    echo "📡 Ping test:"
    ping -c 3 $TARGET_HOST 2>/dev/null || echo "❌ Ping failed"
    echo ""
    
    if [ ! -z "$TARGET_PORT" ]; then
        echo "🔌 Port connectivity:"
        timeout 5 nc -zv $TARGET_HOST $TARGET_PORT 2>&1 || echo "❌ Port $TARGET_PORT not reachable"
        echo ""
        
        echo "🛣️  Traceroute:"
        traceroute $TARGET_HOST 2>/dev/null || echo "❌ Traceroute not available"
        echo ""
    fi
fi

echo "🔍 System Resources:"
echo "-------------------"
echo "Memory usage:"
free -h
echo ""
echo "Disk usage:"
df -h
echo ""
echo "CPU usage:"
top -bn1 | head -15
echo ""

echo "📊 Application Processes:"
echo "------------------------"
echo ".NET processes:"
ps aux | grep -i dotnet | grep -v grep || echo "No .NET processes found"
echo ""

echo "Node.js processes:"
ps aux | grep -i node | grep -v grep || echo "No Node.js processes found"
echo ""

echo "📊 Shared Diagnostic Files:"
echo "---------------------------"
echo "Files in /tmp (shared volume):"
ls -la /tmp/ 2>/dev/null || echo "No files in /tmp"
echo ""

echo "Open files and network connections:"
lsof -i 2>/dev/null | head -20 || echo "lsof not available"
echo ""

echo "🔧 Container Health Checks:"
echo "---------------------------"
echo "Recent system messages:"
dmesg | tail -10 2>/dev/null || echo "dmesg not available"
echo ""

echo "Available commands for deeper debugging:"
echo "---------------------------------------"
echo "• tcpdump -i any -n 'host TARGET_IP'    - Capture network traffic"
echo "• strace -p PID                         - Trace system calls"
echo "• netstat -tlnp                         - Show listening ports"
echo "• lsof -p PID                          - Show files opened by process"
echo "• ss -tuln                             - Modern netstat alternative"
echo "• curl -v http://service:port/health    - Test HTTP endpoints"
echo ""
echo "Load Testing & Performance:"
echo "• artillery quick --count 10 --num 2 http://service:port/  - Quick load test"
echo "• artillery run /root/artillery-loadtest.yaml    - Run pre-configured load test"
echo "• loadtest-edit                         - Edit the included load test template"
echo "• loadtest [url] [users] [duration]    - Create custom load test"
echo "• micro /tmp/config.yaml               - Edit YAML files with syntax highlighting"
echo "• yaml-cli validate /tmp/file.yaml     - Validate YAML syntax"
echo "• prettyjson /tmp/response.json        - Pretty print JSON"
echo ""

echo "======================================"
echo "✅ Sidecar debug information complete"
echo "======================================"
