FROM ubuntu:jammy 

LABEL maintainer="Morten Duus"
RUN apt-get update && apt-get install -y \
    curl \
    wget 
RUN apt install -y python3 python3-numpy python3-scipy python3-matplotlib

RUN wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
RUN apt-get update && apt-get install -y \
    dotnet-sdk-8.0 \
    dotnet-sdk-6.0 \
    zsh \
    git \
    net-tools

# dotnet 9
RUN wget https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.sh -O dotnet-install.sh
RUN chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 9.0 --install-dir /usr/share/dotnet --no-path

#install dotnet tools
RUN dotnet tool install -g dotnet-counters
RUN dotnet tool install -g dotnet-dump
RUN dotnet tool install -g dotnet-trace

# Setting User and Home
USER root
WORKDIR /root
ENV HOSTNAME dotdebug

RUN ln -s /root/.dotnet/dotnet /usr/local/bin
RUN ln -s /root/.dotnet/tools/dotnet-counters /usr/local/bin

# ZSH Themes
RUN curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh
COPY zshrc .zshrc
COPY p10k.zsh .p10k.zsh
COPY motd .motd

#setup powerlevel10k    
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
RUN echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc

# Running ZSH
CMD ["zsh"]