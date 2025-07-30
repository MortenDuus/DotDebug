# DotDebug - Kubernetes Sidecar Debug Container

Lightweight debugging sidecar for troubleshooting network connectivity, process behavior, and .NET diagnostics in Kubernetes pods. Supports both volume-based debugging (via .NET diagnostic socket in `/tmp`) and process-level debugging with namespace sharing.

## Quick Start

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

**Quick scripts for existing deployment:**
```bash
# Volume-based debugging (recommended for production)
curl -O https://raw.githubusercontent.com/mortenduus/dotdebug/main/add-debug-sidecar.sh
chmod +x add-debug-sidecar.sh
./add-debug-sidecar.sh <your-deployment> [namespace]

# Process-level debugging (development/staging only)
./add-debug-sidecar.sh --share-process-namespace <your-deployment> [namespace]

# Remove debug sidecar
curl -O https://raw.githubusercontent.com/mortenduus/dotdebug/main/remove-debug-sidecar.sh
chmod +x remove-debug-sidecar.sh
./remove-debug-sidecar.sh <your-deployment> [namespace]
```

**Alternative: YAML patch method:**
```bash
kubectl patch deployment <your-deployment> --patch-file debug-sidecar-patch.yaml
```

**Standalone debugging:**
```bash
# Run standalone for external debugging
docker run -it --network host ghcr.io/mortenduus/dotdebug:latest

# Run in Kubernetes cluster
kubectl run debug-pod --image=ghcr.io/mortenduus/dotdebug:latest -it --rm
```

## Included Tools

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

### Service Mesh Debugging
- **Envoy proxy detection** - Automatic detection of Istio sidecars
- **Envoy admin access** - Access to proxy statistics and configuration
- **Service mesh connectivity testing**

## Debugging Modes

The debug sidecar supports two modes to balance security and debugging capabilities:

### Volume-based (Default) - Secure Mode
- Uses shared volume for .NET diagnostic socket access
- Maintains container isolation
- Recommended for production environments
```bash
./add-debug-sidecar.sh my-app production
```

### Process namespace sharing - Enhanced Mode  
- Direct access to .NET processes across containers
- Enhanced debugging capabilities
- Development/staging environments only
```bash
./add-debug-sidecar.sh --share-process-namespace my-app staging
```

**When to use each mode:**
- **Volume-based**: Production, security/compliance requirements, sufficient diagnostics via shared volume
- **Process sharing**: Development/staging, real-time process monitoring, advanced debugging scenarios

## .NET Diagnostics

This container provides debugging capabilities for .NET applications via shared `/tmp` volume access to the .NET diagnostic socket.

### Volume-based Debugging (Recommended)
The `/tmp` directory is mounted as a shared volume between containers:
- Your .NET app exposes diagnostic socket in `/tmp` (automatic)
- Debug sidecar accesses diagnostic capabilities via the socket
- Maintains container isolation while enabling full .NET debugging

```bash
# List .NET processes via diagnostic socket
dotnet-counters ps

# Live performance monitoring
dotnet-counters monitor -p <process-id> --refresh-interval 1

# Create memory dumps  
dotnet-dump collect -p <process-id> -o /tmp/dump.dmp

# Execution tracing
dotnet-trace collect -p <process-id> -o /tmp/trace.nettrace

# Analyze collected data
dotnet-dump analyze /tmp/dump.dmp
dotnet-trace convert /tmp/trace.nettrace --format speedscope
```

### Application Integration
Configure your .NET application to write diagnostic data to the shared volume:

```csharp
// Write performance metrics to shared volume
var diagnosticPath = Environment.GetEnvironmentVariable("DIAGNOSTIC_OUTPUT_PATH") ?? "/tmp";
var metricsFile = Path.Combine(diagnosticPath, "perf-metrics.json");
await File.WriteAllTextAsync(metricsFile, JsonSerializer.Serialize(metrics));

// Configure logging to shared volume
builder.Logging.AddFile(Path.Combine(diagnosticPath, "app-logs.txt"));
```

### Process namespace sharing (Enhanced Mode)
For development/staging environments, process namespace sharing enables direct process monitoring:

```bash
# Identify .NET processes
dotnet-counters ps

# Real-time HTTP client monitoring
monitor-dotnet MyApp
netmon MyApp          # All network counters
httpmon MyApp         # HTTP client only
```

## Built-in Commands

### Network Testing
```bash
test-port [host] [port]     # Quick port connectivity test
test-http [url]             # HTTP endpoint testing
debug-network [host] [port] # Network connectivity tests
debug-sidecar [host] [port] # Full pod debug info
myip                        # Show pod IP address
listen                      # Show listening ports
conns                       # Show active connections
```

### .NET Debugging (Volume-based)
```bash
tmp-files                   # List shared diagnostic files in /tmp
analyze-latest-dump         # Analyze newest .NET dump
watch-diagnostic-files      # Monitor diagnostic files
show-diagnostic-summary     # Overview of all diagnostic files
```

### .NET Debugging (Process sharing mode)
```bash
dotnet-procs                # Show .NET processes
monitor-dotnet [app]        # Live performance monitoring
dump-dotnet [app]           # Create memory dump
trace-dotnet [app]          # Execution tracing
netmon [app]                # All network counters
httpmon [app]               # HTTP client monitoring
```

### Load Testing
```bash
loadtest-quick [url]        # Quick 10 user load test
loadtest-edit               # Edit Artillery template
loadtest-run                # Run configured load test
```

### System Monitoring
```bash
psmem                       # Top memory consumers
netprocs                    # Processes with network connections
diskspace                   # Disk space usage
```

## Common Scenarios

### Network Connectivity Issues
```bash
# Test external service connectivity
debug-sidecar google.com 443

# Test internal service connectivity  
debug-sidecar my-backend.default.svc.cluster.local 8080

# Capture traffic for troubleshooting
capture-traffic my-backend.default.svc.cluster.local
```

### Service Mesh Debugging
```bash
# Check if Envoy sidecar is present and view statistics
debug-sidecar
envoy-stats | grep -i error
envoy-clusters | jq '.[] | select(.health_status != "HEALTHY")'
```

### .NET Application Issues (Volume-based)
```bash
# View diagnostic files written by your app
show-diagnostic-summary
analyze-latest-dump
tail -f /tmp/app-logs.txt

# Test connectivity to services your app calls
test-port database.service.local 5432
test-http https://api.external-service.com/health
```

### .NET HTTP Client Issues (Process sharing mode)
```bash
# Real-time HTTP client monitoring
monitor-dotnet MyApp
httpmon MyApp

# Specific troubleshooting
DOTNET_PID=$(dotnet-counters ps | tail -n +2 | head -1 | awk '{print $1}')
dotnet-counters monitor -p $DOTNET_PID --counters \
  System.Net.Http[requests-failed-rate,current-connections]
```

## Usage Example

### Quick Deployment Patch
Use the included patch file to add the debug sidecar to any existing deployment:

```bash
# Download the scripts
curl -O https://raw.githubusercontent.com/mortenduus/dotdebug/main/add-debug-sidecar.sh
curl -O https://raw.githubusercontent.com/mortenduus/dotdebug/main/remove-debug-sidecar.sh
chmod +x add-debug-sidecar.sh remove-debug-sidecar.sh

# Add to your deployment
./add-debug-sidecar.sh <your-deployment-name> [namespace]

# Wait for rollout to complete
kubectl rollout status deployment/my-web-app -n production

# Access the debug sidecar
kubectl exec -it <pod-name> -c debug-sidecar -- zsh

# Remove the debug sidecar when done
./remove-debug-sidecar.sh <your-deployment-name> [namespace]
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

**Note**: The `/tmp` volume mount is crucial for .NET application debugging as it provides a shared space where your .NET application can write diagnostic data (dumps, traces, logs) that the debug sidecar can then access and analyze. If not set, then process must shared namespace 

## 🤝 Contributing

This tool is designed specifically for sidecar debugging scenarios. Contributions that enhance network debugging, process monitoring, and service mesh troubleshooting capabilities are welcome!
