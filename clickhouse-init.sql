-- ClickHouse 数据库初始化脚本
-- 用于 Solana Geyser Plugin Kafka 数据同步

-- 1. 创建数据库
CREATE DATABASE IF NOT EXISTS solana;

USE solana;

-- ========================================
-- 2. 创建表结构
-- ========================================

-- 2.1 区块表 (chain_blocks)
DROP TABLE IF EXISTS chain_blocks;
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
    
    -- 统计信息（可选）
    executed_transaction_count UInt32 DEFAULT 0,
    total_compute_units UInt32 DEFAULT 0,
    total_fees UInt64 DEFAULT 0
) ENGINE = ReplacingMergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (slot, blockhash)
SETTINGS index_granularity = 8192;

-- 索引
CREATE INDEX IF NOT EXISTS idx_leader ON chain_blocks (leader) TYPE bloom_filter GRANULARITY 1;
CREATE INDEX IF NOT EXISTS idx_timestamp ON chain_blocks (timestamp) TYPE minmax GRANULARITY 1;

-- 2.2 交易表 (chain_txs)
DROP TABLE IF EXISTS chain_txs;
CREATE TABLE chain_txs (
    -- 主键
    slot UInt64,
    tx_signature String,
    tx_index UInt64,
    
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
    timestamp DateTime,
    ingested_at DateTime DEFAULT now(),
    
    -- 可选：日志消息
    log_messages Array(String) DEFAULT []
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (slot, tx_index, tx_signature)
SETTINGS index_granularity = 8192;

-- 索引
CREATE INDEX IF NOT EXISTS idx_signature ON chain_txs (tx_signature) TYPE bloom_filter GRANULARITY 1;
CREATE INDEX IF NOT EXISTS idx_account_keys ON chain_txs (account_keys) TYPE bloom_filter GRANULARITY 1;
-- Enum 类型不需要额外索引，已经很高效了

-- 2.3 账户表 (chain_accounts)
DROP TABLE IF EXISTS chain_accounts;
CREATE TABLE chain_accounts (
    -- 主键字段
    slot UInt64,
    pubkey String,
    write_version UInt64,
    
    -- 账户数据
    lamports UInt64,
    owner_program String,
    executable UInt8,
    rent_epoch UInt64,
    data String,                        -- Base64 编码
    data_len UInt32,
    
    -- 元数据
    txn_signature Nullable(String),
    is_startup UInt8,
    
    -- 时间戳
    timestamp DateTime,
    ingested_at DateTime DEFAULT now()
) ENGINE = ReplacingMergeTree(write_version)
PARTITION BY toYYYYMM(timestamp)
ORDER BY (pubkey, slot, write_version)
SETTINGS index_granularity = 8192;

-- 索引
CREATE INDEX IF NOT EXISTS idx_owner_program ON chain_accounts (owner_program) TYPE bloom_filter GRANULARITY 1;
CREATE INDEX IF NOT EXISTS idx_slot ON chain_accounts (slot) TYPE minmax GRANULARITY 1;

-- 2.4 程序日志表 (chain_program_logs)
DROP TABLE IF EXISTS chain_program_logs;
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
    timestamp DateTime,
    ingested_at DateTime DEFAULT now()
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (slot, tx_index, log_index)
SETTINGS index_granularity = 8192;

-- 索引
CREATE INDEX IF NOT EXISTS idx_program_id ON chain_program_logs (program_id) TYPE bloom_filter GRANULARITY 1;
CREATE INDEX IF NOT EXISTS idx_tx_signature ON chain_program_logs (tx_signature) TYPE bloom_filter GRANULARITY 1;
-- Enum 类型不需要额外索引，已经很高效了

-- 2.5 链事件表 (chain_events)
DROP TABLE IF EXISTS chain_events;
CREATE TABLE chain_events (
    -- 主键
    slot UInt64,
    tx_signature String,
    tx_index UInt32,
    log_index UInt32,
    
    -- 事件信息
    program String,
    event_type String,
    event_discriminator String,
    
    -- 事件数据
    payload String,                     -- JSON 格式
    raw_data String,                    -- Base64 编码的原始数据
    
    -- 时间戳
    timestamp DateTime,
    ingested_at DateTime DEFAULT now()
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (slot, tx_index, log_index, program)
SETTINGS index_granularity = 8192;

-- 索引
CREATE INDEX IF NOT EXISTS idx_program ON chain_events (program) TYPE bloom_filter GRANULARITY 1;
CREATE INDEX IF NOT EXISTS idx_event_type ON chain_events (event_type) TYPE bloom_filter GRANULARITY 1;
CREATE INDEX IF NOT EXISTS idx_discriminator ON chain_events (event_discriminator) TYPE bloom_filter GRANULARITY 1;
CREATE INDEX IF NOT EXISTS idx_tx_signature ON chain_events (tx_signature) TYPE bloom_filter GRANULARITY 1;

-- ========================================
-- 3. 创建物化视图（可选，用于加速常见查询）
-- ========================================

-- 3.1 每日交易统计
DROP TABLE IF EXISTS chain_daily_tx_stats;
CREATE MATERIALIZED VIEW IF NOT EXISTS chain_daily_tx_stats
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (date, status)
POPULATE
AS SELECT
    toDate(timestamp) as date,
    status,
    count() as tx_count,
    sum(fee) as total_fees,
    sum(compute_units_consumed) as total_compute_units
FROM chain_txs
GROUP BY date, status;

-- 3.2 每小时区块统计
DROP TABLE IF EXISTS chain_hourly_block_stats;
CREATE MATERIALIZED VIEW IF NOT EXISTS chain_hourly_block_stats
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(hour)
ORDER BY (hour, leader)
POPULATE
AS SELECT
    toStartOfHour(timestamp) as hour,
    leader,
    count() as block_count,
    sum(num_txs) as total_txs,
    sum(total_fees) as total_fees
FROM chain_blocks
WHERE status = 'Rooted'
GROUP BY hour, leader;

-- 3.3 程序调用频率统计
DROP TABLE IF EXISTS chain_program_call_stats;
CREATE MATERIALIZED VIEW IF NOT EXISTS chain_program_call_stats
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (date, program_id)
POPULATE
AS SELECT
    toDate(timestamp) as date,
    program_id,
    count() as call_count,
    countIf(log_type = 'INVOKE') as invoke_count,
    countIf(log_type = 'FAILED') as failed_count,
    countIf(log_type = 'SUCCESS') as success_count
FROM chain_program_logs
GROUP BY date, program_id;

-- ========================================
-- 4. TTL 策略（可选，自动清理历史数据）
-- ========================================

-- 保留 6 个月的数据
-- ALTER TABLE chain_blocks MODIFY TTL timestamp + INTERVAL 6 MONTH;
-- ALTER TABLE chain_txs MODIFY TTL timestamp + INTERVAL 6 MONTH;
-- ALTER TABLE chain_accounts MODIFY TTL timestamp + INTERVAL 6 MONTH;
-- ALTER TABLE chain_program_logs MODIFY TTL timestamp + INTERVAL 3 MONTH;
-- ALTER TABLE chain_events MODIFY TTL timestamp + INTERVAL 3 MONTH;

-- ========================================
-- 5. 验证表创建
-- ========================================

SHOW TABLES;

SELECT 
    table,
    engine,
    partition_key,
    sorting_key,
    total_rows
FROM system.tables
WHERE database = 'solana'
ORDER BY table;
