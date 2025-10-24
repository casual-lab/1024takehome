# Kafka to ClickHouse 数据同步设计方案

## 1. 项目概述

### 1.1 目标
将 Solana Geyser Plugin 通过 Kafka 输出的数据同步写入 ClickHouse 数据库，实现高性能的链上数据分析和查询。

### 1.2 数据流架构

```
┌─────────────────┐       ┌──────────────┐       ┌─────────────────┐       ┌──────────────┐
│ Solana Validator│──────>│Geyser Plugin │──────>│     Kafka       │──────>│  ClickHouse  │
│                 │       │ (Rust)       │       │  (6 Topics)     │       │  (Database)  │
└─────────────────┘       └──────────────┘       └─────────────────┘       └──────────────┘
                                                           │
                                                           │
                                                           ▼
                                                  ┌─────────────────┐
                                                  │  Kafka Consumer │
                                                  │  + ClickHouse   │
                                                  │     Writer      │
                                                  │   (Rust/Go)     │
                                                  └─────────────────┘
```

### 1.3 数据表映射

| Kafka Topic | ClickHouse Table | 数据内容 | 配置项 | 预估 QPS | 状态 |
|-------------|------------------|----------|--------|----------|------|
| `solana.chain_blocks` | `chain_blocks` | 区块信息 | `slot_status_topic` | ~2-3 | ⚠️ 部分支持 |
| `solana.chain_txs` | `chain_txs` | 交易明细 | `transaction_topic` | ~3000 | ✅ 完全支持 |
| `solana.chain_accounts` | `chain_accounts` | 账户快照 | `update_account_topic` | ~1000 | ✅ 完全支持 |
| `solana.chain_program_logs` | `chain_program_logs` | 程序日志 | `program_log_topic` | ~5000 | ✅ 完全支持 |
| `solana.chain_events` | `chain_events` | Anchor 事件 | `chain_event_topic` | ~500 | ✅ 完全支持 |

---

## 2. 技术选型

### 2.1 方案对比

#### 方案 A: 独立的 Rust 消费者服务 ⭐ 推荐

**优点：**
- ✅ 高性能：Rust 零成本抽象，内存安全
- ✅ 类型安全：与 Geyser Plugin 共享 Protobuf 定义
- ✅ 易于部署：单一二进制文件
- ✅ 可复用：可以扩展到其他数据库（PostgreSQL、TimescaleDB）
- ✅ 可观测性：内置 Prometheus 指标

**缺点：**
- ❌ 开发周期稍长（3-5 天）

**技术栈：**
```
- rdkafka (Kafka 客户端)
- clickhouse-rs (ClickHouse 客户端)
- prost (Protobuf 解析)
- tokio (异步运行时)
- prometheus (监控指标)
```

#### 方案 B: ClickHouse Kafka 引擎

**优点：**
- ✅ 无需额外服务
- ✅ SQL 声明式配置

**缺点：**
- ❌ 功能受限：难以处理复杂的数据转换
- ❌ 错误处理困难
- ❌ 不支持 Protobuf（需要用 JSON 格式）
- ❌ 性能受限于 ClickHouse 内置引擎

#### 方案 C: Kafka Connect + JDBC Sink

**优点：**
- ✅ 成熟的生态系统

**缺点：**
- ❌ Java 运行时依赖重
- ❌ 需要额外的 Kafka Connect 集群
- ❌ 配置复杂
- ❌ Protobuf 支持有限

#### 方案 D: Python/Go 消费者脚本

**优点：**
- ✅ 快速原型开发

**缺点：**
- ❌ 性能较差
- ❌ 运行时依赖多
- ❌ 生产环境稳定性问题

### 2.2 最终选择：方案 A - Rust 独立服务

基于以下考虑：
1. **性能要求高**：预计峰值 10,000+ 消息/秒
2. **类型安全**：Protobuf 定义可复用
3. **运维简单**：单一二进制，无运行时依赖
4. **可扩展性**：未来可支持多个数据库

---

## 3. ClickHouse 表结构设计

### 3.1 chain_blocks 表

```sql
CREATE TABLE chain_blocks (
    -- 主键
    slot UInt64,
    
    -- 区块信息
    blockhash String,
    parent_slot UInt64,
    parent_blockhash String,
    leader String,                      -- 区块生产者公钥
    num_txs UInt32,                     -- 交易数量
    
    -- 区块状态
    status Enum8(
        'Processed' = 1, 
        'Confirmed' = 2, 
        'Rooted' = 3, 
        'FirstShredReceived' = 4,
        'Completed' = 5, 
        'CreatedBank' = 6, 
        'Dead' = 7
    ),
    
    -- 时间戳
    timestamp DateTime,                 -- 区块时间
    ingested_at DateTime DEFAULT now(), -- 数据入库时间
    
    -- 统计信息（可选，从 metadata 迁移）
    executed_transaction_count UInt32 DEFAULT 0,
    total_compute_units UInt32 DEFAULT 0,
    total_fees UInt64 DEFAULT 0
) ENGINE = ReplacingMergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (slot, blockhash)
SETTINGS index_granularity = 8192;

-- 索引
CREATE INDEX idx_leader ON chain_blocks (leader) TYPE bloom_filter GRANULARITY 1;
CREATE INDEX idx_timestamp ON chain_blocks (timestamp) TYPE minmax GRANULARITY 1;
```

**设计说明：**
- `ReplacingMergeTree`：自动去重，处理重复区块更新
- 分区策略：按月分区（基于 timestamp）
- 主键排序：`(slot, blockhash)` 支持快速区块查询

### 3.2 chain_txs 表

```sql
CREATE TABLE chain_txs (
    -- 主键
    slot UInt64,
    tx_signature String,
    tx_index UInt64,                    -- 区块内交易索引
    
    -- 交易状态
    status Enum8('Success' = 1, 'Failed' = 2) DEFAULT 'Success',
    is_vote UInt8,
    error_info String DEFAULT '',
    
    -- 账户信息
    account_keys Array(String),
    num_required_signatures UInt8,
    num_readonly_signed_accounts UInt8,
    num_readonly_unsigned_accounts UInt8,
    
    -- 指令信息
    num_instructions UInt32,
    instructions Array(Tuple(
        program_id_index UInt8,
        accounts Array(UInt8),
        data String
    )),
    
    -- 资源消耗
    compute_units_consumed Nullable(UInt64),
    fee UInt64,
    
    -- 余额变动
    pre_balances Array(UInt64),
    post_balances Array(UInt64),
    
    -- 时间戳
    timestamp DateTime,                 -- 区块时间
    ingested_at DateTime DEFAULT now(),
    
    -- 可选：日志消息（如果需要）
    log_messages Array(String) DEFAULT []
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (slot, tx_index, tx_signature)
SETTINGS index_granularity = 8192;

-- 索引
CREATE INDEX idx_signature ON chain_txs (tx_signature) TYPE bloom_filter GRANULARITY 1;
CREATE INDEX idx_account_keys ON chain_txs (account_keys) TYPE bloom_filter GRANULARITY 1;
CREATE INDEX idx_status ON chain_txs (status) TYPE set GRANULARITY 1;
```

**设计说明：**
- 包含完整的交易信息（账户、指令、资源消耗）
- 支持按签名、账户、状态快速查询
- 日志消息可选（占用空间大，可根据需求决定是否存储）

### 3.3 chain_accounts 表

```sql
CREATE TABLE chain_accounts (
    -- 主键字段
    slot UInt64,
    pubkey String,
    write_version UInt64,
    
    -- 账户数据
    lamports UInt64,
    owner_program String,               -- 所有者程序（owner）
    executable UInt8,
    rent_epoch UInt64,
    data String,                        -- Base64 编码的账户数据
    data_len UInt32,                    -- 数据长度
    
    -- 元数据
    txn_signature Nullable(String),
    is_startup UInt8,
    
    -- 时间戳
    timestamp DateTime,                 -- 区块时间
    ingested_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(write_version)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (pubkey, slot, write_version)
SETTINGS index_granularity = 8192;

-- 索引
CREATE INDEX idx_owner_program ON chain_accounts (owner_program) TYPE bloom_filter GRANULARITY 1;
CREATE INDEX idx_slot ON chain_accounts (slot) TYPE minmax GRANULARITY 1;
```

**设计说明：**
- `ReplacingMergeTree(write_version)`：自动去重，保留最新版本
- 分区策略：按月分区，便于管理历史数据
- 主键排序：`(pubkey, slot, write_version)` 支持高效查询单个账户历史
- `owner_program` 字段便于按程序过滤账户

### 3.4 chain_program_logs 表

```sql
CREATE TABLE chain_program_logs (
    -- 主键
    slot UInt64,
    tx_signature String,
    tx_index UInt32,
    log_index UInt32,
    
    -- 日志内容
    program_id String,
    message String,
    log_type Enum8(
        'UNKNOWN' = 0, 
        'INVOKE' = 1, 
        'LOG' = 2, 
        'DATA' = 3, 
        'SUCCESS' = 4, 
        'FAILED' = 5, 
        'CONSUMED' = 6
    ),
    depth UInt32,
    
    -- 时间戳
    timestamp DateTime,                 -- 区块时间
    ingested_at DateTime DEFAULT now()
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (slot, tx_index, log_index)
SETTINGS index_granularity = 8192;

-- 索引
CREATE INDEX idx_program_id ON chain_program_logs (program_id) TYPE bloom_filter GRANULARITY 1;
CREATE INDEX idx_tx_signature ON chain_program_logs (tx_signature) TYPE bloom_filter GRANULARITY 1;
CREATE INDEX idx_log_type ON chain_program_logs (log_type) TYPE set GRANULARITY 1;
```

**设计说明：**
- 存储所有程序日志（INVOKE, LOG, DATA, SUCCESS, FAILED, CONSUMED）
- `depth` 字段记录调用深度（支持 CPI 分析）
- 支持按程序、交易、日志类型快速查询

### 3.5 chain_events 表

```sql
CREATE TABLE chain_events (
    -- 主键
    slot UInt64,
    tx_signature String,
    tx_index UInt32,
    log_index UInt32,
    
    -- 事件信息
    program String,                     -- 发出事件的程序 ID
    event_type String,                  -- 事件类型名称（从 discriminator 解析）
    event_discriminator String,         -- 8 字节 hex 字符串（16 chars）
    
    -- 事件数据
    payload String,                     -- JSON 格式的事件数据（如果能解析）
    raw_data String,                    -- Base64 编码的原始数据（Borsh）
    
    -- 时间戳
    timestamp DateTime,                 -- 区块时间
    ingested_at DateTime DEFAULT now()
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (slot, tx_index, log_index, program)
SETTINGS index_granularity = 8192;

-- 索引
CREATE INDEX idx_program ON chain_events (program) TYPE bloom_filter GRANULARITY 1;
CREATE INDEX idx_event_type ON chain_events (event_type) TYPE bloom_filter GRANULARITY 1;
CREATE INDEX idx_discriminator ON chain_events (event_discriminator) TYPE bloom_filter GRANULARITY 1;
CREATE INDEX idx_tx_signature ON chain_events (tx_signature) TYPE bloom_filter GRANULARITY 1;
```

**设计说明：**
- 存储 Anchor 和自定义程序事件
- `event_discriminator` 用于事件识别（8 字节 sha256 hash）
- `payload` 存储 JSON 格式（便于查询），`raw_data` 存储原始 Borsh 数据
- 支持按程序、事件类型、discriminator 快速查询

---

## 4. Rust 消费者服务架构

### 4.1 项目结构

```
kafka-clickhouse-sync/
├── Cargo.toml
├── src/
│   ├── main.rs                 # 程序入口
│   ├── config.rs               # 配置加载
│   ├── kafka/
│   │   ├── mod.rs
│   │   ├── consumer.rs         # Kafka 消费者
│   │   └── message_handler.rs  # 消息解析
│   ├── clickhouse/
│   │   ├── mod.rs
│   │   ├── client.rs           # ClickHouse 客户端
│   │   ├── writer.rs           # 批量写入
│   │   └── schema.rs           # 表结构定义
│   ├── models/
│   │   ├── mod.rs
│   │   ├── account.rs          # 账户模型
│   │   ├── block.rs            # 区块模型
│   │   ├── transaction.rs      # 交易模型
│   │   ├── log.rs              # 日志模型
│   │   └── event.rs            # 事件模型
│   ├── metrics/
│   │   ├── mod.rs
│   │   └── prometheus.rs       # Prometheus 指标
│   └── utils/
│       ├── mod.rs
│       ├── base64.rs           # Base64 编解码
│       └── hex.rs              # Hex 编解码
├── proto/
│   └── event.proto             # 复制自 Geyser Plugin
└── config.toml                 # 配置文件示例
```

### 4.2 核心模块设计

#### 4.2.1 Kafka Consumer

```rust
// src/kafka/consumer.rs
pub struct KafkaConsumerPool {
    consumers: HashMap<String, StreamConsumer>,
    config: KafkaConfig,
}

impl KafkaConsumerPool {
    pub async fn new(config: KafkaConfig) -> Result<Self>;
    
    pub async fn subscribe(&self, topics: Vec<&str>) -> Result<()>;
    
    pub async fn consume_messages(&self) -> Result<MessageStream>;
}

// 消息处理流程
pub async fn process_message(
    message: BorrowedMessage<'_>,
    clickhouse_writer: &ClickHouseWriter,
) -> Result<()> {
    let topic = message.topic();
    let payload = message.payload().ok_or("Empty payload")?;
    
    match topic {
        "chain_accounts" => {
            let event = parse_account_event(payload)?;
            clickhouse_writer.insert_account(event).await?;
        }
        "chain_blocks" => {
            let event = parse_block_event(payload)?;
            clickhouse_writer.insert_block(event).await?;
        }
        // ... 其他 topic 处理
    }
    
    Ok(())
}
```

#### 4.2.2 ClickHouse Writer

```rust
// src/clickhouse/writer.rs
pub struct ClickHouseWriter {
    client: clickhouse::Client,
    batch_size: usize,
    flush_interval: Duration,
    
    // 批量缓冲区
    account_buffer: Vec<AccountRow>,
    block_buffer: Vec<BlockRow>,
    transaction_buffer: Vec<TransactionRow>,
    log_buffer: Vec<LogRow>,
    event_buffer: Vec<EventRow>,
}

impl ClickHouseWriter {
    pub async fn new(config: ClickHouseConfig) -> Result<Self>;
    
    // 批量插入接口
    pub async fn insert_account(&mut self, row: AccountRow) -> Result<()> {
        self.account_buffer.push(row);
        
        if self.account_buffer.len() >= self.batch_size {
            self.flush_accounts().await?;
        }
        
        Ok(())
    }
    
    pub async fn flush_accounts(&mut self) -> Result<()> {
        if self.account_buffer.is_empty() {
            return Ok(());
        }
        
        let mut insert = self.client.insert("solana_accounts")?;
        
        for row in self.account_buffer.drain(..) {
            insert.write(&row).await?;
        }
        
        insert.end().await?;
        
        Ok(())
    }
    
    // 定时刷新所有缓冲区
    pub async fn flush_all(&mut self) -> Result<()> {
        self.flush_accounts().await?;
        self.flush_blocks().await?;
        self.flush_transactions().await?;
        self.flush_logs().await?;
        self.flush_events().await?;
        Ok(())
    }
}
```

#### 4.2.3 配置文件

```toml
# config.toml

[kafka]
bootstrap_servers = "localhost:9092"
group_id = "clickhouse-sync"
topics = [
    "solana.chain_blocks",
    "solana.chain_txs",
    "solana.chain_accounts",
    "solana.chain_program_logs",
    "solana.chain_events"
]

# 消费者配置
enable_auto_commit = false
session_timeout_ms = 30000
max_poll_records = 500

[clickhouse]
url = "http://localhost:8123"
database = "solana"
user = "default"
password = ""

# 批量写入配置
batch_size = 1000
flush_interval_secs = 5
max_retries = 3

[processing]
# 并发处理
num_workers = 4

# 消息处理
enable_deduplication = true
dedupe_window_secs = 60

[metrics]
# Prometheus 监控
enabled = true
port = 9090
```

### 4.3 数据流处理

```
┌─────────────┐
│Kafka Message│
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Parse Proto │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Transform  │  ← 数据转换：base64, hex, 类型映射
└──────┬──────┘
       │
       ▼
┌─────────────┐
│Add to Buffer│  ← 批量缓冲
└──────┬──────┘
       │
       ▼
┌─────────────┐
│Batch Insert │  ← 达到阈值或超时时刷新
│ ClickHouse  │
└─────────────┘
```

---

## 5. 性能优化策略

### 5.1 批量写入

- **批次大小**：1000 条消息/批次
- **刷新间隔**：5 秒
- **并发写入**：每个表独立的写入 buffer

### 5.2 分区策略

- **时间分区**：按月分区，便于归档和删除历史数据
- **TTL 策略**：可配置数据保留期（如保留 6 个月）

```sql
ALTER TABLE solana_transactions 
MODIFY TTL toDateTime(slot / 2) + INTERVAL 6 MONTH;
```

### 5.3 压缩优化

- **编码方式**：
  - String 类型：LZ4 压缩
  - UInt64：Delta + LZ4
  - Array：默认压缩

### 5.4 查询优化

- **物化视图**：预聚合常用查询

```sql
-- 示例：每日交易统计
CREATE MATERIALIZED VIEW solana_daily_stats
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (date, program_id)
AS SELECT
    toDate(toDateTime(slot / 2)) as date,
    arrayJoin(account_keys) as program_id,
    count() as tx_count,
    sum(fee) as total_fees,
    sum(compute_units_consumed) as total_compute_units
FROM solana_transactions
GROUP BY date, program_id;
```

---

## 6. 监控和可观测性

### 6.1 Prometheus 指标

```rust
// 关键指标
- kafka_messages_consumed_total{topic, partition}
- kafka_consumer_lag{topic, partition}
- clickhouse_inserts_total{table}
- clickhouse_insert_errors_total{table, error_type}
- clickhouse_batch_size{table}
- clickhouse_insert_duration_seconds{table}
- message_processing_duration_seconds{topic}
- buffer_size{table}
```

### 6.2 日志记录

```rust
use tracing::{info, warn, error};

// 结构化日志
info!(
    topic = %message.topic(),
    partition = %message.partition(),
    offset = %message.offset(),
    "Processing message"
);
```

### 6.3 健康检查

```rust
// HTTP 健康检查端点
GET /health
{
    "status": "healthy",
    "kafka": {
        "connected": true,
        "lag": 100
    },
    "clickhouse": {
        "connected": true,
        "last_insert": "2025-10-24T10:30:00Z"
    }
}
```

---

## 7. 部署方案

### 7.1 Docker Compose 部署

```yaml
# docker-compose.yml
version: '3.8'

services:
  clickhouse:
    image: clickhouse/clickhouse-server:latest
    ports:
      - "8123:8123"
      - "9000:9000"
    volumes:
      - ./clickhouse-data:/var/lib/clickhouse
      - ./init-db.sql:/docker-entrypoint-initdb.d/init.sql
    environment:
      CLICKHOUSE_DB: solana
      CLICKHOUSE_USER: default
      CLICKHOUSE_PASSWORD: ""

  kafka-sync:
    build: .
    depends_on:
      - clickhouse
    environment:
      RUST_LOG: info
      CONFIG_PATH: /app/config.toml
    volumes:
      - ./config.toml:/app/config.toml
    restart: unless-stopped
```

### 7.2 Systemd 服务

```ini
# /etc/systemd/system/kafka-clickhouse-sync.service
[Unit]
Description=Kafka to ClickHouse Sync Service
After=network.target

[Service]
Type=simple
User=solana
ExecStart=/usr/local/bin/kafka-clickhouse-sync --config /etc/kafka-sync/config.toml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

---

## 8. 开发计划

### Phase 1: 基础框架（2 天）
- ✅ 项目搭建和依赖配置
- ✅ Kafka 消费者实现
- ✅ ClickHouse 客户端封装
- ✅ 配置文件加载

### Phase 2: 数据同步（2 天）
- ✅ Protobuf 消息解析
- ✅ 数据模型转换
- ✅ 批量写入实现
- ✅ 错误处理和重试

### Phase 3: 优化和监控（1 天）
- ✅ Prometheus 指标集成
- ✅ 性能优化
- ✅ 日志和追踪

### Phase 4: 测试和文档（1 天）
- ✅ 单元测试
- ✅ 集成测试
- ✅ 性能测试
- ✅ 部署文档

**总计：6 个工作日**

---

## 9. 风险和挑战

### 9.1 性能风险

**风险**：高吞吐量下的写入延迟
**缓解措施**：
- 批量写入
- 异步处理
- 背压控制（当 buffer 满时暂停消费）

### 9.2 数据一致性

**风险**：Kafka 重复消费导致重复数据
**缓解措施**：
- 使用 ReplacingMergeTree 引擎自动去重
- 记录 Kafka offset，实现 exactly-once 语义

### 9.3 Schema 演化

**风险**：Protobuf schema 变更
**缓解措施**：
- 向后兼容的 schema 设计
- 版本化字段处理

---

## 10. 后续扩展

### 10.1 实时查询 API

基于 ClickHouse 数据构建 REST API：
- 账户历史查询
- 交易搜索
- 程序分析统计

### 10.2 数据分析 Dashboard

- Grafana 集成
- 链上数据可视化
- 实时监控面板

### 10.3 多链支持

扩展到支持其他区块链：
- Ethereum
- Polygon
- BSC

---

## 11. 总结

本方案提供了一个**高性能、可扩展、生产就绪**的 Kafka 到 ClickHouse 数据同步解决方案。

**核心优势：**
✅ **高性能**：Rust + 批量写入 + 异步处理
✅ **可靠性**：错误重试 + 健康检查 + 监控告警
✅ **可扩展**：模块化设计，易于添加新的数据源和目标
✅ **运维友好**：单一二进制 + Docker 支持 + 完善的监控

**下一步行动：**
1. 审核设计方案
2. 确认 ClickHouse 表结构
3. 开始实现 Rust 消费者服务
4. 集成测试和性能调优

---

## 附录 A: 依赖清单

```toml
[dependencies]
# Kafka
rdkafka = { version = "0.36", features = ["cmake-build"] }

# ClickHouse
clickhouse = "0.11"

# Protobuf
prost = "0.12"

# 异步运行时
tokio = { version = "1.35", features = ["full"] }

# 配置
serde = { version = "1.0", features = ["derive"] }
toml = "0.8"

# 日志和追踪
tracing = "0.1"
tracing-subscriber = "0.3"

# 监控
prometheus = "0.13"

# 错误处理
anyhow = "1.0"
thiserror = "1.0"

# 工具
base64 = "0.21"
hex = "0.4"
```

## 附录 B: 参考查询示例

```sql
-- 1. 查询最近的区块
SELECT 
    slot,
    blockhash,
    leader,
    num_txs,
    status,
    timestamp,
    total_compute_units,
    total_fees
FROM chain_blocks
WHERE timestamp >= now() - INTERVAL 1 HOUR
ORDER BY slot DESC
LIMIT 100;

-- 2. 查询账户历史
SELECT 
    slot,
    lamports,
    owner_program,
    data_len,
    timestamp
FROM chain_accounts
WHERE pubkey = 'YourAccountPubkeyHere'
ORDER BY slot DESC
LIMIT 100;

-- 3. 统计每日交易量
SELECT 
    toDate(timestamp) as date,
    count() as tx_count,
    sum(fee) as total_fees,
    sum(compute_units_consumed) as total_compute_units,
    countIf(status = 'Failed') as failed_count
FROM chain_txs
WHERE date >= today() - 7
GROUP BY date
ORDER BY date;

-- 4. 查询特定交易的详细信息
SELECT 
    slot,
    tx_signature,
    status,
    fee,
    compute_units_consumed,
    account_keys,
    num_instructions,
    error_info,
    timestamp
FROM chain_txs
WHERE tx_signature = 'YourTransactionSignatureHere';

-- 5. 查询特定程序的日志
SELECT 
    slot,
    tx_signature,
    log_type,
    message,
    depth,
    timestamp
FROM chain_program_logs
WHERE program_id = 'YourProgramID'
  AND timestamp >= now() - INTERVAL 1 DAY
ORDER BY slot DESC, log_index ASC
LIMIT 1000;

-- 6. 查询特定程序的事件
SELECT 
    slot,
    tx_signature,
    event_type,
    payload,
    timestamp
FROM chain_events
WHERE program = 'YourProgramID'
  AND event_type != ''
ORDER BY slot DESC
LIMIT 100;

-- 7. 统计特定程序的调用频率
SELECT 
    program_id,
    count() as call_count,
    countIf(log_type = 'INVOKE') as invoke_count,
    countIf(log_type = 'FAILED') as failed_count
FROM chain_program_logs
WHERE timestamp >= today() - INTERVAL 1 DAY
GROUP BY program_id
ORDER BY call_count DESC
LIMIT 20;

-- 8. 查询账户余额变化
SELECT 
    slot,
    pubkey,
    lamports,
    lamports - lagInFrame(lamports) OVER (PARTITION BY pubkey ORDER BY slot) as balance_change,
    timestamp
FROM chain_accounts
WHERE pubkey = 'YourAccountPubkeyHere'
  AND timestamp >= now() - INTERVAL 7 DAY
ORDER BY slot DESC;

-- 9. 查询失败的交易
SELECT 
    slot,
    tx_signature,
    error_info,
    fee,
    account_keys,
    timestamp
FROM chain_txs
WHERE status = 'Failed'
  AND timestamp >= now() - INTERVAL 1 HOUR
ORDER BY slot DESC
LIMIT 100;

-- 10. 统计事件类型分布
SELECT 
    program,
    event_type,
    count() as event_count
FROM chain_events
WHERE timestamp >= today()
GROUP BY program, event_type
ORDER BY event_count DESC
LIMIT 50;
```
