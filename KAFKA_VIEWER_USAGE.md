# Kafka Topic 查看器使用指南

## 概述

提供了两个脚本来查看 Kafka 中的 Solana 数据：
- `view_topic.sh` - 快速命令行工具
- `view_kafka_data.py` - 完整的 Python 工具

## 功能特性

✅ 支持所有 6 种 Geyser 插件数据类型  
✅ 自动解析 Protobuf 消息  
✅ 美化输出显示  
✅ **灵活的 offset 控制**（earliest/latest/数字）  
✅ **可选的消息删除**（通过提交 offset）  
✅ 智能消息类型检测  

## 使用方法

### 1. 使用 view_topic.sh（推荐）

#### 基本用法

```bash
# 查看账户更新（默认从最早开始，显示 10 条）
./view_topic.sh solana.chain_accounts

# 查看交易数据，显示 20 条
./view_topic.sh solana.chain_txs 20

# 查看插槽状态，显示 5 条
./view_topic.sh solana.slots 5
```

#### Offset 控制

```bash
# 从最早的消息开始（默认）
./view_topic.sh solana.chain_accounts 10 earliest

# 从最新的消息开始（等待新消息）
./view_topic.sh solana.chain_txs 10 latest

# 从指定的 offset 开始
./view_topic.sh solana.chain_accounts 10 100
./view_topic.sh solana.chain_txs 20 1000
```

#### 消息删除（提交 offset）

```bash
# 读取前 50 条消息并标记为已消费
./view_topic.sh solana.slots 50 earliest --delete

# 从 offset 100 开始读取 10 条并删除
./view_topic.sh solana.chain_accounts 10 100 --delete
```

**⚠️ 注意**: 
- "删除"实际上是提交 offset 到 consumer group
- 消息本身不会从 Kafka 删除，只是被标记为已消费
- 下次使用 `--delete` 时会从新的位置开始
- Kafka 会根据保留策略自动清理旧消息

### 2. 使用 view_kafka_data.py

#### 基本用法

```bash
# 查看所有类型的数据（各 5 条）
python3 view_kafka_data.py --topic all --max 5

# 查看特定类型
python3 view_kafka_data.py --topic accounts --max 10
python3 view_kafka_data.py --topic txs --max 20
python3 view_kafka_data.py --topic slots --max 5
python3 view_kafka_data.py --topic blocks --max 10
python3 view_kafka_data.py --topic logs --max 50
python3 view_kafka_data.py --topic events --max 30
```

#### 直接指定 Topic

```bash
# 使用原始 topic 名称
python3 view_kafka_data.py --raw-topic solana.chain_accounts --max 20

# 自定义 topic（如果配置文件不同）
python3 view_kafka_data.py --raw-topic my.custom.topic --max 10
```

#### Offset 控制

```bash
# 从最早开始
python3 view_kafka_data.py --topic accounts --offset earliest --max 10

# 从最新开始
python3 view_kafka_data.py --topic txs --offset latest --max 10

# 从指定 offset 开始
python3 view_kafka_data.py --topic accounts --offset 500 --max 20
```

#### 消息删除

```bash
# 读取并标记为已消费
python3 view_kafka_data.py --topic accounts --max 100 --delete

# 从指定 offset 开始读取并删除
python3 view_kafka_data.py --raw-topic solana.chain_txs --offset 1000 --max 50 --delete
```

## 可用的 Kafka Topics

基于当前的 Geyser 插件配置（`config.json`）：

| Topic | 数据类型 | 说明 |
|-------|---------|------|
| `solana.chain_accounts` | UpdateAccountEvent | 账户更新 |
| `solana.slots` | SlotStatusEvent | 插槽状态 |
| `solana.chain_txs` | TransactionEvent | 交易数据 |
| `solana.chain_blocks` | BlockMetadataEvent / SlotStatusEvent | 区块元数据（通常是插槽状态） |
| `solana.chain_program_logs` | ProgramLogEvent | 程序日志 |
| `solana.chain_events` | ChainEvent | Anchor 事件 |

## Offset 说明

### Offset 类型

1. **earliest** - 从最早的消息开始
   - 适用于查看历史数据
   - 如果 topic 有大量消息，可能需要较长时间

2. **latest** - 从最新的消息开始
   - 适用于实时监控新消息
   - 会等待新消息到达（timeout 5 秒）

3. **数字** - 从指定的 offset 开始
   - 精确控制读取位置
   - offset 从 0 开始计数
   - 示例：`100`, `1000`, `50000`

### 查看当前 Offset

使用 Kafka 命令行工具：

```bash
# 查看 topic 的 offset 范围
rpk topic describe solana.chain_accounts -X brokers=localhost:19092

# 查看 consumer group 的提交位置
rpk group describe view_kafka_consumer -X brokers=localhost:19092
```

## 实际使用场景

### 场景 1: 调试插件配置

```bash
# 检查是否有账户数据
./view_topic.sh solana.chain_accounts 5

# 检查交易是否包含失败的
./view_topic.sh solana.chain_txs 20

# 检查程序日志是否正确提取
./view_topic.sh solana.chain_program_logs 10
```

### 场景 2: 数据采样

```bash
# 采样前 100 条账户更新并标记为已处理
./view_topic.sh solana.chain_accounts 100 earliest --delete

# 从中间位置采样
./view_topic.sh solana.chain_txs 50 1000
```

### 场景 3: 实时监控

```bash
# 监控新的交易
./view_topic.sh solana.chain_txs 10 latest

# 持续监控插槽状态
watch -n 5 "./view_topic.sh solana.slots 5 latest"
```

### 场景 4: 清理已处理的消息

```bash
# 批量标记为已消费（模拟消费者处理）
./view_topic.sh solana.chain_accounts 1000 earliest --delete
./view_topic.sh solana.chain_txs 5000 earliest --delete
```

## 输出示例

### 账户更新

```
📦 账户更新 (chain_accounts)
────────────────────────────────────────────────────────────────────────────────
  pubkey:         9bcd9fafe7bcb79833665b53b613a4e0d957e4a8413cdb1ee724b45e0a9e30cb
  owner_program:  0761481d357474bb7c4d7624ebd3bdb3d8355e73d11043fc0da3538000000000
  lamports:       27,074,400
  slot:           2,664
  write_version:  0
  executable:     False
  rent_epoch:     18446744073709551615
  data:           03000000a48011c3849100b7199581f4... (3762 bytes)
  data_version:   0
  is_startup:     True
  account_age:    0
```

### 交易

```
💳 交易 (chain_txs)
────────────────────────────────────────────────────────────────────────────────
  tx_signature:   012d34ac60424f75cb748355b17fd900dcf5ccaec1923e816786e9f3f5d6e837...
  slot:           41,602
  status:         ✅ success
  is_vote:        True
  fee:            5,000 lamports
  compute_units:  2,100
  compute_price:  0
  total_cost:     5,000
  instructions:   1
  accounts:       3
```

### 插槽状态

```
🔷 区块/插槽状态 (chain_blocks)
────────────────────────────────────────────────────────────────────────────────
  slot:               70,245
  parent_slot:        70,244
  status:             Rooted
  is_confirmed:       True
  confirmation_count: 2
  status_description: Rooted - highest slot having reached max vote lockout
```

## 故障排查

### 问题 1: 没有消息

```bash
# 检查 topic 是否存在
rpk topic list -X brokers=localhost:19092

# 检查 Solana 验证器日志
tail -f /path/to/validator.log | grep -i geyser
```

### 问题 2: Protobuf 解析错误

```bash
# 重新生成 protobuf 文件
cd /home/ubuntu/ytest
protoc --experimental_allow_proto3_optional --python_out=. \
  solana-accountsdb-plugin-kafka/proto/event.proto

# 设置环境变量
export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python
```

### 问题 3: Offset 错误

```bash
# 重置 consumer group offset
rpk group seek view_kafka_consumer --to start -X brokers=localhost:19092
rpk group seek view_kafka_consumer --to end -X brokers=localhost:19092
```

## 高级技巧

### 1. 批量处理

```bash
# 处理所有 topic 的前 100 条消息
for topic in solana.chain_accounts solana.chain_txs solana.slots; do
  ./view_topic.sh $topic 100 earliest --delete
done
```

### 2. 数据导出

```bash
# 导出到文件
./view_topic.sh solana.chain_txs 1000 > transactions.log

# 只导出特定字段（使用 jq 或其他工具处理）
python3 view_kafka_data.py --topic txs --max 1000 > txs.txt
```

### 3. 性能监控

```bash
# 查看消费速度
time ./view_topic.sh solana.chain_accounts 10000 earliest

# 监控 lag
watch -n 1 "rpk group describe view_kafka_consumer -X brokers=localhost:19092"
```

## 相关文档

- [GEYSER_KAFKA_TOPICS.md](./GEYSER_KAFKA_TOPICS.md) - Topic 详细说明
- [CONFIG_TABLES_MAPPING.md](./solana-accountsdb-plugin-kafka/CONFIG_TABLES_MAPPING.md) - 配置映射
- [Kafka Viewer README](./KAFKA_VIEWER_README.md) - 技术细节
