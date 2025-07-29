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
cat .motd

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

# .NET debugging shortcuts
alias dotnet-procs='ps aux | grep -i dotnet | grep -v grep'  # Show .NET processes
alias dotnet-ports='lsof -i | grep dotnet'   # Show .NET network connections
alias dotnet-files='lsof -p $(pgrep -f dotnet) 2>/dev/null' # Files opened by .NET processes
alias tmp-files='ls -la /tmp/'               # List shared diagnostic files

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

# Additional debugging functions
monitor-dotnet() {
    if [ -z "$1" ]; then
        echo "Usage: monitor-dotnet [process-name-pattern]"
        echo "Example: monitor-dotnet MyApp"
        return 1
    fi
    local pid=$(pgrep -f "$1" | head -1)
    if [ -z "$pid" ]; then
        echo "No process found matching: $1"
        return 1
    fi
    echo "Monitoring .NET process: $pid ($1)"
    dotnet-counters monitor -p $pid
}

dump-dotnet() {
    if [ -z "$1" ]; then
        echo "Usage: dump-dotnet [process-name-pattern]"
        echo "Example: dump-dotnet MyApp"
        return 1
    fi
    local pid=$(pgrep -f "$1" | head -1)
    if [ -z "$pid" ]; then
        echo "No process found matching: $1"
        return 1
    fi
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="/tmp/dotnet-dump-${1}-${timestamp}.dmp"
    echo "Creating dump of .NET process: $pid ($1)"
    echo "Output file: $filename"
    dotnet-dump collect -p $pid -o "$filename"
}

trace-dotnet() {
    if [ -z "$1" ]; then
        echo "Usage: trace-dotnet [process-name-pattern] [duration-seconds]"
        echo "Example: trace-dotnet MyApp 30"
        return 1
    fi
    local pid=$(pgrep -f "$1" | head -1)
    if [ -z "$pid" ]; then
        echo "No process found matching: $1"
        return 1
    fi
    local duration=${2:-10}
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="/tmp/dotnet-trace-${1}-${timestamp}.nettrace"
    echo "Tracing .NET process: $pid ($1) for ${duration}s"
    echo "Output file: $filename"
    timeout $duration dotnet-trace collect -p $pid -o "$filename"
}


# Colorise the top Tabs of Iterm2 with the same color as background
# Just change the 18/26/33 wich are the rgb values
echo -e "\033]6;1;bg;red;brightness;18\a"
echo -e "\033]6;1;bg;green;brightness;26\a"
echo -e "\033]6;1;bg;blue;brightness;33\a"

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


