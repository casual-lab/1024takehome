# Solana 和 Anchor 开发环境安装指南

## 文档信息
- **文档编号**: 05
- **创建日期**: 2025-10-31
- **适用环境**: Docker 容器 / Linux

---

## 1. 环境要求

### 1.1 系统要求
- **操作系统**: Linux (Ubuntu 20.04+ 推荐)
- **内存**: 至少 8GB RAM
- **磁盘**: 至少 20GB 可用空间
- **网络**: 需要稳定的互联网连接

### 1.2 前置软件
- Rust 1.75+
- Node.js 18+
- Yarn 或 npm

---

## 2. 安装步骤

### 2.1 安装 Solana CLI

#### 方法 1: 官方安装脚本（推荐）

```bash
# 安装 Solana 1.18.x 版本（与 Anchor 兼容）
sh -c "$(curl -sSfL https://release.solana.com/v1.18.0/install)"
```

#### 配置环境变量

```bash
# 添加到 PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# 永久生效（添加到 .bashrc）
echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### 验证安装

```bash
solana --version
# 预期输出: solana-cli 1.18.x
```

### 2.2 配置 Solana CLI

#### 设置本地网络

```bash
# 设置为 localhost（本地测试网）
solana config set --url localhost

# 创建测试钱包（如果不存在）
solana-keygen new --no-bip39-passphrase

# 查看配置
solana config get
```

预期输出：
```
Config File: /root/.config/solana/cli/config.yml
RPC URL: http://localhost:8899
WebSocket URL: ws://localhost:8900/ (computed)
Keypair Path: /root/.config/solana/id.json
Commitment: confirmed
```

### 2.3 安装 Anchor CLI

#### 使用 avm（Anchor Version Manager）

```bash
# 安装 avm
cargo install --git https://github.com/coral-xyz/anchor avm --locked --force

# 使用 avm 安装 Anchor 0.30.x
avm install 0.30.1
avm use 0.30.1
```

#### 验证安装

```bash
anchor --version
# 预期输出: anchor-cli 0.30.1
```

### 2.4 安装额外依赖

#### 安装 SPL Token CLI（可选，用于代币操作）

```bash
cargo install spl-token-cli
```

#### 验证

```bash
spl-token --version
```

---

## 3. 启动本地测试网

### 3.1 启动 solana-test-validator

```bash
# 在后台启动测试验证节点
solana-test-validator &

# 或者在单独的终端窗口运行（推荐，方便查看日志）
solana-test-validator
```

#### 测试验证器选项

```bash
# 带自定义配置启动
solana-test-validator \
  --reset \                          # 重置账本
  --quiet \                          # 减少日志输出
  --ledger .anchor/test-ledger \     # 指定账本目录
  --bind-address 0.0.0.0             # 绑定所有接口
```

### 3.2 验证节点运行

```bash
# 检查节点状态
solana ping

# 查看余额（应该有测试 SOL）
solana balance
```

如果余额为 0，空投一些测试 SOL：
```bash
solana airdrop 10
```

---

## 4. 项目编译和测试

### 4.1 编译 Anchor 项目

```bash
cd /workspace/lp-staking

# 编译智能合约
anchor build
```

#### 首次编译注意事项

首次编译可能需要：
- 下载大量依赖（10-20 分钟）
- 编译 Anchor 框架（5-10 分钟）
- 生成 IDL 和 TypeScript 类型

**预期输出**:
```
Compiling lp-staking v0.1.0
...
Finished release [optimized] target(s) in X.XXs
```

### 4.2 运行测试

```bash
# 运行 Anchor 测试
anchor test
```

#### 测试流程
1. 启动本地测试验证器
2. 部署程序
3. 运行测试脚本
4. 清理环境

### 4.3 部署到本地网络

```bash
# 确保本地验证器正在运行
solana-test-validator

# 部署程序
anchor deploy
```

---

## 5. 常见问题排查

### 5.1 "no such command: build-sbf"

**原因**: 未安装 Solana CLI 或版本不兼容

**解决方案**:
```bash
# 重新安装 Solana CLI
sh -c "$(curl -sSfL https://release.solana.com/v1.18.0/install)"
source ~/.bashrc
```

### 5.2 "Error: failed to connect to cluster"

**原因**: 本地测试验证器未启动

**解决方案**:
```bash
# 启动验证器
solana-test-validator &

# 等待几秒钟
sleep 5

# 验证连接
solana ping
```

### 5.3 编译错误: "failed to download dependencies"

**原因**: 网络问题或 crates.io 访问受限

**解决方案**:
```bash
# 配置国内镜像（可选）
mkdir -p ~/.cargo
cat > ~/.cargo/config.toml << EOF
[source.crates-io]
replace-with = 'ustc'

[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
EOF

# 清理缓存重试
cargo clean
anchor build
```

### 5.4 "insufficient funds" 错误

**原因**: 测试钱包 SOL 余额不足

**解决方案**:
```bash
# 空投测试 SOL
solana airdrop 10

# 验证余额
solana balance
```

### 5.5 Anchor 版本不兼容

**原因**: Anchor 版本与 Solana 版本不匹配

**解决方案**:
```bash
# 检查版本兼容性
# Anchor 0.30.x 需要 Solana 1.18.x

# 重新安装匹配版本
avm install 0.30.1
avm use 0.30.1
```

---

## 6. Docker 环境特殊配置

### 6.1 持久化 Solana 配置

在 `docker-compose.yml` 中添加卷挂载：

```yaml
volumes:
  - .:/workspace
  - solana-config:/root/.config/solana
  - solana-cache:/root/.cache/solana
```

### 6.2 暴露端口

确保 Docker 容器暴露必要端口：

```yaml
ports:
  - "8899:8899"    # Solana RPC
  - "8900:8900"    # Solana WebSocket
  - "9900:9900"    # Solana faucet
```

### 6.3 容器内运行验证器

```bash
# 在容器内后台运行
nohup solana-test-validator > /tmp/validator.log 2>&1 &

# 查看日志
tail -f /tmp/validator.log
```

---

## 7. 快速启动脚本

创建 `/workspace/scripts/setup-dev-env.sh`:

```bash
#!/bin/bash

echo "=== Solana & Anchor 开发环境设置 ==="

# 1. 检查 Solana CLI
if ! command -v solana &> /dev/null; then
    echo "安装 Solana CLI..."
    sh -c "$(curl -sSfL https://release.solana.com/v1.18.0/install)"
    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
fi

# 2. 检查 Anchor
if ! command -v anchor &> /dev/null; then
    echo "安装 Anchor CLI..."
    cargo install --git https://github.com/coral-xyz/anchor avm --locked --force
    avm install 0.30.1
    avm use 0.30.1
fi

# 3. 配置 Solana
echo "配置 Solana CLI..."
solana config set --url localhost
if [ ! -f ~/.config/solana/id.json ]; then
    solana-keygen new --no-bip39-passphrase
fi

# 4. 启动测试验证器
echo "启动测试验证器..."
if ! pgrep -x "solana-test-validator" > /dev/null; then
    nohup solana-test-validator > /tmp/validator.log 2>&1 &
    sleep 5
fi

# 5. 空投测试 SOL
echo "空投测试 SOL..."
solana airdrop 10 || true

# 6. 验证安装
echo ""
echo "=== 环境验证 ==="
echo "Solana: $(solana --version)"
echo "Anchor: $(anchor --version)"
echo "余额: $(solana balance)"
echo ""
echo "✅ 环境设置完成！"
```

使用脚本：
```bash
chmod +x /workspace/scripts/setup-dev-env.sh
/workspace/scripts/setup-dev-env.sh
```

---

## 8. 验证清单

安装完成后，检查以下项目：

- [ ] `solana --version` 输出版本信息
- [ ] `anchor --version` 输出版本信息
- [ ] `solana config get` 显示正确配置
- [ ] `solana ping` 能连接到节点
- [ ] `solana balance` 显示余额（> 0）
- [ ] `cd /workspace/lp-staking && anchor build` 编译成功
- [ ] `anchor test` 测试通过

---

## 9. 推荐开发工作流

```bash
# 1. 进入项目目录
cd /workspace/lp-staking

# 2. 启动验证器（新终端）
solana-test-validator --reset

# 3. 编辑代码
vim programs/lp-staking/src/...

# 4. 编译
anchor build

# 5. 测试
anchor test

# 6. 部署（可选）
anchor deploy

# 7. 查看程序日志
solana logs
```

---

## 10. 参考资源

- [Solana 官方文档](https://docs.solana.com/)
- [Anchor 官方文档](https://www.anchor-lang.com/)
- [Solana Cookbook](https://solanacookbook.com/)
- [Anchor 示例项目](https://github.com/coral-xyz/anchor/tree/master/examples)

---

**文档版本**: v1.0  
**最后更新**: 2025-10-31  
**维护者**: LP Module Dev Team
