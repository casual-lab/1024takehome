# Kafka 数据查看工具

这些脚本用于查看 Solana Geyser Kafka 插件生成的 Kafka 消息。

## 📋 可用脚本

### 1. `view_kafka.sh` - 交互式查看
交互式菜单,选择要查看的数据类型。

```bash
./view_kafka.sh
```

**功能:**
- ✅ 账户更新 (`solana.accounts`)
- ✅ 交易信息 (`solana.transactions`)
- ✅ 区块状态 (`solana.slots`)
- ✅ 区块元数据 (`solana.blocks`) ⭐ **NEW**
- ⏳ 程序日志 (`solana.program_logs`) - Stage 4
- ⏳ 链事件 (`solana.events`) - Stage 4
- 🔍 自定义 topic
- 📋 查看全部

### 2. `view_topic.sh` - 直接查看指定 topic
直接查看指定 Kafka topic 的消息。

```bash
# 基本用法
./view_topic.sh <topic_name> [max_messages]

# 示例
./view_topic.sh solana.blocks           # 查看区块元数据 (最多10条)
./view_topic.sh solana.blocks 20        # 查看区块元数据 (最多20条)
./view_topic.sh solana.accounts         # 查看账户更新
./view_topic.sh solana.transactions     # 查看交易
./view_topic.sh chain_blocks_metadata   # 使用自定义 topic 名称
```

### 3. `list_topics.sh` - 列出所有 topics
列出 Kafka 中存在的所有 topics。

```bash
./list_topics.sh
```

### 4. `view_kafka_data.py` - Python 查看脚本
底层 Python 脚本,解析 Protobuf 消息并美化显示。

```bash
# 直接使用 Python 脚本
python3 view_kafka_data.py --topic metadata --max 10
python3 view_kafka_data.py --raw-topic solana.blocks --max 20
python3 view_kafka_data.py --topic all --max 5
```

**参数:**
- `--topic`: 预定义的 topic 类型 (`accounts`, `txs`, `blocks`, `metadata`, `logs`, `events`, `all`)
- `--raw-topic`: 直接指定 Kafka topic 名称
- `--max`: 每个 topic 最多显示的消息数 (默认: 10)

## 📊 支持的数据类型

### ✅ 已实现 (Stage 1-3)

#### 1. 账户更新 (`solana.accounts`)
显示账户创建和更新事件:
- 账户公钥
- Owner 程序
- Lamports 余额
- 槽位、版本
- 账户数据

#### 2. 交易 (`solana.transactions`)
显示交易详情:
- 交易签名
- 成功/失败状态
- 手续费
- 计算单元消耗
- 指令和账户数量

#### 3. 区块状态 (`solana.slots`)
显示区块/槽位状态:
- 槽位编号
- 父槽位
- 状态 (Processed, Confirmed, Rooted, etc.)
- 确认计数

#### 4. 区块元数据 (`solana.blocks`) ⭐ **NEW**
显示详细的区块元数据:
- 槽位和区块哈希
- 父槽位和父哈希
- 区块时间和高度
- 已执行交易数量
- Entry 数量
- Data/Coding shreds 数量
- 奖励列表 (Fee, Rent, Staking, Voting)

### ⏳ 待实现 (Stage 4-8)

#### 5. 程序日志 (`solana.program_logs`)
程序执行日志 (需要 LogParser 模块):
- INVOKE - 程序调用
- LOG - 日志消息
- DATA - 程序数据
- SUCCESS/FAILED - 执行结果
- CONSUMED - 计算单元消耗

#### 6. 链事件 (`solana.events`)
Anchor 事件和自定义事件 (需要 LogParser 模块):
- 事件鉴别器
- 事件数据
- 解码后的数据
- 事件名称

## 🔧 配置

### Kafka 连接配置

默认连接配置 (在 `view_kafka_data.py` 中):

```python
bootstrap_servers=['localhost:19092']
security_protocol='SASL_PLAINTEXT'
sasl_mechanism='SCRAM-SHA-256'
sasl_plain_username='superuser'
sasl_plain_password='secretpassword'
```

如果你的 Kafka 使用不同的配置,请修改 `view_kafka_data.py` 中的 `consume_topic()` 函数。

### Topic 名称映射

根据你的 Geyser 插件配置,topic 名称可能不同:

**默认 topic 名称:**
```json
{
  "update_account_topic": "solana.accounts",
  "slot_status_topic": "solana.slots",
  "transaction_topic": "solana.transactions",
  "block_metadata_topic": "solana.blocks"
}
```

**自定义 topic 名称示例:**
```json
{
  "update_account_topic": "chain_accounts",
  "slot_status_topic": "chain_blocks",
  "transaction_topic": "chain_txs",
  "block_metadata_topic": "chain_blocks_metadata"
}
```

使用 `--raw-topic` 参数或选项 7 (自定义 topic) 来查看自定义名称的 topic。

## 📝 使用示例

### 场景 1: 查看最新的区块元数据

```bash
# 方法 1: 使用交互式脚本
./view_kafka.sh
# 选择选项 4

# 方法 2: 直接查看
./view_topic.sh solana.blocks 5

# 方法 3: 使用 Python 脚本
python3 view_kafka_data.py --topic metadata --max 5
```

### 场景 2: 监控账户更新

```bash
# 查看最近 20 条账户更新
./view_topic.sh solana.accounts 20
```

### 场景 3: 分析交易

```bash
# 查看最近 10 条交易
./view_topic.sh solana.transactions 10
```

### 场景 4: 查看所有数据类型

```bash
# 使用交互式脚本
./view_kafka.sh
# 选择选项 8 (全部查看)

# 或直接运行
python3 view_kafka_data.py --topic all --max 5
```

### 场景 5: 查看自定义 topic

```bash
# 如果你使用了自定义 topic 名称
./view_topic.sh chain_blocks_metadata 10
```

## 🐛 故障排除

### 问题 1: "找不到 event_pb2.py"

**原因:** Protobuf 定义文件未生成。

**解决方法:**
```bash
cd /home/ubuntu
protoc --python_out=. /home/ubuntu/ytest/solana-accountsdb-plugin-kafka/proto/event.proto
```

### 问题 2: "Topic 中没有消息"

**可能原因:**
1. Kafka 未运行
2. Solana 验证器未运行
3. Geyser 插件未正确配置
4. Topic 名称不匹配

**检查步骤:**
```bash
# 1. 检查 Kafka 是否运行
docker ps | grep redpanda

# 2. 检查验证器是否运行
pgrep -f solana-test-validator

# 3. 列出所有 topics
./list_topics.sh

# 4. 查看验证器日志
tail -f test-ledger/validator.log | grep -i kafka
```

### 问题 3: "无法连接到 Kafka"

**检查连接:**
```bash
# 测试 Kafka 端口
nc -zv localhost 19092

# 启动 Kafka
cd /home/ubuntu/ytest/redpanda-quickstart/docker-compose
docker-compose up -d
```

### 问题 4: "解析消息失败"

**可能原因:**
- Protobuf 定义不匹配
- 消息格式错误
- 使用了错误的 topic 类型

**解决方法:**
1. 确保 `event_pb2.py` 是最新的
2. 检查 topic 名称是否正确
3. 查看原始消息数据

## 📊 输出示例

### 区块元数据输出示例

```
📊 区块元数据 (chain_blocks_metadata) ⭐ NEW
────────────────────────────────────────────────────────────────────────────────
  slot:                12345
  blockhash:           8QwxYz...
  parent_slot:         12344
  parent_blockhash:    7PqxYw...
  block_time:          1698765432 (2023-10-31 10:30:32)
  block_height:        1000
  executed_tx_count:   42
  entry_count:         15
  data_shreds:         120
  coding_shreds:       30
  rewards:             3 reward(s)
    [1] pubkey: AbC123...
        lamports: 5,000
        post_balance: 1,005,000
        type: Staking
    [2] pubkey: DeF456...
        lamports: 100
        post_balance: 50,100
        type: Fee
    [3] pubkey: GhI789...
        lamports: 2,500
        post_balance: 502,500
        type: Voting
```

## 🔗 相关文档

- [Geyser 插件配置](../solana-accountsdb-plugin-kafka/config.json)
- [实现结果文档](../IMPLEMENTATION_RESULTS.md)
- [测试程序文档](../geyser-test-program/README.md)

## 💡 提示

1. **首次使用:** 运行 `./view_kafka.sh` 进行交互式查看
2. **快速查看:** 使用 `./view_topic.sh <topic>` 直接查看特定 topic
3. **列出 topics:** 使用 `./list_topics.sh` 查看所有可用的 topics
4. **调试:** 使用 `--max` 参数控制显示的消息数量
5. **自定义:** 修改 `view_kafka_data.py` 来定制输出格式

## 🎯 下一步

完成 Stage 4 后,将能够查看:
- 📝 程序日志 (`solana.program_logs`)
- 🎯 链事件 (`solana.events`)

这将提供完整的链上活动可观测性!
