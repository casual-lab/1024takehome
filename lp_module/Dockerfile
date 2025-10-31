# Ubuntu 24.04 开发环境
FROM ubuntu:24.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# 设置工作目录
WORKDIR /workspace

# 更新系统并安装基础工具
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
    # 基础工具
    curl \
    wget \
    git \
    vim \
    nano \
    tmux \
    screen \
    htop \
    tree \
    zip \
    unzip \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    # 网络工具
    net-tools \
    iputils-ping \
    dnsutils \
    netcat-openbsd \
    telnet \
    traceroute \
    # 开发工具
    build-essential \
    cmake \
    pkg-config \
    autoconf \
    automake \
    libtool \
    # 版本控制
    git-lfs \
    # 文本处理
    jq \
    yq \
    sed \
    gawk \
    grep \
    # 系统工具
    sudo \
    openssh-client \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    # 性能分析
    sysstat \
    iotop \
    iftop \
    nethogs \
    # 其他实用工具
    rsync \
    file \
    less \
    man-db \
    manpages \
    bash-completion \
    && rm -rf /var/lib/apt/lists/*

# 安装 Node.js 20.x LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@latest && \
    npm install -g yarn pnpm && \
    rm -rf /var/lib/apt/lists/*

# 安装 Rust 和 Cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . $HOME/.cargo/env && \
    rustup default stable && \
    rustup component add rustfmt clippy

# 将 Rust 添加到 PATH
ENV PATH="/root/.cargo/bin:${PATH}"

# 安装 Solana CLI
RUN sh -c "$(curl -sSfL https://release.solana.com/stable/install)" && \
    echo 'export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc

# 将 Solana 添加到 PATH
ENV PATH="/root/.local/share/solana/install/active_release/bin:${PATH}"

# 安装 Anchor Framework
RUN cargo install --git https://github.com/coral-xyz/anchor avm --locked --force && \
    avm install latest && \
    avm use latest

# 安装 Python 3 和常用包
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/* && \
    pip3 install --no-cache-dir --break-system-packages \
    requests \
    pyyaml \
    click \
    rich

# 安装 Docker CLI（用于在容器内操作 Docker）
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# 配置 Git
RUN git config --global init.defaultBranch main && \
    git config --global core.editor vim

# 创建常用目录
RUN mkdir -p /workspace/projects && \
    mkdir -p /workspace/data && \
    mkdir -p /workspace/logs

# 设置 bash 提示符美化
RUN echo 'export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> ~/.bashrc

# 添加一些有用的别名
RUN echo 'alias ll="ls -alF"' >> ~/.bashrc && \
    echo 'alias la="ls -A"' >> ~/.bashrc && \
    echo 'alias l="ls -CF"' >> ~/.bashrc && \
    echo 'alias ..="cd .."' >> ~/.bashrc && \
    echo 'alias ...="cd ../.."' >> ~/.bashrc && \
    echo 'alias gs="git status"' >> ~/.bashrc && \
    echo 'alias ga="git add"' >> ~/.bashrc && \
    echo 'alias gc="git commit"' >> ~/.bashrc && \
    echo 'alias gp="git push"' >> ~/.bashrc && \
    echo 'alias gl="git log --oneline --graph --decorate"' >> ~/.bashrc

# 健康检查（可选）
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD [ "bash", "-c", "echo 'Healthy'" ]

# 默认命令
CMD ["/bin/bash"]

# 元数据标签
LABEL maintainer="LP Module Development Team"
LABEL description="Ubuntu 24.04 development environment with Solana, Rust, Node.js and common CLI tools"
LABEL version="1.0"
