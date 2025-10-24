# Anchor 自定义事件捕获分析

## ✅ 当前实现：能够捕获 Anchor 事件

### 工作原理

当前的 `LogParser` **可以捕获 Anchor 自定义事件**，处理流程如下：

```rust
// 1. 识别 "Program data:" 日志
"Program data: SGVsbG8gV29ybGQ="  // Base64 编码

// 2. Base64 解码
[0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x57, 0x6f, 0x72, 0x6c, 0x64]

// 3. 提取前 8 字节作为 discriminator
discriminator = [0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x57, 0x6f]

// 4. 可选过滤（如果配置了 event_discriminators）
if event_discriminators.contains(&discriminator) {
    // 捕获事件
}

// 5. 保存到 ChainEvent
ChainEvent {
    program_id: "Your_Program_ID",
    discriminator: "48656c6c6f20576f",  // Hex string
    data: [0x48, 0x65, ...],            // 完整数据（包括 discriminator）
    instruction_index: 0,
}
```

### Anchor 事件格式

Anchor 框架发出事件时的格式：

```
Program data: <base64_encoded_data>
```

其中 `base64_encoded_data` 的结构：
```
┌─────────────────────┬──────────────────────────┐
│  8-byte discriminator │  Borsh encoded event data │
└─────────────────────┴──────────────────────────┘
```

**Discriminator 计算方法**（Anchor 标准）：
```rust
discriminator = sha256("event:{EventName}")[0..8]
```

例如：
- `event:TransferEvent` → `sha256()` → 取前 8 字节
- `event:InitializeEvent` → `sha256()` → 取前 8 字节

## 📊 当前支持的功能

| 功能 | 状态 | 说明 |
|------|------|------|
| 识别 "Program data:" | ✅ | 完全支持 |
| Base64 解码 | ✅ | 完全支持 |
| 提取 8 字节 discriminator | ✅ | 完全支持 |
| Discriminator 过滤 | ✅ | 可配置白名单 |
| 保存原始数据 | ✅ | 完整保存（raw_data） |
| 记录 program_id | ✅ | 完全支持 |
| 记录 slot/tx_signature | ✅ | 完全支持 |
| Event 类型名称解析 | ❌ | event_type 字段为空 |
| Borsh 反序列化 | ❌ | json_payload 字段为 None |

## 🔧 配置示例

### 1. 捕获所有 Anchor 事件（无过滤）

```json
{
  "filters": [{
    "event_discriminators": [],           // 空数组 = 捕获所有
    "extract_anchor_events": true,
    "chain_event_topic": "chain_events"
  }]
}
```

### 2. 只捕获特定事件（白名单过滤）

```json
{
  "filters": [{
    "event_discriminators": [
      "11c39756bd62d2e0",                 // TransferEvent
      "a1b2c3d4e5f67890"                  // SwapEvent
    ],
    "extract_anchor_events": true,
    "chain_event_topic": "chain_events"
  }]
}
```

### 3. 如何获取 discriminator？

**方法 1: 从 Anchor IDL 计算**
```bash
# 使用 Python 计算
python3 << EOF
import hashlib
event_name = "TransferEvent"
namespace = f"event:{event_name}"
hash_bytes = hashlib.sha256(namespace.encode()).digest()
discriminator = hash_bytes[:8].hex()
print(f"{event_name} discriminator: {discriminator}")
EOF
```

**方法 2: 从交易日志提取**
```bash
# 运行测试程序，查看 Kafka 中的事件
./view_kafka.sh
# 选择 "View chain events"
# 复制显示的 event_discriminator 值
```

**方法 3: 从 TypeScript/Rust 代码计算**
```typescript
// TypeScript (Anchor 客户端)
import { sha256 } from 'js-sha256';

function getDiscriminator(eventName: string): string {
  const hash = sha256.array(`event:${eventName}`);
  return Buffer.from(hash.slice(0, 8)).toString('hex');
}

console.log(getDiscriminator('TransferEvent'));
```

## 🎯 使用场景

### 场景 1: 监控特定 DeFi 协议的事件

```json
{
  "filters": [{
    "program_filters": ["YourDeFiProgramID"],
    "event_discriminators": [
      "1234567890abcdef",  // SwapEvent
      "fedcba0987654321"   // LiquidityAddedEvent
    ],
    "extract_anchor_events": true
  }]
}
```

### 场景 2: 捕获所有程序的所有事件

```json
{
  "filters": [{
    "event_discriminators": [],  // 空 = 全部捕获
    "extract_anchor_events": true
  }]
}
```

### 场景 3: 同时捕获日志和事件

```json
{
  "filters": [{
    "extract_program_logs": true,      // 捕获所有日志
    "extract_anchor_events": true,     // 捕获所有事件
    "program_log_topic": "logs",
    "chain_event_topic": "events"
  }]
}
```

## 📝 事件数据结构（Kafka 中）

发布到 `chain_events` topic 的消息：

```protobuf
message ChainEvent {
  uint64 slot = 1;                    // 区块槽位
  bytes tx_signature = 2;             // 交易签名
  uint32 tx_index = 3;                // 区块内交易索引
  string program_id = 4;              // 发出事件的程序
  bytes event_discriminator = 5;      // 8 字节 discriminator
  string event_type = 6;              // 事件类型名称（当前为空）
  bytes raw_data = 7;                 // 完整的原始数据（Borsh 编码）
  optional string json_payload = 8;   // JSON 表示（当前为 None）
  uint32 log_index = 9;               // 日志索引
}
```

## 🚀 后续增强建议

### Stage 9: Event Schema Registry（可选）

如果需要解码 Borsh 数据，可以添加：

1. **Event Registry**
   ```rust
   struct EventRegistry {
       schemas: HashMap<[u8; 8], EventSchema>,
   }
   
   struct EventSchema {
       name: String,
       fields: Vec<FieldDefinition>,
   }
   ```

2. **从 IDL 加载 Schema**
   ```json
   {
     "event_schemas": {
       "11c39756bd62d2e0": {
         "name": "TransferEvent",
         "fields": [
           {"name": "from", "type": "publicKey"},
           {"name": "to", "type": "publicKey"},
           {"name": "amount", "type": "u64"}
         ]
       }
     }
   }
   ```

3. **Borsh 反序列化**
   - 使用 `borsh` crate 解码
   - 填充 `json_payload` 字段

但对于大多数用例，**当前实现已经足够**：
- ✅ 捕获所有原始数据
- ✅ 下游服务可以自行解码
- ✅ 保持插件轻量级

## 总结

**✅ 是的，Anchor 自定义事件能够被捕获！**

当前实现完全支持：
1. 自动识别 Anchor 事件（"Program data:" 格式）
2. 提取 8 字节 discriminator
3. 保存完整的原始数据（包括 Borsh 编码的 payload）
4. 可选的白名单过滤（通过 event_discriminators 配置）
5. 记录完整的上下文信息（slot, signature, program_id, etc.）

只要你的 Anchor 程序使用标准的 `emit!` 宏发出事件，插件就能捕获它们！
