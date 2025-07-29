# DotnetDebug - Kubernetes Sidecar Debug Container

A lightweight debugging sidecar container for troubleshooting network connectivity, process behavior, .NET application diagnostics in Kubernetes pods. Specifically designed for debugging .NET client applications with shared diagnostic data via the `/tmp` diagnostics volume.

## 🚀 Quick Start

### As a Sidecar Container

```yaml
# Add to your deployment spec
- name: debug-sidecar
  image: ghcr.io/mortenduus/dotdebug:latest
  command: ["sleep", "infinity"]
  securityContext:
    capabilities:
      add: ["NET_ADMIN", "SYS_PTRACE", "NET_RAW"]
  volumeMounts:
  - name: diagnostics
    mountPath: /tmp
```

**Quick patch to existing deployment:**
```bash
kubectl patch deployment <your-deployment> --patch-file debug-sidecar-patch.yaml
```

### Standalone Debug Container

```bash
# Run standalone for external debugging
docker run -it --network host ghcr.io/mortenduus/dotdebug:latest

# Run in Kubernetes cluster
kubectl run debug-pod --image=ghcr.io/mortenduus/dotdebug:latest -it --rm
```

## 🛠️ Included Tools

### Network Debugging
- **tcpdump** - Network packet capture and analysis
- **nmap** - Network discovery and port scanning  
- **mtr** - Network diagnostic (traceroute + ping)
- **iperf3** - Network performance testing
- **netcat/socat** - Network connection utilities
- **dig/nslookup** - DNS resolution testing

### Process & System Debugging
- **strace** - System call tracing
- **lsof** - List open files and network connections
- **htop** - Interactive process viewer
- **ss/netstat** - Network connection monitoring

### .NET Application Debugging
- **.NET SDK** - Versions 6.0, 8.0, and 9.0
- **dotnet-counters** - Real-time performance counters
- **dotnet-dump** - Memory dump collection and analysis
- **dotnet-trace** - Performance event tracing

### Network & Service Mesh Debugging
- **Envoy proxy detection** - Automatic detection of Istio sidecars
- **Envoy admin access** - Access to proxy statistics and configuration (if available)
- **Service mesh connectivity testing**

## � .NET Application Diagnostics

This container is specifically designed for debugging .NET client applications running in the same pod. The key feature is the **shared `/tmp` diagnostics volume** that allows seamless data exchange between your .NET application and the debug sidecar.

### Shared Diagnostics Volume (`/tmp`)
The `/tmp` directory is mounted as an `emptyDir` volume shared between containers in the pod:
- **Your .NET app** can write diagnostic data, dumps, traces, and logs to `/tmp`
- **Debug sidecar** can access and analyze these files in real-time
- **Persistent across container restarts** within the pod lifecycle

### .NET Debugging Workflow
```bash
# 1. Collect performance counters from your .NET app
dotnet-counters collect -p $(pgrep -f "YourApp") -o /tmp/counters.csv

# 2. Create memory dumps for analysis
dotnet-dump collect -p $(pgrep -f "YourApp") -o /tmp/app-dump.dmp

# 3. Capture detailed execution traces
dotnet-trace collect -p $(pgrep -f "YourApp") -o /tmp/trace.nettrace

# 4. Analyze the collected data
ls -la /tmp/          # View all diagnostic files
head /tmp/counters.csv # Quick analysis of performance data
```

### Real-time .NET Application Monitoring
```bash
# Monitor live performance counters
dotnet-counters monitor -p $(pgrep -f "YourApp")

# Watch for garbage collection issues
dotnet-counters monitor -p $(pgrep -f "YourApp") --counters System.Runtime[gc-heap-size,gen-0-gc-count,gen-1-gc-count,gen-2-gc-count]

# Monitor HTTP client performance
dotnet-counters monitor -p $(pgrep -f "YourApp") --counters System.Net.Http
```

### Diagnostic Data Sharing Examples
```bash
# Your .NET application writes logs/dumps to /tmp
# Then access from debug sidecar:

# View application logs written to shared volume
tail -f /tmp/app-logs.txt

# Analyze heap dumps with dotnet-dump
dotnet-dump analyze /tmp/heap-dump.dmp

# Convert and analyze traces
dotnet-trace convert /tmp/app-trace.nettrace --format speedscope
```

## �📋 Debug Commands

### debug-sidecar
Comprehensive sidecar debugging information collector.

```bash
# Basic pod environment analysis  
debug-sidecar

# Test connectivity to specific service
debug-sidecar my-service.namespace.svc.cluster.local 8080

# Examples
debug-sidecar                                    # Full pod analysis
debug-sidecar api-gateway.istio-system 15000   # Test Istio gateway
debug-sidecar external-api.com 443             # Test external connectivity
```

### debug-network  
Network connectivity troubleshooting tool.

```bash
# Test network connectivity
debug-network [host] [port]

# Examples  
debug-network google.com 443
debug-network postgres.database 5432
debug-network my-service.default.svc.cluster.local 80
```

## 🔗 Built-in Aliases & Functions

### Quick Network Testing
```bash
test-port [host] [port]     # Quick port connectivity test
test-http [url]             # HTTP endpoint testing
myip                        # Show pod IP address
listen                      # Show listening ports
conns                       # Show active connections
ports                       # Show all ports with processes
listening                   # Show only listening ports
```

### .NET Application Debugging
```bash
dotnet-procs                # Show all .NET processes
dotnet-ports                # Show .NET network connections
dotnet-files                # Show files opened by .NET processes
tmp-files                   # List shared diagnostic files
monitor-dotnet [app-name]   # Live performance monitoring
dump-dotnet [app-name]      # Create memory dump to /tmp
trace-dotnet [app-name] [secs] # Execution tracing to /tmp
```

### System Resource Monitoring
```bash
psmem                       # Top memory consumers
pscpu                       # Top CPU consumers
diskspace                   # Disk space usage
diskusage                   # Directory sizes sorted
openfiles                   # Show open files
```

### Network/Envoy Debugging  
```bash
envoy-stats                 # Get Envoy proxy metrics (if available)
envoy-clusters              # Show Envoy cluster status (if available)
envoy-config                # Dump Envoy configuration (if available)
```

### Traffic Analysis
```bash
capture-traffic [host]      # Capture packets for specific host
trace-calls [pid]           # Trace system calls for process
netprocs                    # Show processes with network connections
```

## 💡 Common Sidecar Debugging Scenarios

### Pod Network Connectivity Issues
```bash
# Check if pod can reach external services
debug-sidecar google.com 443

# Test internal service connectivity  
debug-sidecar my-backend.default.svc.cluster.local 8080

# Capture traffic to troubleshoot connectivity
capture-traffic my-backend.default.svc.cluster.local
```

### Service Mesh Debugging
```bash
# Check if Envoy sidecar is present
debug-sidecar

# View Envoy proxy statistics (if Envoy is detected)
envoy-stats | grep -i error

# Check cluster health (if Envoy is detected)
envoy-clusters | jq '.[] | select(.health_status != "HEALTHY")'
```

### .NET Application Performance Issues
```bash
# Monitor live .NET application performance
dotnet-counters monitor -p $(pgrep -f "YourApp")

# Collect performance data to shared volume for analysis
dotnet-counters collect -p $(pgrep -f "YourApp") -o /tmp/perf-counters.csv

# Create memory dump for heap analysis
dotnet-dump collect -p $(pgrep -f "YourApp") -o /tmp/memory-dump.dmp

# Trace application execution and save to shared volume
dotnet-trace collect -p $(pgrep -f "YourApp") -o /tmp/execution-trace.nettrace

# Analyze network connections for .NET HTTP clients
netprocs | grep -f "YourApp"

# Monitor garbage collection performance
dotnet-counters monitor -p $(pgrep -f "YourApp") --counters System.Runtime[gc-heap-size,gen-0-gc-count,time-in-gc]
```

### .NET Client Application Debugging
```bash
# Debug HTTP client connectivity issues
dotnet-counters monitor -p $(pgrep -f "YourApp") --counters System.Net.Http

# Capture network traffic for HTTP debugging
capture-traffic api.external-service.com

# Analyze shared diagnostic files written by your app
ls -la /tmp/              # List all diagnostic files in shared volume
tail -f /tmp/app-logs.txt # Follow application logs in real-time
cat /tmp/config-dump.json # View configuration dumps

# Test connectivity to services your .NET app is calling
test-port database.service.local 5432
test-http https://api.external-service.com/health
```

### Application Performance Issues
```bash
# Trace application system calls
trace-calls $(pgrep MyApp)

# Monitor overall system resource usage
htop
```

### DNS and Service Discovery
```bash
# Test DNS resolution
debug-network my-service.namespace.svc.cluster.local

# Check available services via environment
debug-sidecar | grep SERVICE_HOST
```

## 📊 Sidecar Configuration Examples

### Quick Deployment Patch
Use the included patch file to add the debug sidecar to any existing deployment:

```bash
# Download the patch file
curl -O https://raw.githubusercontent.com/mortenduus/dotdebug/main/debug-sidecar-patch.yaml

# Apply to your deployment
kubectl patch deployment <your-deployment-name> --patch-file debug-sidecar-patch.yaml

# Verify the sidecar was added
kubectl get pods -l app=<your-app-label>

# Access the debug sidecar
kubectl exec -it <pod-name> -c debug-sidecar -- bash
```

### Manual Configuration

### Basic Sidecar with .NET Diagnostics
```yaml
- name: debug-sidecar
  image: ghcr.io/mortenduus/dotdebug:latest
  command: ["sleep", "infinity"]
  # Essential: Mount diagnostics volume for .NET debugging
  volumeMounts:
  - name: diagnostics
    mountPath: /tmp    # Shared diagnostic data location
  resources:
    limits:
      memory: "256Mi"  
      cpu: "200m"
```

**Note**: The `/tmp` volume mount is crucial for .NET application debugging as it provides a shared space where your .NET application can write diagnostic data (dumps, traces, logs) that the debug sidecar can then access and analyze.

### Advanced Sidecar with Network Debugging
```yaml
- name: debug-sidecar
  image: ghcr.io/mortenduus/dotdebug:latest
  command: ["sleep", "infinity"]
  securityContext:
    capabilities:
      add:
      - NET_ADMIN    # For tcpdump, traffic shaping
      - SYS_PTRACE   # For strace, process debugging  
      - NET_RAW      # For raw socket access
  volumeMounts:
  - name: diagnostics
    mountPath: /tmp
  resources:
    limits:
      memory: "512Mi"
      cpu: "300m"
```

### Persistent Debug Data Collection  
```yaml
- name: debug-sidecar
  image: ghcr.io/mortenduus/dotdebug:latest
  command: ["sleep", "infinity"]
  volumeMounts:
  - name: diagnostics
    mountPath: /tmp
  - name: debug-data
    mountPath: /debug-output
  # Note: Use a separate init container or cronjob for data collection
  # instead of overriding the main command
```

### Complete Pod Configuration with .NET App + Debug Sidecar
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dotnet-app-with-debug
spec:
  template:
    spec:
      containers:
      # Your main .NET application
      - name: main-app
        image: your-dotnet-app:latest
        volumeMounts:
        - name: diagnostics
          mountPath: /tmp    # Same mount point for shared diagnostics
        env:
        - name: DIAGNOSTIC_OUTPUT_PATH
          value: "/tmp"      # Configure your app to write diagnostics here
      
      # Debug sidecar container
      - name: debug-sidecar
        image: ghcr.io/mortenduus/dotdebug:latest
        command: ["sleep", "infinity"]
        volumeMounts:
        - name: diagnostics
          mountPath: /tmp    # Access diagnostic data from main app
        securityContext:
          capabilities:
            add: ["NET_ADMIN", "SYS_PTRACE", "NET_RAW"]
        resources:
          limits:
            memory: "256Mi"
            cpu: "200m"
      
      # Shared volume for diagnostic data exchange
      volumes:
      - name: diagnostics
        emptyDir: {}
```

### .NET Application Configuration
Configure your .NET application to write diagnostic data to the shared volume:

```csharp
// In your .NET application, write diagnostic data to /tmp
var diagnosticPath = Environment.GetEnvironmentVariable("DIAGNOSTIC_OUTPUT_PATH") ?? "/tmp";

// Example: Write performance logs
await File.WriteAllTextAsync(Path.Combine(diagnosticPath, "perf-metrics.json"), jsonData);

// Example: Configure logging to shared volume
builder.Logging.AddFile(Path.Combine(diagnosticPath, "app-logs.txt"));
```

## 🔧 Accessing the Sidecar

### kubectl exec into sidecar
```bash
# Access the debug sidecar
kubectl exec -it [pod-name] -c debug-sidecar -- bash

# Run debug commands
kubectl exec -it [pod-name] -c debug-sidecar -- debug-sidecar

# Capture traffic from outside the pod (saves to /tmp which is mounted)
kubectl exec -it [pod-name] -c debug-sidecar -- tcpdump -i any -w /tmp/capture.pcap
```

### Port forwarding for Envoy admin
```bash
# Forward Envoy admin port (if Envoy proxy is present)
kubectl port-forward [pod-name] 15000:15000

# Then access http://localhost:15000 for Envoy admin interface
```

## 🏗️ Building

```bash
git clone [repository]
cd DotDebug  
docker build -t dotdebug-sidecar .
```

## 🤝 Contributing

This tool is designed specifically for sidecar debugging scenarios. Contributions that enhance network debugging, process monitoring, and service mesh troubleshooting capabilities are welcome!
