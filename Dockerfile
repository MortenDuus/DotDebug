FROM ubuntu:jammy 

LABEL maintainer="Morten Duus"
LABEL description="Sidecar debugging container for Kubernetes pods"

# Install essential system packages and network debugging tools
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    jq \
    unzip \
    socat \
    netcat-openbsd \
    telnet \
    iputils-ping \
    iproute2 \
    iperf3 \
    dnsutils \
    net-tools \
    tcpdump 
RUN apt-get update && apt-get install -y tcptraceroute \
    traceroute \
    mtr \
    nmap \
    strace \
    lsof \
    htop \
    vim \
    nano \
    micro \
    tree \
    less \
    procps \
    ca-certificates \
    openssl \
    util-linux

# Install .NET SDKs and debugging tools
RUN wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    apt-get update && apt-get install -y dotnet-sdk-8.0 dotnet-sdk-6.0

# Install .NET 9 (preview)
RUN wget https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 9.0 --install-dir /usr/share/dotnet --no-path

# Install .NET debugging tools
RUN dotnet tool install -g dotnet-counters && \
    dotnet tool install -g dotnet-dump && \
    dotnet tool install -g dotnet-trace

# Install Node.js and performance testing tools
RUN apt update -y && apt install -y nodejs npm && \
    npm install -g artillery@latest && \
    npm install -g yaml-cli && \
    npm install -g prettyjson

# Clean up package files
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    rm -f packages-microsoft-prod.deb dotnet-install.sh

# Set up user and environment
USER root
WORKDIR /root
ENV HOSTNAME=sidecar-debug

# Create symbolic links for .NET tools
RUN ln -s /root/.dotnet/dotnet /usr/local/bin && \
    ln -s /root/.dotnet/tools/dotnet-counters /usr/local/bin && \
    ln -s /root/.dotnet/tools/dotnet-dump /usr/local/bin && \
    ln -s /root/.dotnet/tools/dotnet-trace /usr/local/bin

# Install zsh and git for oh-my-zsh
RUN apt-get update && apt-get install -y zsh git fonts-powerline

# Install oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install powerlevel10k theme
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k

# Copy zsh configuration and powerlevel10k config
COPY zshrc /root/.zshrc
COPY p10k.zsh /root/.p10k.zsh

# Copy debug scripts and configuration
COPY debug-sidecar.sh /usr/local/bin/debug-sidecar
COPY debug-network.sh /usr/local/bin/debug-network
COPY motd /root/.motd
COPY artillery-loadtest.yaml /root/artillery-loadtest.yaml

# Make debug scripts executable
RUN chmod +x /usr/local/bin/debug-sidecar /usr/local/bin/debug-network

# Set zsh as default shell
RUN chsh -s $(which zsh)

# Default command that keeps container running and shows motd
CMD ["zsh", "-c", "cat ~/.motd 2>/dev/null || true; exec zsh"]