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

**Quick scripts for existing deployment:**
```bash
# Secure mode: Volume-based debugging (recommended)
curl -O https://raw.githubusercontent.com/mortenduus/dotdebug/main/add-debug-sidecar.sh
chmod +x add-debug-sidecar.sh
./add-debug-sidecar.sh <your-deployment> [namespace]

# Enhanced mode: Process-level debugging (development/staging)
./add-debug-sidecar.sh --share-process-namespace <your-deployment> [namespace]

# Remove debug sidecar (automatically detects mode and cleans up appropriately)
curl -O https://raw.githubusercontent.com/mortenduus/dotdebug/main/remove-debug-sidecar.sh
chmod +x remove-debug-sidecar.sh
./remove-debug-sidecar.sh <your-deployment> [namespace]
```

> **Recommended:** The scripts provide validation, error handling, and consistent experience for production use.

**Alternative: YAML patch method:**
```bash
kubectl patch deployment <your-deployment> --patch-file debug-sidecar-patch.yaml
```

> **When to use scripts vs YAML patch:**  
> • **Scripts:** Production environments, CI/CD pipelines, team use (validation + error handling)  
> • **YAML patch:** One-off debugging, environments where downloading scripts isn't preferred

**Remove debug sidecar from deployment:**
```bash
# Recommended: Use the safe removal script
./remove-debug-sidecar.sh <your-deployment> [namespace]

# Alternative: Manual removal by finding container name
CONTAINER_INDEX=$(kubectl get deployment <your-deployment> -o jsonpath='{range .spec.template.spec.containers[*]}{@.name}{"\n"}{end}' | grep -n "debug-sidecar" | cut -d: -f1)
CONTAINER_INDEX=$((CONTAINER_INDEX-1))  # Convert to 0-based index
kubectl patch deployment <your-deployment> --type='json' -p="[{\"op\": \"remove\", \"path\": \"/spec/template/spec/containers/${CONTAINER_INDEX}\"}]"

# Alternative: Manual editing (safest for complex deployments)
kubectl edit deployment <your-deployment>  # Remove debug-sidecar container and diagnostics volume
```

> **Production Safe:** All methods avoid downtime. The script automatically finds containers by name rather than assuming indices, making it safe for deployments with multiple sidecars.

### Why Scripts Are Better Than Raw YAML Patches

✅ **No Downtime:** Uses rolling updates, pods restart gracefully  
✅ **Smart Validation:** Scripts check if deployment exists and validate current state  
✅ **Multi-Sidecar Safe:** Works with existing Istio, Fluentd, or other sidecars  
✅ **Idempotent:** Won't add duplicates or fail if already exists/doesn't exist  
✅ **User Friendly:** Clear feedback, confirmation prompts, and helpful error messages  
✅ **Consistent Experience:** Same workflow for both adding and removing

> **Addition:** Scripts can detect existing volumes and containers to avoid conflicts  
> **Removal:** Scripts dynamically find container indices instead of hardcoding them

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

## 🎯 Flexible Debugging Modes

The debug sidecar now supports **two modes** to balance security and debugging capabilities:

### 🔒 Secure Mode (Default)
- **Volume-based diagnostics only**
- **Container isolation maintained** 
- **Recommended for production environments**
```bash
./add-debug-sidecar.sh my-app production
```

### 🔓 Enhanced Mode (Optional)  
- **Process namespace sharing enabled**
- **Direct .NET process monitoring**
- **Enhanced debugging capabilities**
```bash
./add-debug-sidecar.sh --share-process-namespace my-app production
```

### How to Choose?

**Use Secure Mode when:**
- Debugging in production environments
- Security/compliance requirements prohibit process namespace sharing
- Volume-based diagnostics are sufficient
- You can modify your .NET app to write diagnostic data to `/tmp`

**Use Enhanced Mode when:**
- Development/staging environments
- Need real-time process monitoring without app changes
- Advanced .NET debugging scenarios (live performance counters, on-demand dumps)
- Security constraints allow process namespace sharing

> **Note**: The debug sidecar automatically detects which mode is active and provides appropriate commands and feedback.

## 🔒 Security-First Approach

This debug sidecar follows security best practices:

✅ **No Process Namespace Sharing**: Containers maintain isolation - the debug sidecar cannot see processes from other containers  
✅ **Volume-Based Diagnostics**: Uses shared `/tmp` volume for secure data exchange between containers  
✅ **Minimal Privileges**: Only includes necessary network debugging capabilities  
✅ **Container Isolation**: Each container maintains its own process space and security context  

### Why Volume-Based Instead of Process Sharing?

**🔒 Security Benefits:**
- Prevents exposure of environment variables and command-line arguments
- Maintains container isolation boundaries  
- Reduces attack surface
- Follows principle of least privilege

**📊 Effective Debugging:**
- Your .NET app writes diagnostic data to `/tmp` 
- Debug sidecar analyzes the files without needing process access
- Full diagnostic capabilities through structured data exchange
- Better for production environments

## � .NET Application Diagnostics

This container is specifically designed for debugging .NET client applications running in the same pod. The key feature is the **shared `/tmp` diagnostics volume** that allows seamless data exchange between your .NET application and the debug sidecar.

### Shared Diagnostics Volume (`/tmp`)
The `/tmp` directory is mounted as an `emptyDir` volume shared between containers in the pod:
- **Your .NET app** can write diagnostic data, dumps, traces, and logs to `/tmp`
- **Debug sidecar** can access and analyze these files in real-time
- **Persistent across container restarts** within the pod lifecycle

### .NET Debugging Workflow (Volume-Based)
> **Security Note**: This approach uses shared volumes instead of process namespace sharing, maintaining container isolation while enabling effective .NET debugging.

```bash
# 1. Your .NET app writes diagnostic data to /tmp (configured in your app)
# 2. Access shared diagnostic files from the debug sidecar
ls -la /tmp/                    # View all diagnostic files

# 3. Analyze performance data written by your app
head /tmp/counters.csv          # Performance metrics
cat /tmp/app-config.json        # Configuration dumps
tail -f /tmp/app-logs.txt       # Live application logs

# 4. Analyze memory dumps created by your app
dotnet-dump analyze /tmp/app-dump.dmp

# 5. Convert and analyze traces from your app
dotnet-trace convert /tmp/trace.nettrace --format speedscope
```

### .NET Application Integration
Configure your .NET application to write diagnostic data to the shared volume:

```csharp
// In your .NET application startup
var diagnosticPath = Environment.GetEnvironmentVariable("DIAGNOSTIC_OUTPUT_PATH") ?? "/tmp";

// Write performance metrics
var metricsFile = Path.Combine(diagnosticPath, "perf-metrics.json");
await File.WriteAllTextAsync(metricsFile, JsonSerializer.Serialize(metrics));

// Configure logging to shared volume
builder.Logging.AddFile(Path.Combine(diagnosticPath, "app-logs.txt"));

// Create memory dumps when needed
if (shouldCreateDump)
{
    var dumpFile = Path.Combine(diagnosticPath, $"dump-{DateTime.UtcNow:yyyyMMdd-HHmmss}.dmp");
    // Use your preferred dump creation method
}
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

### .NET HTTP Client Performance Monitoring (Enhanced Mode)
> **Note**: These examples require process namespace sharing (`--share-process-namespace` flag)

> **💡 Best Practice**: Use `dotnet-counters ps` to identify .NET processes - it's more reliable than `pgrep` especially in single-app scenarios.

```bash
# First, identify the .NET process (typically only one diagnostic-enabled app)
dotnet-counters ps

# Monitor all HTTP client metrics in real-time (using process ID from above)
dotnet-counters monitor -p <PID> --counters System.Net.Http

# Or use automatic process detection (if only one .NET process exists)
DOTNET_PID=$(dotnet-counters ps | grep -v "Process Id" | head -1 | awk '{print $1}')
dotnet-counters monitor -p $DOTNET_PID --counters System.Net.Http

# Monitor specific HTTP client performance counters
dotnet-counters monitor -p $DOTNET_PID --counters \
  System.Net.Http[requests-started,requests-started-rate,requests-aborted,requests-aborted-rate,current-requests]

# Monitor HTTP connection pool metrics
dotnet-counters monitor -p $DOTNET_PID --counters \
  System.Net.Http[current-connections,connections-established-per-second,http11-connections-current-total,http20-connections-current-total]

# Monitor HTTP request duration and status codes
dotnet-counters monitor -p $DOTNET_PID --counters \
  System.Net.Http[http11-requests-queue-duration,http20-requests-queue-duration,requests-failed,requests-failed-rate]

# Comprehensive HTTP monitoring with custom refresh interval
dotnet-counters monitor -p $DOTNET_PID --refresh-interval 5 --counters \
  System.Net.Http[requests-started,requests-failed,current-requests,current-connections,connections-established-per-second]

# Monitor HTTP client with JSON output for automated analysis
dotnet-counters monitor -p $DOTNET_PID --counters \
  "System.Net.Http[requests-started]" \
  "System.Net.Http[current-connections]" \
  --format json
```

### HTTP Client Debugging Examples
```bash
# 1. Identify HTTP client connection issues (using reliable process detection)
DOTNET_PID=$(dotnet-counters ps | tail -n +2 | head -1 | awk '{print $1}')
dotnet-counters monitor -p $DOTNET_PID --counters \
  System.Net.Http[current-connections,connections-established-per-second,requests-failed-rate]

# 2. Monitor request queue performance (HTTP/1.1 vs HTTP/2)
dotnet-counters monitor -p $DOTNET_PID --counters \
  System.Net.Http[http11-requests-queue-duration,http20-requests-queue-duration]

# 3. Track connection pool efficiency
dotnet-counters monitor -p $DOTNET_PID --counters \
  System.Net.Http[http11-connections-current-total,http20-connections-current-total,connections-established-per-second]

# 4. Monitor for connection leaks or excessive connections
watch -n 2 "dotnet-counters monitor -p \$(dotnet-counters ps | tail -n +2 | head -1 | awk '{print \$1}') --counters System.Net.Http[current-connections] | tail -1"

# 5. Capture HTTP metrics to file for analysis
dotnet-counters collect -p $DOTNET_PID --counters System.Net.Http --format csv -o /tmp/http-metrics.csv --duration 00:05:00
```

### HTTP Client Troubleshooting Scenarios
```bash
# Scenario 1: High HTTP request failure rate
# Check for failed requests and connection issues
DOTNET_PID=$(dotnet-counters ps | tail -n +2 | head -1 | awk '{print $1}')
dotnet-counters monitor -p $DOTNET_PID --counters \
  System.Net.Http[requests-failed,requests-failed-rate,requests-aborted,requests-aborted-rate,current-connections]

# Scenario 2: HTTP connection pool exhaustion  
# Monitor connection limits and establishment rate
dotnet-counters monitor -p $DOTNET_PID --counters \
  System.Net.Http[current-connections,connections-established-per-second,http11-connections-current-total]

# Scenario 3: Slow HTTP response times
# Monitor queue duration and active requests
dotnet-counters monitor -p $DOTNET_PID --counters \
  System.Net.Http[http11-requests-queue-duration,http20-requests-queue-duration,current-requests,requests-started-rate]

# Scenario 4: HTTP/2 vs HTTP/1.1 performance comparison
dotnet-counters monitor -p $DOTNET_PID --counters \
  System.Net.Http[http11-connections-current-total,http20-connections-current-total,http11-requests-queue-duration,http20-requests-queue-duration]
```

### Available System.Net.Http Counters
```bash
# Core request metrics
System.Net.Http[requests-started]                    # Total requests started
System.Net.Http[requests-started-rate]               # Requests per second
System.Net.Http[requests-failed]                     # Total failed requests  
System.Net.Http[requests-failed-rate]                # Failed requests per second
System.Net.Http[requests-aborted]                    # Total aborted requests
System.Net.Http[requests-aborted-rate]               # Aborted requests per second
System.Net.Http[current-requests]                    # Currently active requests

# Connection metrics
System.Net.Http[current-connections]                 # Current open connections
System.Net.Http[connections-established-per-second]  # New connections per second
System.Net.Http[http11-connections-current-total]    # HTTP/1.1 connections
System.Net.Http[http20-connections-current-total]    # HTTP/2 connections

# Performance metrics
System.Net.Http[http11-requests-queue-duration]      # HTTP/1.1 queue wait time
System.Net.Http[http20-requests-queue-duration]      # HTTP/2 queue wait time
```

### .NET Application Performance Issues (Volume-Based)
```bash
# Analyze performance data written by your .NET application
show-diagnostic-summary              # Overview of all diagnostic files
cat /tmp/perf-counters.csv          # View performance metrics
head -20 /tmp/gc-stats.json         # Garbage collection data

# Analyze memory dumps created by your application
analyze-latest-dump                  # Analyze the newest dump file
ls -la /tmp/*.dmp                   # List all available dumps

# Convert and analyze execution traces
convert-traces                       # Convert .nettrace files to speedscope
ls -la /tmp/*.speedscope.json       # View converted trace files

# Monitor application logs in real-time
watch-diagnostic-files               # Follow logs as they're written
tail -f /tmp/app-logs.txt           # Follow specific log file
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

### .NET Application Debugging (Volume-Based)
```bash
tmp-files                   # List shared diagnostic files in /tmp
analyze-dumps               # Analyze .NET dumps in /tmp using dotnet-dump
view-logs                   # View application logs in /tmp
json-pretty                 # Pretty print JSON diagnostic files
yaml-check                  # Validate YAML configuration files
```

### .NET Application Debugging (Enhanced Mode - Process Access)
```bash
dotnet-procs                # Show .NET processes across containers
monitor-dotnet [app-name]   # Live performance monitoring with dotnet-counters
dump-dotnet [app-name]      # Create memory dump to /tmp
trace-dotnet [app-name]     # Execution tracing to /tmp

# HTTP Client specific monitoring (Enhanced Mode)
http-monitor [app-name]     # Monitor HTTP client performance
http-connections [app-name] # Monitor HTTP connection pool metrics
http-failures [app-name]    # Monitor HTTP request failures
```

### Network & Process Monitoring
```bash
netprocs                    # Show processes with network connections  
listening                   # Show listening ports only
conns                       # Show active connections
```

### System Resource Monitoring
```bash
psmem                       # Top memory consumers
pscpu                       # Top CPU consumers
diskspace                   # Disk space usage
diskusage                   # Directory sizes sorted
openfiles                   # Show open files
```

### Load Testing & Performance
```bash
# Pre-configured load test (edit first, then run)
loadtest-edit                  # Edit the included Artillery template
loadtest-run                   # Run the pre-configured load test
artillery run /root/artillery-loadtest.yaml  # Same as above

# Quick custom load tests
loadtest [url] [users] [duration]  # Custom Artillery load test
loadtest-quick [url]        # Quick 10 user load test  
artillery quick --count 10 --num 2 [url]  # Artillery quick test
```

### Pre-configured Load Test Template
The container includes a comprehensive Artillery load test template at `/root/artillery-loadtest.yaml` with:
- **Multi-phase testing**: Warm-up, load, and spike phases
- **Multiple scenarios**: Health checks, API endpoints, complex operations
- **Performance thresholds**: P95/P99 response time limits
- **Detailed comments**: Examples for common use cases

```bash
# Quick workflow:
loadtest-edit               # 1. Edit the template for your service
loadtest-run                # 2. Run the load test
ls /tmp/*.json              # 3. View generated reports
```

### File Editing & Configuration
```bash
micro [file]                # Advanced editor with syntax highlighting
yaml-edit [file]            # Alias for micro (great for YAML)
yaml-check [file]           # Validate YAML syntax
json-pretty [file]          # Pretty print JSON
create-yaml-template [file] # Create YAML config template
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

### .NET Application Performance Issues (Volume-Based)
```bash
# Analyze performance data written by your .NET application
show-diagnostic-summary              # Overview of all diagnostic files
cat /tmp/perf-counters.csv          # View performance metrics
head -20 /tmp/gc-stats.json         # Garbage collection data

# Analyze memory dumps created by your application
analyze-latest-dump                  # Analyze the newest dump file
ls -la /tmp/*.dmp                   # List all available dumps

# Convert and analyze execution traces
convert-traces                       # Convert .nettrace files to speedscope
ls -la /tmp/*.speedscope.json       # View converted trace files

# Monitor application logs in real-time
watch-diagnostic-files               # Follow logs as they're written
tail -f /tmp/app-logs.txt           # Follow specific log file
```

### .NET Client Application Debugging (Volume-Based)
```bash
# Analyze HTTP client performance data written by your app
cat /tmp/http-client-metrics.json   # HTTP performance data
jq '.requests[] | select(.status >= 400)' /tmp/http-logs.json  # Failed requests

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

### .NET HTTP Client Debugging (Enhanced Mode)
> **Note**: Requires process namespace sharing for direct process monitoring

```bash
# Real-time HTTP client performance monitoring
monitor-dotnet MyApp  # Uses dotnet-counters for live monitoring

# Specific HTTP client troubleshooting
DOTNET_PID=$(dotnet-counters ps | tail -n +2 | head -1 | awk '{print $1}')
dotnet-counters monitor -p $DOTNET_PID --counters \
  System.Net.Http[requests-failed-rate,current-connections,connections-established-per-second]

# Identify HTTP connection issues
dotnet-counters monitor -p $DOTNET_PID --counters \
  System.Net.Http[requests-aborted,requests-aborted-rate,http11-requests-queue-duration]

# Monitor for HTTP connection pool problems
dotnet-counters monitor -p $DOTNET_PID --counters \
  System.Net.Http[current-connections,http11-connections-current-total,http20-connections-current-total]

# Capture HTTP metrics to shared volume for analysis
dotnet-counters collect -p $DOTNET_PID --counters System.Net.Http \
  --format csv -o /tmp/http-performance.csv --duration 00:02:00

# Create performance dump during HTTP issues
dump-dotnet MyApp  # Creates dump in /tmp for later analysis
```

### Application Performance Issues
```bash
# Trace application system calls (using reliable process detection)
DOTNET_PID=$(dotnet-counters ps | tail -n +2 | head -1 | awk '{print $1}')
trace-calls $DOTNET_PID

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
# Download the scripts
curl -O https://raw.githubusercontent.com/mortenduus/dotdebug/main/add-debug-sidecar.sh
curl -O https://raw.githubusercontent.com/mortenduus/dotdebug/main/remove-debug-sidecar.sh
chmod +x add-debug-sidecar.sh remove-debug-sidecar.sh

# Add to your deployment
./add-debug-sidecar.sh <your-deployment-name> [namespace]

# Verify the sidecar was added
kubectl get pods -l app=<your-app-label>

# Access the debug sidecar
kubectl exec -it <pod-name> -c debug-sidecar -- zsh

# Remove the debug sidecar when done
./remove-debug-sidecar.sh <your-deployment-name> [namespace]
```

### Complete Workflow Example
```bash
# 1. Download the management scripts
curl -O https://raw.githubusercontent.com/mortenduus/dotdebug/main/add-debug-sidecar.sh
curl -O https://raw.githubusercontent.com/mortenduus/dotdebug/main/remove-debug-sidecar.sh
chmod +x add-debug-sidecar.sh remove-debug-sidecar.sh

# 2. Add debug sidecar to your application
./add-debug-sidecar.sh my-web-app production

# 3. Wait for rollout to complete
kubectl rollout status deployment/my-web-app -n production

# 4. Access the debug container
kubectl exec -it deployment/my-web-app -n production -c debug-sidecar -- zsh

# 5. Debug your application (inside the sidecar)
# Note: You should see a welcome message with available tools and commands
motd                             # Show welcome message if not displayed
debug-sidecar                    # Get comprehensive pod info
debug-network external-api.com  # Test external connectivity

# Enhanced mode: Direct process monitoring (if --share-process-namespace was used)
ps aux | grep dotnet             # Check if you can see .NET processes  
dotnet-counters ps               # List .NET processes (more reliable)
DOTNET_PID=$(dotnet-counters ps | tail -n +2 | head -1 | awk '{print $1}')
dotnet-counters monitor -p $DOTNET_PID  # Monitor .NET performance
monitor-dotnet MyApp             # Live performance monitoring

# Secure mode: Volume-based diagnostics
tmp-files                        # List diagnostic files written by your app
analyze-latest-dump              # Analyze memory dumps
watch-diagnostic-files           # Follow logs in real-time

# 6. Clean up when debugging is complete
./remove-debug-sidecar.sh my-web-app production
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
kubectl exec -it [pod-name] -c debug-sidecar -- zsh

# Run debug commands
kubectl exec -it [pod-name] -c debug-sidecar -- debug-sidecar

# Capture traffic from outside the pod (saves to /tmp which is mounted)
kubectl exec -it [pod-name] -c debug-sidecar -- tcpdump -i any -w /tmp/capture.pcap
```

### Troubleshooting

**If you don't see the welcome message (motd) when accessing the sidecar:**
```bash
# Show the welcome message manually
kubectl exec -it [pod-name] -c debug-sidecar -- motd

# Or show it directly
kubectl exec -it [pod-name] -c debug-sidecar -- cat ~/.motd
```

**Common access patterns:**
```bash
# Interactive shell with full environment
kubectl exec -it [pod-name] -c debug-sidecar -- zsh

# Run single debug command
kubectl exec -it [pod-name] -c debug-sidecar -- debug-sidecar

# Quick network test
kubectl exec -it [pod-name] -c debug-sidecar -- test-port google.com 443
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
