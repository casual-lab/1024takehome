# LP Module - 流动性池与质押挖矿模块

基于 Solana 区块链的 DeFi 流动性挖矿模块，提供完整的流动性池、质押和奖励分配功能。

## 🎯 项目概述

本项目实现了一个完整的 DeFi 流动性挖矿系统，包括：

- ✅ **流动性池管理** - 用户存入 wrappedUSDC，获得 LP Token
- ✅ **质押挖矿** - 质押 LP Token 赚取 SOL 奖励
- ✅ **双重奖励机制** - 固定速率 & 按块动态排放
- ⏳ **数据采集** - 基于 ClickHouse 的链上数据索引（待实现）
- ✅ **完整文档** - 设计文档、开发指南、API 参考

## 📊 开发进度

**当前阶段**: Phase 1 ✅ 已完成

- ✅ 开发环境搭建（Solana CLI 2.3.13, Anchor 0.32.1）
- ✅ 核心状态结构定义
- ✅ 奖励计算器实现
- ✅ Initialize 指令实现
- ✅ 首次成功编译

**下一阶段**: Phase 2 - 流动性池功能（Deposit/Withdraw）

详见：[06_开发进度报告_Phase1完成.md](docs/06_开发进度报告_Phase1完成.md)

## 🚀 快速开始

### 前置要求

- Docker 20.10+
- Docker Compose 2.0+

### 方法 1: 使用 Docker（推荐）

```bash
# 1. 构建并启动开发环境
./scripts/dev.sh build
./scripts/dev.sh start

# 2. 进入开发容器
./scripts/dev.sh shell

# 3. 设置 Solana 环境（首次运行）
/workspace/scripts/setup-dev-env.sh

# 4. 编译 Anchor 项目
cd /workspace/lp-staking
anchor build
```

### 方法 2: 本地开发

```bash
# 1. 安装 Solana 工具链
./scripts/setup-dev-env.sh

# 2. 进入项目目录
cd lp-staking

# 3. 启动测试验证器（新终端）
solana-test-validator --reset

# 4. 编译项目
anchor build

# 5. 运行测试（待实现）
anchor test
```

## 📁 项目结构

```
lp_module/
├── lp-staking/              # ⭐ Anchor 智能合约项目
│   ├── programs/
│   │   └── lp-staking/     # Rust 程序源码
│   │       ├── src/
│   │       │   ├── lib.rs               # 程序入口
│   │       │   ├── constants.rs         # 常量定义
│   │       │   ├── errors.rs            # 错误类型
│   │       │   ├── state/               # 状态账户
│   │       │   │   ├── pool_state.rs    # 池子状态
│   │       │   │   ├── user_position.rs # 用户仓位
│   │       │   │   └── reward_config.rs # 奖励配置
│   │       │   ├── instructions/        # 指令实现
│   │       │   │   └── initialize.rs    # 初始化
│   │       │   └── utils/               # 工具函数
│   │       │       └── reward_calculator.rs
│   │       └── Cargo.toml
│   ├── tests/              # 集成测试
│   ├── target/             # 编译输出
│   │   ├── deploy/         # 部署文件（.so）
│   │   └── idl/            # IDL JSON
│   └── Anchor.toml         # Anchor 配置
│
├── docs/                   # 📚 完整文档
│   ├── 01_流动性池与质押挖矿模块_整体设计文档.md
│   ├── 02_Docker开发环境使用文档.md
│   ├── 03_研发计划与开发指南.md
│   ├── 04_Anchor项目结构与代码说明.md
│   ├── 05_Solana和Anchor开发环境安装指南.md
│   ├── 06_开发进度报告_Phase1完成.md
│   └── 07_快速参考手册.md
│
├── scripts/                # 脚本工具
│   ├── dev.sh             # Docker 环境管理
│   └── setup-dev-env.sh   # 环境自动安装
│
├── Dockerfile             # Docker 镜像定义
├── docker-compose.yml     # Docker Compose 配置
└── README.md              # 本文件
```

## 🛠️ 常用命令

### Docker 环境管理

```bash
./scripts/dev.sh build      # 构建镜像
./scripts/dev.sh start      # 启动环境
./scripts/dev.sh stop       # 停止环境
./scripts/dev.sh shell      # 进入容器
./scripts/dev.sh restart    # 重启环境
```

### Anchor 项目开发

```bash
cd /workspace/lp-staking

# 编译项目
anchor build

# 运行测试
anchor test

# 部署到本地网络
anchor deploy

# 查看程序日志
solana logs

# 查看程序 ID
solana address -k target/deploy/lp_staking-keypair.json
```

### Solana 工具

```bash
# 查看余额
solana balance

# 空投测试 SOL
solana airdrop 10

# 查看配置
solana config get

# 查看账户
solana account <address>
```

## 🏗️ 核心架构

### 状态账户

| 账户类型 | PDA Seeds | 大小 | 说明 |
|---------|----------|------|------|
| **PoolState** | `["pool_state"]` | 193 字节 | 池子核心状态 |
| **UserPosition** | `["user_position", user, pool]` | 129 字节 | 用户持仓信息 |
| **RewardConfig** | `["reward_config", pool]` | 106 字节 | 奖励配置 |

### 已实现指令

| 指令 | 状态 | 功能 |
|-----|------|-----|
| `initialize` | ✅ 已完成 | 初始化池子和奖励系统 |
| `deposit` | ⏳ 开发中 | 存入 USDC，获得 LP Token |
| `withdraw` | 📋 计划中 | 赎回 LP Token，提取 USDC |
| `stake` | 📋 计划中 | 质押 LP Token 开始挖矿 |
| `unstake` | 📋 计划中 | 解除质押 LP Token |
| `claim` | 📋 计划中 | 领取累计奖励 |

### 奖励机制

#### 固定速率排放
```
user_reward = (user_staked / total_staked) × emission_rate × time_elapsed
```

#### 按块动态排放
```
current_rate = initial_rate × (decay_factor / 10000) ^ period
user_reward = (user_staked / total_staked) × current_rate × blocks_elapsed
```

## 📖 文档索引

### 设计文档
- [01_整体设计文档](docs/01_流动性池与质押挖矿模块_整体设计文档.md) - 完整系统设计
- [03_研发计划与开发指南](docs/03_研发计划与开发指南.md) - 详细开发计划

### 技术文档
- [04_Anchor项目结构与代码说明](docs/04_Anchor项目结构与代码说明.md) - 代码架构
- [05_Solana和Anchor开发环境安装指南](docs/05_Solana和Anchor开发环境安装指南.md) - 环境搭建
- [07_快速参考手册](docs/07_快速参考手册.md) - 快速查询

### 进度报告
- [06_开发进度报告_Phase1完成](docs/06_开发进度报告_Phase1完成.md) - 最新进度

### 环境文档
- [02_Docker开发环境使用文档](docs/02_Docker开发环境使用文档.md) - Docker 使用说明

## 🧪 测试

### 单元测试
```bash
# 运行 Rust 单元测试
cd lp-staking
cargo test --package lp-staking
```

### 集成测试（待实现）
```bash
# 运行 Anchor 集成测试
anchor test
```

## 🔍 程序信息

```
程序 ID:   21HQd5MFf1hK9skAe7Hctp535318QQLTQEn29kMeYAP8
版本:      0.1.0
Anchor:    0.32.1
Solana:    2.3.13
```

## 🐛 故障排查

### 常见问题

**编译错误**
```bash
anchor clean
cargo clean
anchor build
```

**测试验证器无法启动**
```bash
pkill solana-test-validator
solana-test-validator --reset
```

**账户不存在**
```bash
solana airdrop 10
```

更多问题请参考：[07_快速参考手册](docs/07_快速参考手册.md)

## 🗺️ 开发路线图

- [x] **Phase 1**: 项目初始化与环境搭建 ✅
- [ ] **Phase 2**: 核心功能实现（Deposit/Withdraw）⏳
- [ ] **Phase 3**: 质押功能（Stake/Unstake/Claim）
- [ ] **Phase 4**: 数据索引服务（ClickHouse）
- [ ] **Phase 5**: 集成测试与优化
- [ ] **Phase 6**: Devnet 部署

## 📝 许可

MIT License

## 👥 贡献

欢迎提交 Issue 和 Pull Request！

### 贡献指南
1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 📞 联系方式

- 项目负责人: [待定]
- 技术支持: [待定]
- 文档维护: LP Module Dev Team

---

**最后更新**: 2025-10-31  
**项目状态**: 🟢 活跃开发中  
**完成度**: ~15%
