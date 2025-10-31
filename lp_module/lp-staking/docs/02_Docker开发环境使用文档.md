# Docker 开发环境使用文档

## 概述

本文档描述了基于 Ubuntu 24.04 的开发环境 Docker 镜像的构建和使用方法。该镜像预装了 Solana、Rust、Node.js 等开发工具，适用于区块链和 DeFi 项目开发。

## 镜像特性

### 基础环境
- **操作系统**: Ubuntu 24.04 LTS
- **时区**: Asia/Shanghai
- **语言**: UTF-8

### 已安装的工具和软件

#### 1. 基础命令行工具
- **文件操作**: curl, wget, git, vim, nano, tree, zip, unzip, tar, rsync
- **终端工具**: tmux, screen
- **系统监控**: htop, sysstat, iotop, iftop, nethogs
- **网络工具**: net-tools, ping, nslookup, netcat, telnet, traceroute
- **文本处理**: jq, yq, sed, awk, grep

#### 2. 开发环境
- **Node.js**: v20.x LTS
- **npm**: 最新版本
- **yarn**: 全局安装
- **pnpm**: 全局安装

#### 3. Rust 生态
- **Rust**: 稳定版（stable）
- **Cargo**: Rust 包管理器
- **rustfmt**: 代码格式化工具
- **clippy**: 代码检查工具

#### 4. Solana 开发工具
- **Solana CLI**: 稳定版
- **Anchor Framework**: 最新版本
- **AVM**: Anchor 版本管理器

#### 5. Python 环境
- **Python 3**: 系统版本
- **pip**: Python 包管理器
- **常用库**: requests, pyyaml, click, rich

#### 6. 其他工具
- **Docker CLI**: 用于在容器内操作外部 Docker
- **Git LFS**: 大文件支持
- **Build Essential**: C/C++ 编译工具链

## 构建镜像

### 基本构建
```bash
# 在项目根目录执行
docker build -t lp-module-dev:latest .
```

### 指定平台构建
```bash
# 为 AMD64 平台构建
docker build --platform linux/amd64 -t lp-module-dev:latest .

# 为 ARM64 平台构建（如 Apple Silicon）
docker build --platform linux/arm64 -t lp-module-dev:latest .
```

### 多平台构建
```bash
# 需要先创建 buildx builder
docker buildx create --name multiplatform --use
docker buildx build --platform linux/amd64,linux/arm64 -t lp-module-dev:latest --push .
```

## 运行容器

### 基本运行
```bash
docker run -it --rm lp-module-dev:latest
```

### 挂载项目目录
```bash
# 将当前目录挂载到容器的 /workspace
docker run -it --rm -v $(pwd):/workspace lp-module-dev:latest
```

### 带端口映射运行（用于开发服务器）
```bash
# 映射常用端口
docker run -it --rm \
  -v $(pwd):/workspace \
  -p 3000:3000 \
  -p 8899:8899 \
  -p 8900:8900 \
  lp-module-dev:latest
```

### 完整开发环境（推荐）
```bash
docker run -it --rm \
  --name lp-dev \
  -v $(pwd):/workspace \
  -v ~/.gitconfig:/root/.gitconfig:ro \
  -v ~/.ssh:/root/.ssh:ro \
  -p 3000:3000 \
  -p 8899:8899 \
  -p 8900:8900 \
  -e TERM=xterm-256color \
  lp-module-dev:latest
```

### 后台运行并进入
```bash
# 启动容器
docker run -d --name lp-dev \
  -v $(pwd):/workspace \
  lp-module-dev:latest tail -f /dev/null

# 进入容器
docker exec -it lp-dev /bin/bash

# 停止容器
docker stop lp-dev

# 删除容器
docker rm lp-dev
```

## 使用 Docker Compose（推荐）

创建 `docker-compose.yml` 文件：

```yaml
version: '3.8'

services:
  dev:
    build: .
    image: lp-module-dev:latest
    container_name: lp-dev
    volumes:
      - .:/workspace
      - ~/.gitconfig:/root/.gitconfig:ro
      - ~/.ssh:/root/.ssh:ro
    ports:
      - "3000:3000"      # 前端开发服务器
      - "8899:8899"      # Solana RPC
      - "8900:8900"      # Solana WebSocket
    environment:
      - TERM=xterm-256color
    stdin_open: true
    tty: true
    command: /bin/bash

  clickhouse:
    image: clickhouse/clickhouse-server:latest
    container_name: lp-clickhouse
    ports:
      - "8123:8123"      # HTTP 接口
      - "9000:9000"      # Native 接口
    volumes:
      - clickhouse_data:/var/lib/clickhouse
    environment:
      CLICKHOUSE_DB: lp_module
      CLICKHOUSE_USER: admin
      CLICKHOUSE_PASSWORD: password

volumes:
  clickhouse_data:
```

使用 Docker Compose：
```bash
# 启动所有服务
docker-compose up -d

# 进入开发容器
docker-compose exec dev /bin/bash

# 查看日志
docker-compose logs -f dev

# 停止所有服务
docker-compose down

# 停止并删除卷
docker-compose down -v
```

## 常用操作

### Solana 开发

#### 1. 启动本地测试网
```bash
# 进入容器后执行
solana-test-validator
```

#### 2. 创建 Anchor 项目
```bash
anchor init my-project
cd my-project
anchor build
anchor test
```

#### 3. 配置 Solana CLI
```bash
# 设置为本地测试网
solana config set --url localhost

# 生成新钱包
solana-keygen new

# 查看余额
solana balance

# 空投 SOL（测试网）
solana airdrop 10
```

### Rust 开发

```bash
# 创建新项目
cargo new my-rust-project
cd my-rust-project

# 构建项目
cargo build

# 运行项目
cargo run

# 运行测试
cargo test

# 格式化代码
cargo fmt

# 代码检查
cargo clippy
```

### Node.js 开发

```bash
# 初始化项目
npm init -y

# 安装依赖
npm install

# 使用 yarn
yarn install

# 使用 pnpm
pnpm install
```

## 环境变量

容器内预设的环境变量：

- `DEBIAN_FRONTEND=noninteractive`: 非交互式安装
- `TZ=Asia/Shanghai`: 时区设置
- `LANG=C.UTF-8`: 语言编码
- `PATH`: 包含 Rust、Solana、Node.js 等工具路径

## 自定义配置

### 添加额外的工具

在 Dockerfile 中添加：
```dockerfile
RUN apt-get update && apt-get install -y \
    your-package-name \
    && rm -rf /var/lib/apt/lists/*
```

### 修改时区
```dockerfile
ENV TZ=America/New_York
```

### 添加自定义脚本

在 Dockerfile 末尾添加：
```dockerfile
COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh
```

## 故障排查

### 1. 构建失败

**问题**: 网络连接超时
```bash
# 解决方案：使用国内镜像
# 在 Dockerfile 中添加
RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
```

### 2. 权限问题

**问题**: 容器内无法写入文件
```bash
# 解决方案：以当前用户身份运行
docker run -it --rm -v $(pwd):/workspace -u $(id -u):$(id -g) lp-module-dev:latest
```

### 3. Solana 工具未找到

**问题**: `solana: command not found`
```bash
# 解决方案：手动加载环境
source ~/.bashrc

# 或检查安装
ls -la ~/.local/share/solana/install/active_release/bin/
```

### 4. 容器内无法访问宿主机服务

**问题**: 无法连接宿主机上的数据库
```bash
# 解决方案：使用 host.docker.internal（Mac/Windows）
# 或使用宿主机 IP（Linux）
```

## 性能优化

### 1. 使用构建缓存
```bash
# 利用 BuildKit 缓存
DOCKER_BUILDKIT=1 docker build -t lp-module-dev:latest .
```

### 2. 多阶段构建（如需精简镜像）
```dockerfile
# 构建阶段
FROM ubuntu:24.04 as builder
# ... 构建操作

# 运行阶段
FROM ubuntu:24.04
COPY --from=builder /path/to/artifacts /destination
```

### 3. 减小镜像大小
```bash
# 清理 APT 缓存
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# 合并 RUN 命令
RUN command1 && \
    command2 && \
    command3
```

## 安全建议

1. **不要在生产环境使用 root 用户**
2. **定期更新基础镜像**: `docker pull ubuntu:24.04`
3. **扫描漏洞**: `docker scan lp-module-dev:latest`
4. **限制容器资源**:
   ```bash
   docker run --memory="2g" --cpus="2" lp-module-dev:latest
   ```

## 备份和迁移

### 导出镜像
```bash
docker save lp-module-dev:latest | gzip > lp-module-dev.tar.gz
```

### 导入镜像
```bash
docker load < lp-module-dev.tar.gz
```

### 推送到镜像仓库
```bash
# 标记镜像
docker tag lp-module-dev:latest your-registry/lp-module-dev:latest

# 推送
docker push your-registry/lp-module-dev:latest
```

## 更新日志

### v1.0 (2025-10-31)
- 初始版本
- 基于 Ubuntu 24.04
- 集成 Solana、Rust、Node.js 开发环境
- 预装常用命令行工具

## 参考资料

- [Docker 官方文档](https://docs.docker.com/)
- [Ubuntu 镜像文档](https://hub.docker.com/_/ubuntu)
- [Solana 文档](https://docs.solana.com/)
- [Anchor 文档](https://www.anchor-lang.com/)
- [Rust 文档](https://www.rust-lang.org/)

## 技术支持

如遇问题，请检查：
1. Docker 版本是否为最新稳定版
2. 系统资源是否充足（建议 8GB+ RAM）
3. 网络连接是否正常
4. 查看容器日志: `docker logs <container_id>`

---

**文档版本**: v1.0  
**最后更新**: 2025-10-31  
**维护者**: LP Module Development Team
