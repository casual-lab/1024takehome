# Geyser Kafka Plugin Test Program

这是一个用于测试和演示 Solana Geyser Kafka 插件功能的 Anchor 测试程序。

## 程序功能

该测试程序包含 4 个指令，用于触发不同类型的 Kafka 事件:

### 1. `initialize` - 初始化计数器
- 创建一个新的 Counter 账户
- 触发账户创建事件 (chain_accounts)
- 生成初始化日志

### 2. `increment` - 递增计数器
- 将计数器值加 1
- 触发账户更新事件 (chain_accounts)
- 生成程序日志 (chain_program_logs)

### 3. `complex_operation` - 复杂操作
- 执行多步操作
- 生成多条程序日志
- 模拟 Anchor 事件 (chain_events)

### 4. `transfer_sol` - SOL 转账
- 在账户间转移 SOL
- 触发多个账户更新事件

## 项目结构

```
geyser-test-program/
├── programs/
│   └── geyser-test-program/
│       ├── src/
│       │   └── lib.rs              # 主程序代码
│       └── Cargo.toml
├── tests/
│   └── geyser-test.ts              # TypeScript 测试套件
├── deploy.sh                       # 部署脚本
├── run_tests.sh                    # 测试运行脚本
├── start_validator_with_geyser.sh  # 启动带 Geyser 的验证器
├── demo.ts                         # 交互式演示脚本
├── Anchor.toml                     # Anchor 配置
└── README.md                       # 本文档
```

## 前置要求

1. **Rust 工具链**
   ```bash
   rustc --version  # 应该是 1.79.0 或更高
   ```

2. **Solana CLI**
   ```bash
   solana --version
   solana-keygen new  # 如果还没有钱包
   ```

3. **Node.js 和 Yarn**
   ```bash
   node --version
   yarn --version
   ```

4. **Kafka (RedPanda)**
   ```bash
   cd /home/ubuntu/ytest/redpanda-quickstart
   docker-compose up -d
   ```

5. **Geyser 插件已编译**
   ```bash
   cd /home/ubuntu/ytest/solana-accountsdb-plugin-kafka
   cargo build --release
   ```

## 快速开始

### 方案 1: 完整演示 (推荐)

按顺序执行以下步骤:

```bash
cd /home/ubuntu/ytest/geyser-test-program

# 1. 编译和部署程序
./deploy.sh

# 2. 启动带 Geyser 插件的测试验证器
./start_validator_with_geyser.sh

# 3. 运行演示脚本
npx ts-node demo.ts
```

### 方案 2: 运行测试套件

```bash
# 使用已启动的验证器运行测试
./run_tests.sh
```

### 方案 3: 手动步骤

```bash
# 1. 编译程序
cargo build-sbf

# 2. 部署程序
solana program deploy target/deploy/geyser_test_program.so

# 3. 启动验证器(不带 Geyser)
solana-test-validator

# 4. 在另一个终端运行测试
yarn install
yarn test
```

## 监控 Kafka 消息

在运行测试时,可以在另一个终端监控 Kafka 消息:

```bash
cd /home/ubuntu/ytest

# 监控账户更新
./view_kafka.sh chain_accounts

# 监控交易
./view_kafka.sh chain_txs

# 监控区块元数据
./view_kafka.sh chain_blocks_metadata

# 监控程序日志 (Stage 4 完成后)
./view_kafka.sh chain_program_logs

# 监控事件 (Stage 4 完成后)
./view_kafka.sh chain_events
```

## Geyser 配置

生成的 `geyser-config.json` 配置文件包含以下设置:

```json
{
  "update_account_topic": "chain_accounts",      // 账户更新
  "update_slot_topic": "chain_blocks",           // 区块信息
  "notify_transaction_topic": "chain_txs",       // 交易
  "block_metadata_topic": "chain_blocks_metadata", // 区块元数据 (新增)
  "program_log_topic": "chain_program_logs",     // 程序日志 (Stage 4)
  "chain_event_topic": "chain_events",           // 链事件 (Stage 4)
  "extract_program_logs": true,                  // 提取日志
  "extract_anchor_events": true,                 // 提取 Anchor 事件
  "event_discriminators": []                     // 事件过滤器
}
```

## 预期的 Kafka 事件

运行演示程序后,应该在 Kafka 中看到以下事件:

### 1. Initialize 指令
- **chain_accounts**: Counter 账户创建
  - `account`: Counter 账户地址
  - `owner`: 程序 ID
  - `data`: 账户数据 (count=0)
  
- **chain_txs**: 初始化交易
  - `signature`: 交易签名
  - `success`: true
  - `instructions`: initialize 指令
  
- **chain_blocks_metadata**: 包含该交易的区块
  - `slot`: 区块槽位
  - `block_hash`: 区块哈希
  - `transaction_count`: 交易数量

### 2. Increment 指令
- **chain_accounts**: Counter 账户更新 (count+1)
- **chain_txs**: Increment 交易
- **chain_program_logs** (Stage 4): 
  - "Program log: Incrementing counter"
  - "Program data: <base64_encoded_count>"

### 3. Complex Operation 指令
- **chain_accounts**: Counter 账户更新
- **chain_txs**: ComplexOperation 交易
- **chain_program_logs** (Stage 4): 多条日志
  - "Starting complex operation"
  - "Processing data"
  - "Operation complete"
- **chain_events** (Stage 4): 模拟的事件数据

### 4. Transfer SOL 指令
- **chain_accounts**: 2 个账户更新 (发送者和接收者)
- **chain_txs**: Transfer 交易

## 实现状态

### ✅ 已完成 (Stage 1-3)
- ✅ Block metadata 事件 (`chain_blocks_metadata` topic)
- ✅ Transaction 事件 (`chain_txs` topic)
- ✅ Account updates 事件 (`chain_accounts` topic)
- ✅ 基础配置和过滤器扩展
- ✅ Prometheus 监控指标

### ⏳ 待完成 (Stage 4-8)
- ⏳ **Stage 4** (2 days): LogParser 模块
  - 解析 log_messages
  - 提取程序调用栈
  - 识别 7 种日志类型
  - 解码 Anchor 事件
  
- ⏳ **Stage 5** (1 day): 集成 LogParser 到 notify_transaction
  - 发布 program_log 事件
  - 发布 chain_event 事件
  
- ⏳ **Stage 6** (0.5 day): Publisher 批量方法
- ⏳ **Stage 7** (1 day): 集成测试
- ⏳ **Stage 8** (0.5 day): 文档更新

## 程序 ID

默认程序 ID: `Fg6PaFpoGXkYsidMpWTK6W2BeZ7FEfcYkg476zPFsLnS`

如果需要更改,修改以下文件:
1. `programs/geyser-test-program/src/lib.rs` - `declare_id!()` 宏
2. `Anchor.toml` - `[programs.localnet]` 部分

## 故障排除

### 编译错误
```bash
# 确保使用正确的 Rust 版本
rustup default 1.79.0
cargo clean
cargo build-sbf
```

### 部署失败
```bash
# 检查余额
solana balance

# 请求空投
solana airdrop 2

# 检查连接
solana config get
```

### 验证器启动失败
```bash
# 停止现有验证器
pkill -f solana-test-validator

# 清理测试账本
rm -rf test-ledger

# 重新启动
./start_validator_with_geyser.sh
```

### Kafka 连接失败
```bash
# 检查 Kafka 状态
docker ps | grep redpanda

# 重启 Kafka
cd /home/ubuntu/ytest/redpanda-quickstart
docker-compose restart

# 测试连接
nc -zv localhost 9092
```

## 查看日志

```bash
# 验证器日志
tail -f test-ledger/validator.log

# Geyser 插件日志 (在验证器日志中)
grep -i geyser test-ledger/validator.log

# Kafka 日志
docker logs -f redpanda-redpanda-1
```

## 性能测试

可以修改 `demo.ts` 或创建自定义脚本来进行性能测试:

```typescript
// 批量测试
for (let i = 0; i < 100; i++) {
    await program.methods.increment()
        .accounts({ counter: counter.publicKey })
        .rpc();
}
```

## 相关文档

- [Solana Geyser Plugin Interface](https://docs.solana.com/developing/plugins/geyser-plugins)
- [Anchor Framework](https://www.anchor-lang.com/)
- [Kafka](https://kafka.apache.org/documentation/)
- [实现计划](/home/ubuntu/ytest/REFACTORING_PLAN.md)

## 支持

如有问题,请查看:
1. `REFACTORING_PLAN.md` - 详细的实现计划
2. `ARCHITECTURE_ANALYSIS.md` - 架构分析
3. Validator 日志: `test-ledger/validator.log`
