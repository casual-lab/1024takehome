# Geyser 插件 Kafka Topics 完整说明

## 概述

本文档详细说明了 `solana-accountsdb-plugin-kafka` Geyser 插件向 Kafka 发送的所有数据类型和对应的 topic。

## 插件架构

```
Solana Validator
    ↓
Geyser Plugin Interface
    ↓
solana-accountsdb-plugin-kafka
    ↓ (通过 rdkafka)
Kafka Broker (Redpanda)
    ↓
ClickHouse / 其他消费者
```

## Kafka Topics 配置

基于 `config.json` 的实际配置：

### 1. **solana.chain_accounts** - 账户更新
- **消息类型**: `UpdateAccountEvent`
- **触发时机**: 账户数据变化时
- **配置项**: `update_account_topic`
- **主要字段**:
  - `slot`: 槽位号
  - `pubkey`: 账户公钥 (32字节)
  - `owner`: 所有者程序 ID
  - `lamports`: 账户余额
  - `data`: 账户数据
  - `write_version`: 写入版本号
  - `txn_signature`: 触发此更新的交易签名
  - `is_startup`: 是否为启动时的账户快照
  - `executable`: 是否为可执行账户

### 2. **solana.slots** - 插槽状态
- **消息类型**: `SlotStatusEvent`
- **触发时机**: 插槽状态变化时
- **配置项**: `slot_status_topic`
- **主要字段**:
  - `slot`: 槽位号
  - `parent`: 父槽位号
  - `status`: 状态 (Processed=0, Rooted=1, Confirmed=2, FirstShredReceived=3, Completed=4, CreatedBank=5, Dead=0xDEAD)
  - `is_confirmed`: 是否已确认
  - `confirmation_count`: 确认数量
  - `status_description`: 状态描述

### 3. **solana.chain_txs** - 交易
- **消息类型**: `TransactionEvent`
- **触发时机**: 每笔交易执行后
- **配置项**: `transaction_topic`
- **主要字段**:
  - `signature`: 交易签名 (64字节)
  - `slot`: 槽位号
  - `is_vote`: 是否为投票交易
  - `is_successful`: 是否成功
  - `transaction`: 完整的交易数据
    - `message`: 消息 (Legacy 或 V0)
    - `signatures`: 签名列表
  - `transaction_status_meta`: 执行元数据
    - `fee`: 交易费用
    - `compute_units_consumed`: 消耗的计算单元
    - `pre_balances` / `post_balances`: 执行前后余额
    - `log_messages`: 日志消息
    - `error_info`: 错误信息 (如果失败)
  - `compute_units_price`: 计算单元价格
  - `instruction_count`: 指令数量
  - `account_count`: 涉及的账户数量

### 4. **solana.chain_blocks** - 区块元数据
- **消息类型**: `BlockMetadataEvent` **或** `SlotStatusEvent`
- **触发时机**: 
  - `BlockMetadataEvent`: 区块完全完成时（较少见）
  - `SlotStatusEvent`: 插槽状态变化时（更频繁）
- **配置项**: `block_metadata_topic`
- **重要说明**: ⚠️ **由于 Solana 验证器可能不频繁调用 `notify_block_metadata`，这个 topic 实际上大部分时候接收的是 `SlotStatusEvent`（插槽状态），而不是完整的区块元数据。真正的区块元数据（包含 blockhash）只在区块完全完成时才会发送。**
- **BlockMetadataEvent 主要字段**:
  - `slot`: 槽位号
  - `block_hash`: 区块哈希 (base58) - **注意：通常为空**
  - `parent_slot`: 父槽位号
  - `parent_block_hash`: 父区块哈希 - **注意：通常为空**
  - `leader`: 区块领导者公钥
  - `executed_transaction_count`: 执行的交易数量
  - `block_time`: Unix 时间戳
  - `block_height`: 区块高度
  - `rewards`: 奖励列表
    - `pubkey`: 接收者公钥
    - `lamports`: 奖励金额
    - `reward_type`: 奖励类型 (Fee=1, Rent=2, Staking=3, Voting=4)
  - `total_compute_units`: 总计算单元
  - `total_fees`: 总费用
- **SlotStatusEvent 字段**（参见上面的插槽状态说明）

### 5. **solana.chain_program_logs** - 程序日志
- **消息类型**: `ProgramLogEvent`
- **触发时机**: 程序执行产生日志时
- **配置项**: `program_log_topic`
- **需要配置**: `extract_program_logs: true`
- **主要字段**:
  - `slot`: 槽位号
  - `tx_signature`: 交易签名
  - `tx_index`: 交易在区块中的索引
  - `program_id`: 程序 ID (base58)
  - `log_type`: 日志类型
    - `UNKNOWN = 0`
    - `INVOKE = 1` - "Program XXX invoke [N]"
    - `LOG = 2` - "Program log: XXX"
    - `DATA = 3` - "Program data: XXX"
    - `SUCCESS = 4` - "Program XXX success"
    - `FAILED = 5` - "Program XXX failed: XXX"
    - `CONSUMED = 6` - "Program XXX consumed N compute units"
  - `log_index`: 日志在交易中的索引
  - `depth`: 调用深度 (1=顶层, 2+=CPI调用)
  - `message`: 日志消息内容

### 6. **solana.chain_events** - 链事件 (Anchor 事件)
- **消息类型**: `ChainEvent`
- **触发时机**: 检测到 Anchor 事件或自定义事件时
- **配置项**: `chain_event_topic`
- **需要配置**: `extract_anchor_events: true`
- **主要字段**:
  - `slot`: 槽位号
  - `tx_signature`: 交易签名
  - `tx_index`: 交易索引
  - `program_id`: 发出事件的程序 ID
  - `event_discriminator`: 事件鉴别器 (8字节)
  - `event_type`: 事件类型名称 (可选)
  - `raw_data`: 原始事件数据 (Borsh 编码)
  - `json_payload`: JSON 表示 (如果可解析)
  - `log_index`: 对应的日志索引

## 配置选项说明

### 过滤器配置 (filters)

```json
{
  "filters": [{
    // Topic 配置
    "update_account_topic": "solana.chain_accounts",
    "slot_status_topic": "solana.slots",
    "transaction_topic": "solana.chain_txs",
    "block_metadata_topic": "solana.chain_blocks",
    "program_log_topic": "solana.chain_program_logs",
    "chain_event_topic": "solana.chain_events",
    
    // 程序过滤
    "program_ignores": [],        // 忽略的程序列表
    "program_filters": [],        // 只包含的程序列表
    
    // 账户过滤
    "account_filters": [],        // 只包含的账户列表
    
    // 事件过滤
    "event_discriminators": [],   // 要捕获的事件鉴别器 (hex)
    
    // 行为控制
    "publish_all_accounts": false,        // 启动时发布所有账户
    "include_vote_transactions": false,   // 包含投票交易
    "include_failed_transactions": true,  // 包含失败的交易
    
    // 功能开关
    "extract_program_logs": true,         // 提取程序日志
    "extract_anchor_events": true,        // 提取 Anchor 事件
    "wrap_messages": false                // 使用 MessageWrapper 包装
  }]
}
```

### MessageWrapper 模式

当 `wrap_messages: true` 时，所有消息会被包装在 `MessageWrapper` 中：

```protobuf
message MessageWrapper {
  oneof event_message {
    UpdateAccountEvent account = 1;
    SlotStatusEvent slot = 2;
    TransactionEvent transaction = 3;
    BlockMetadataEvent block = 4;
    ProgramLogEvent program_log = 5;
    ChainEvent chain_event = 6;
  }
}
```

这样可以在单个 topic 中发送多种类型的消息，但会增加消息大小。

## Kafka 消息键 (Key)

插件使用以下键策略：

| Topic | 键内容 | 包装模式键前缀 |
|-------|--------|---------------|
| accounts | pubkey (32 bytes) | 'A' + pubkey |
| slots | slot (8 bytes, little-endian) | 'S' + slot |
| transactions | signature (64 bytes) | 'T' + signature |
| blocks | slot (8 bytes, little-endian) | 'B' + slot |
| program_logs | tx_signature (64 bytes) | 'L' + signature |
| chain_events | tx_signature (64 bytes) | 'E' + signature |

## 使用工具查看数据

### 1. 使用 view_topic.sh

```bash
# 查看账户更新
./view_topic.sh solana.chain_accounts 10

# 查看交易
./view_topic.sh solana.chain_txs 20

# 查看插槽状态
./view_topic.sh solana.slots 5

# 查看区块元数据
./view_topic.sh solana.chain_blocks 10

# 查看程序日志
./view_topic.sh solana.chain_program_logs 50

# 查看链事件
./view_topic.sh solana.chain_events 30
```

### 2. 使用 view_kafka_data.py

```bash
# 查看所有类型的数据
python3 view_kafka_data.py --topic all --max 5

# 只查看账户
python3 view_kafka_data.py --topic accounts --max 10

# 直接指定 topic
python3 view_kafka_data.py --raw-topic solana.chain_accounts --max 20
```

## Protobuf 定义位置

- **源文件**: `solana-accountsdb-plugin-kafka/proto/event.proto`
- **生成的 Python**: `event_pb2.py` (需要使用 protoc 生成)

## 性能指标 (Prometheus)

插件暴露以下 Prometheus 指标 (端口 9091):

- `kafka_upload_accounts_total{status="success|failed"}` - 账户上传计数
- `kafka_upload_slots_total{status="success|failed"}` - 插槽上传计数
- `kafka_upload_transactions_total{status="success|failed"}` - 交易上传计数
- `kafka_upload_blocks_total{status="success|failed"}` - 区块上传计数
- `kafka_upload_program_logs_total{status="success|failed"}` - 程序日志上传计数
- `kafka_upload_events_total{status="success|failed"}` - 事件上传计数

## 故障排查

### 1. Topic 中没有数据

检查：
- Solana 验证器是否正在运行
- Geyser 插件是否正确加载 (检查验证器日志)
- Kafka broker 是否可访问
- 配置文件中的 topic 名称是否正确

### 2. 解析消息失败

可能原因：
- Protobuf 定义不匹配 (重新生成 event_pb2.py)
- 插件版本与解析脚本不匹配
- 使用了 wrap_messages 但解析时未处理

### 3. block_hash 和 parent_block_hash 为空

**这是正常现象！** 原因：

1. **Geyser 回调频率问题**: Solana 验证器的 `notify_block_metadata` 回调只在区块**完全完成并确认**时才会被调用，这个频率相对较低。

2. **配置混淆**: 配置文件中的 `block_metadata_topic` 设置为 `solana.chain_blocks`，但实际上这个 topic 会接收两种类型的消息：
   - `BlockMetadataEvent` - 真正的区块元数据（包含 blockhash，但很少）
   - `SlotStatusEvent` - 插槽状态更新（更频繁，没有 blockhash）

3. **Protobuf 兼容性**: 由于 `BlockMetadataEvent` 和 `SlotStatusEvent` 共享一些字段（如 slot, parent_slot），protobuf 可以"成功"解析，但缺少的字段会显示为空。

**解决方案**：
- 如果需要完整的区块元数据（包括 blockhash），应该使用 RPC 调用 `getBlock` 来获取
- 如果只需要插槽状态，使用 `solana.slots` topic（`slot_status_topic`）
- 更新后的 `view_kafka_data.py` 脚本会自动检测消息类型并正确显示

**建议配置**：
```json
{
  "slot_status_topic": "solana.slots",           // 插槽状态（频繁）
  "block_metadata_topic": "solana.block_meta",   // 区块元数据（罕见）
}
```

这样可以更清楚地区分两种不同的数据流。

### 4. 性能问题

优化建议：
- 调整 `batch.size` 和 `linger.ms` 参数
- 使用程序/账户过滤器减少数据量
- 考虑禁用不需要的功能 (如 program_logs, events)
- 增加 Kafka 分区数量

## 相关文档

- [CONFIG_TABLES_MAPPING.md](./solana-accountsdb-plugin-kafka/CONFIG_TABLES_MAPPING.md) - 配置和数据库表映射
- [ARCHITECTURE_ANALYSIS.md](./solana-accountsdb-plugin-kafka/ARCHITECTURE_ANALYSIS.md) - 插件架构分析
- [Protobuf 定义](./solana-accountsdb-plugin-kafka/proto/event.proto) - 完整的消息格式定义
