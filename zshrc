# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
#export TERM="xterm-256color"
ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_DISABLE_COMPFIX="true"
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
POWERLEVEL9K_DISABLE_GITSTATUS=true

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
  yarn
  web-search
  jsontools
  macports
  node
  sudo
  docker
)

source $ZSH/oh-my-zsh.sh
# User configuration
cat ~/.motd 2>/dev/null || true

# Network debugging shortcuts
alias listen='netstat -tlnp'
alias ports='ss -tulpn'
alias conns='ss -tuln'
alias myip='hostname -i'

# Envoy proxy debugging (if available)
alias envoy-stats='curl -s http://localhost:15000/stats/prometheus'
alias envoy-clusters='curl -s http://localhost:15000/clusters'
alias envoy-config='curl -s http://localhost:15000/config_dump'

# Process debugging
alias pstree='ps auxf'
alias netprocs='lsof -i'

# .NET debugging shortcuts (adaptive based on environment)
# Volume-based (always available)
alias tmp-files='ls -la /tmp/'               # List shared diagnostic files
alias analyze-dumps='find /tmp -name "*.dmp" -exec echo "Analyzing: {}" \; -exec dotnet-dump analyze {} \;'
alias view-logs='find /tmp -name "*.log" -o -name "*.txt" | head -5 | xargs tail -f'
alias list-diagnostics='find /tmp -type f \( -name "*.json" -o -name "*.dmp" -o -name "*.log" -o -name "*.txt" -o -name "*.csv" \) -ls'

# Process-based (available when process namespace sharing is enabled)
alias dotnet-procs='ps aux | grep -i dotnet | grep -v grep'  # Show .NET processes
alias dotnet-ps='ps aux | grep -i dotnet | grep -v grep'     # Alias for dotnet-procs
alias dotnet-ports='lsof -i | grep dotnet'   # Show .NET network connections
# Helper function for reliable .NET process detection
get-dotnet-pid() {
    if [ -z "$1" ]; then
        # If no pattern provided, get the first .NET process
        dotnet-counters ps 2>/dev/null | tail -n +2 | head -1 | awk '{print $1}'
    else
        # Try dotnet-counters first (more reliable for .NET processes)
        local dotnet_pid=$(dotnet-counters ps 2>/dev/null | grep -i "$1" | head -1 | awk '{print $1}')
        if [ -n "$dotnet_pid" ]; then
            echo "$dotnet_pid"
        else
            # Fallback to pgrep if dotnet-counters doesn't find it
            pgrep -f "$1" | head -1
        fi
    fi
}

alias dotnet-files='lsof -p $(get-dotnet-pid) 2>/dev/null' # Files opened by .NET processes

# Load testing shortcuts
alias loadtest-quick='artillery quick --count 10 --num 2'    # Quick load test
alias loadtest-edit='micro /root/artillery-loadtest.yaml'     # Edit load test template
alias loadtest-run='artillery run /root/artillery-loadtest.yaml'  # Run load test template
alias yaml-edit='micro'                      # Better YAML editor
alias yaml-check='yaml-cli validate'         # Validate YAML
alias json-pretty='prettyjson'               # Pretty print JSON

# General utilities
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias less='less -R'

# Additional debugging aliases
alias psnet='ss -tulpn'           # Show network processes with PIDs
alias psmem='ps aux --sort=-%mem | head -20'   # Top memory consumers
alias pscpu='ps aux --sort=-%cpu | head -20'   # Top CPU consumers
alias diskspace='df -h'           # Disk space usage
alias diskusage='du -sh * | sort -hr'  # Directory sizes sorted
alias findlarge='find . -type f -size +100M -exec ls -lh {} \;'  # Find large files
alias netstat-summary='netstat -s'    # Network statistics summary
alias openfiles='lsof +L1'        # Show open files
alias listening='netstat -tlnp | grep LISTEN'  # Only listening ports
alias motd='cat ~/.motd'           # Show the welcome message again

# Quick debugging functions
test-port() {
    nc -zv "$1" "$2"
}

test-http() {
    curl -v -m 10 "$1"
}

capture-traffic() {
    tcpdump -i any -n host "$1"
}

trace-calls() {
    strace -p "$1" -f -e network
}

# Volume-based .NET diagnostic functions (always available)
analyze-latest-dump() {
    local latest_dump=$(find /tmp -name "*.dmp" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2)
    if [ -n "$latest_dump" ]; then
        echo "Analyzing latest dump: $latest_dump"
        dotnet-dump analyze "$latest_dump"
    else
        echo "No .NET dump files found in /tmp"
        echo "Your .NET application should create dumps and save them to /tmp"
    fi
}

watch-diagnostic-files() {
    echo "Watching for new diagnostic files in /tmp..."
    echo "Press Ctrl+C to stop"
    find /tmp -name "*.log" -o -name "*.txt" -o -name "*.json" | head -5 | xargs tail -f
}

show-diagnostic-summary() {
    echo "=== Diagnostic Files Summary ==="
    echo ""
    echo "📁 Log files:"
    find /tmp -name "*.log" -o -name "*.txt" | head -10
    echo ""
    echo "📊 Performance data:"
    find /tmp -name "*.csv" -o -name "*perf*" -o -name "*metrics*" | head -10
    echo ""
    echo "🗄️ Memory dumps:"
    find /tmp -name "*.dmp" | head -10
    echo ""
    echo "⚙️ Configuration files:"
    find /tmp -name "*.json" -o -name "*.yaml" -o -name "*.xml" | head -10
}

convert-traces() {
    echo "Converting .NET trace files to speedscope format..."
    find /tmp -name "*.nettrace" | while read trace_file; do
        echo "Converting: $trace_file"
        local output_file="${trace_file%.nettrace}.speedscope.json"
        dotnet-trace convert "$trace_file" --format speedscope --output "$output_file"
        echo "Created: $output_file"
    done
}

# Process-based .NET debugging functions (requires process namespace sharing)
check-process-access() {
    # Check if we can see other containers' processes
    local dotnet_count=$(ps aux | grep -c "[d]otnet" || echo "0")
    if [ "$dotnet_count" -gt 0 ]; then
        return 0  # Can see .NET processes
    else
        return 1  # Cannot see .NET processes
    fi
}

monitor-dotnet() {
    if ! check-process-access; then
        echo "❌ Cannot see .NET processes from other containers"
        echo "   Process namespace sharing is not enabled for this pod"
        echo "   Use volume-based debugging: analyze-latest-dump, tmp-files, etc."
        return 1
    fi
    
    if [ -z "$1" ]; then
        echo "Usage: monitor-dotnet [process-name-pattern]"
        echo "Example: monitor-dotnet MyApp"
        return 1
    fi
    local pid=$(get-dotnet-pid "$1")
    if [ -z "$pid" ]; then
        echo "No .NET process found matching: $1"
        echo "Available .NET processes:"
        dotnet-counters ps 2>/dev/null || ps aux | grep -i dotnet | grep -v grep
        return 1
    fi
    echo "Monitoring .NET process: $pid ($1)"
    dotnet-counters monitor -p $pid
}

dump-dotnet() {
    if ! check-process-access; then
        echo "❌ Cannot see .NET processes from other containers"
        echo "   Process namespace sharing is not enabled for this pod"
        echo "   Your .NET app should create dumps and write them to /tmp"
        echo "   Then use: analyze-latest-dump"
        return 1
    fi
    
    if [ -z "$1" ]; then
        echo "Usage: dump-dotnet [process-name-pattern]"
        echo "Example: dump-dotnet MyApp"
        return 1
    fi
    local pid=$(get-dotnet-pid "$1")
    if [ -z "$pid" ]; then
        echo "No .NET process found matching: $1"
        echo "Available .NET processes:"
        dotnet-counters ps 2>/dev/null || ps aux | grep -i dotnet | grep -v grep
        return 1
        ps aux | grep -i dotnet | grep -v grep
        return 1
    fi
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="/tmp/dotnet-dump-${1}-${timestamp}.dmp"
    echo "Creating dump of .NET process: $pid ($1)"
    echo "Output file: $filename"
    dotnet-dump collect -p $pid -o "$filename"
}

trace-dotnet() {
    if ! check-process-access; then
        echo "❌ Cannot see .NET processes from other containers"
        echo "   Process namespace sharing is not enabled for this pod"
        echo "   Your .NET app should create traces and write them to /tmp"
        echo "   Then use: convert-traces"
        return 1
    fi
    
    if [ -z "$1" ]; then
        echo "Usage: trace-dotnet [process-name-pattern] [duration-seconds]"
        echo "Example: trace-dotnet MyApp 30"
        return 1
    fi
    local pid=$(get-dotnet-pid "$1")
    if [ -z "$pid" ]; then
        echo "No .NET process found matching: $1"
        echo "Available .NET processes:"
        dotnet-counters ps 2>/dev/null || ps aux | grep -i dotnet | grep -v grep
        return 1
    fi
    local duration=${2:-10}
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="/tmp/dotnet-trace-${1}-${timestamp}.nettrace"
    echo "Tracing .NET process: $pid ($1) for ${duration}s"
    echo "Output file: $filename"
    timeout $duration dotnet-trace collect -p $pid -o "$filename"
}

# HTTP Client specific monitoring functions (requires process namespace sharing)
http-monitor() {
    if ! check-process-access; then
        echo "❌ Cannot see .NET processes from other containers"
        echo "   Process namespace sharing is not enabled for this pod"
        echo "   Use volume-based debugging: check /tmp for HTTP client logs"
        return 1
    fi
    
    if [ -z "$1" ]; then
        echo "Usage: http-monitor [process-name-pattern]"
        echo "Example: http-monitor MyApp"
        return 1
    fi
    local pid=$(get-dotnet-pid "$1")
    if [ -z "$pid" ]; then
        echo "No .NET process found matching: $1"
        echo "Available .NET processes:"
        dotnet-counters ps 2>/dev/null
        return 1
    fi
    echo "Monitoring HTTP client performance for: $pid ($1)"
    dotnet-counters monitor -p $pid --counters 'System.Net.Http[requests-started,requests-failed,current-connections,connections-established-per-second]'
}

# Quick aliases for comprehensive monitoring
alias netmon='monitor-network-full'        # Comprehensive network monitoring
alias netmon-quick='monitor-network-quick' # Quick network overview
alias httpmon='monitor-http-detailed'      # Detailed HTTP client monitoring  
alias kestrelmon='monitor-kestrel-detailed' # Detailed Kestrel server monitoring

http-connections() {
    if ! check-process-access; then
        echo "❌ Cannot see .NET processes from other containers"
        echo "   Process namespace sharing is not enabled for this pod"
        return 1
    fi
    
    if [ -z "$1" ]; then
        echo "Usage: http-connections [process-name-pattern]"
        echo "Example: http-connections MyApp"
        return 1
    fi
    local pid=$(get-dotnet-pid "$1")
    if [ -z "$pid" ]; then
        echo "No .NET process found matching: $1"
        echo "Available .NET processes:"
        dotnet-counters ps 2>/dev/null
        return 1
    fi
    echo "Monitoring HTTP connection pool for: $pid ($1)"
    dotnet-counters monitor -p $pid --counters 'System.Net.Http[current-connections,http11-connections-current-total,http20-connections-current-total,connections-established-per-second]'
}

http-failures() {
    if ! check-process-access; then
        echo "❌ Cannot see .NET processes from other containers"
        echo "   Process namespace sharing is not enabled for this pod"
        return 1
    fi
    
    if [ -z "$1" ]; then
        echo "Usage: http-failures [process-name-pattern]"
        echo "Example: http-failures MyApp"
        return 1
    fi
    local pid=$(get-dotnet-pid "$1")
    if [ -z "$pid" ]; then
        echo "No .NET process found matching: $1"
        echo "Available .NET processes:"
        dotnet-counters ps 2>/dev/null
        return 1
    fi
    echo "Monitoring HTTP request failures for: $pid ($1)"
    dotnet-counters monitor -p $pid --counters 'System.Net.Http[requests-failed,requests-failed-rate,requests-aborted,requests-aborted-rate]'
}

http-queue-performance() {
    if ! check-process-access; then
        echo "❌ Cannot see .NET processes from other containers"
        echo "   Process namespace sharing is not enabled for this pod"
        return 1
    fi
    
    if [ -z "$1" ]; then
        echo "Usage: http-queue-performance [process-name-pattern]"
        echo "Example: http-queue-performance MyApp"
        return 1
    fi
    local pid=$(get-dotnet-pid "$1")
    if [ -z "$pid" ]; then
        echo "No .NET process found matching: $1"
        echo "Available .NET processes:"
        dotnet-counters ps 2>/dev/null
        return 1
    fi
    echo "Monitoring HTTP request queue performance for: $pid ($1)"
    dotnet-counters monitor -p $pid --counters 'System.Net.Http[http11-requests-queue-duration,http20-requests-queue-duration,current-requests]'
}

# Comprehensive network monitoring - all HTTP, Kestrel, and networking counters
monitor-network-full() {
    if ! check-process-access; then
        echo "❌ Cannot see .NET processes from other containers"
        echo "   Process namespace sharing is not enabled for this pod"
        echo "   Use volume-based debugging: check /tmp for network performance logs"
        return 1
    fi
    
    if [ -z "$1" ]; then
        echo "Usage: monitor-network-full [process-name-pattern] [refresh-interval]"
        echo "Example: monitor-network-full MyApp 2"
        echo ""
        echo "This monitors ALL network-related counters:"
        echo "  • HTTP Client (requests, connections, failures, timing)"
        echo "  • Kestrel Server (connections, requests, errors)"
        echo "  • ASP.NET Core (requests, responses, routing)"
        echo "  • Socket connections and networking"
        return 1
    fi
    
    local pid=$(get-dotnet-pid "$1")
    if [ -z "$pid" ]; then
        echo "No .NET process found matching: $1"
        echo "Available .NET processes:"
        dotnet-counters ps 2>/dev/null
        return 1
    fi
    
    local refresh_interval=${2:-3}
    echo "🌐 Comprehensive Network Monitoring for: $pid ($1)"
    echo "📊 Refresh interval: ${refresh_interval}s"
    echo "🔄 Press Ctrl+C to stop"
    echo ""
    
    dotnet-counters monitor -p $pid --refresh-interval $refresh_interval --counters \
        'System.Net.Http[requests-started,requests-started-rate,requests-failed,requests-failed-rate,requests-aborted,requests-aborted-rate,current-requests,current-connections,connections-established-per-second,http11-connections-current-total,http20-connections-current-total,http11-requests-queue-duration,http20-requests-queue-duration]' \
        'Microsoft.AspNetCore.Hosting[requests-per-second,total-requests,current-requests,failed-requests]' \
        'Microsoft.AspNetCore.Server.Kestrel[connection-queue-length,request-queue-length,total-connections,current-connections,connection-rate,total-tls-handshakes,current-tls-handshakes,failed-tls-handshakes,current-upgraded-requests,total-upgraded-requests,request-rate,bad-requests,current-bad-requests]' \
        'System.Net.Sockets[outgoing-connections-established,incoming-connections-established]' \
        'System.Net.NameResolution[dns-lookups-requested,dns-lookups-duration]'
}

# Quick network overview - essential counters only
monitor-network-quick() {
    if ! check-process-access; then
        echo "❌ Cannot see .NET processes from other containers"
        echo "   Process namespace sharing is not enabled for this pod"
        return 1
    fi
    
    if [ -z "$1" ]; then
        echo "Usage: monitor-network-quick [process-name-pattern]"
        echo "Example: monitor-network-quick MyApp"
        return 1
    fi
    
    local pid=$(get-dotnet-pid "$1")
    if [ -z "$pid" ]; then
        echo "No .NET process found matching: $1"
        return 1
    fi
    
    echo "⚡ Quick Network Overview for: $pid ($1)"
    echo ""
    
    dotnet-counters monitor -p $pid --refresh-interval 2 --counters \
        'System.Net.Http[requests-started-rate,requests-failed-rate,current-connections]' \
        'Microsoft.AspNetCore.Hosting[requests-per-second,current-requests,failed-requests]' \
        'Microsoft.AspNetCore.Server.Kestrel[current-connections,request-rate,bad-requests]'
}

# HTTP Client focus - detailed HTTP client monitoring
monitor-http-detailed() {
    if ! check-process-access; then
        echo "❌ Cannot see .NET processes from other containers"
        echo "   Process namespace sharing is not enabled for this pod"
        return 1
    fi
    
    if [ -z "$1" ]; then
        echo "Usage: monitor-http-detailed [process-name-pattern]"
        echo "Example: monitor-http-detailed MyApp"
        return 1
    fi
    
    local pid=$(get-dotnet-pid "$1")
    if [ -z "$pid" ]; then
        echo "No .NET process found matching: $1"
        return 1
    fi
    
    echo "🌐 Detailed HTTP Client Monitoring for: $pid ($1)"
    echo ""
    
    dotnet-counters monitor -p $pid --refresh-interval 2 --counters \
        'System.Net.Http[requests-started,requests-started-rate,requests-failed,requests-failed-rate,requests-aborted,requests-aborted-rate,current-requests,current-connections,connections-established-per-second,http11-connections-current-total,http20-connections-current-total,http11-requests-queue-duration,http20-requests-queue-duration,dns-lookups-duration]'
}

# Kestrel server focus - detailed server monitoring  
monitor-kestrel-detailed() {
    if ! check-process-access; then
        echo "❌ Cannot see .NET processes from other containers"
        echo "   Process namespace sharing is not enabled for this pod"
        return 1
    fi
    
    if [ -z "$1" ]; then
        echo "Usage: monitor-kestrel-detailed [process-name-pattern]"
        echo "Example: monitor-kestrel-detailed MyApp"
        return 1
    fi
    
    local pid=$(get-dotnet-pid "$1")
    if [ -z "$pid" ]; then
        echo "No .NET process found matching: $1"
        return 1
    fi
    
    echo "🖥️  Detailed Kestrel Server Monitoring for: $pid ($1)"
    echo ""
    
    dotnet-counters monitor -p $pid --refresh-interval 2 --counters \
        'Microsoft.AspNetCore.Server.Kestrel[connection-queue-length,request-queue-length,total-connections,current-connections,connection-rate,total-tls-handshakes,current-tls-handshakes,failed-tls-handshakes,current-upgraded-requests,total-upgraded-requests,request-rate,bad-requests,current-bad-requests]' \
        'Microsoft.AspNetCore.Hosting[requests-per-second,total-requests,current-requests,failed-requests]'
}


# Colorise the top Tabs of Iterm2 with the same color as background
# Just change the 18/26/33 wich are the rgb values
echo -e "\033]6;1;bg;red;brightness;18\a"
echo -e "\033]6;1;bg;green;brightness;26\a"
echo -e "\033]6;1;bg;blue;brightness;33\a"

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


