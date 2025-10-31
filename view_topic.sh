#!/bin/bash
# 快速查看指定 Kafka topic 的数据

show_usage() {
    echo "用法: $0 <topic_name> [max_messages] [offset] [--delete]"
    echo ""
    echo "参数:"
    echo "  topic_name     - Kafka topic 名称（必需）"
    echo "  max_messages   - 最多显示的消息数（默认: 10）"
    echo "  offset         - 起始位置 earliest/latest/数字（默认: earliest）"
    echo "  --delete       - 读取后删除消息（提交 offset）"
    echo ""
    echo "示例:"
    echo "  $0 solana.chain_accounts"
    echo "  $0 solana.chain_accounts 20"
    echo "  $0 solana.chain_txs 10 latest"
    echo "  $0 solana.chain_txs 10 1000"
    echo "  $0 solana.slots 50 earliest --delete"
    echo ""
    echo "🔹 Geyser 插件实际发送的 Topics (基于 config.json):"
    echo "  1. solana.chain_accounts      账户更新 (UpdateAccountEvent)"
    echo "  2. solana.slots               插槽状态 (SlotStatusEvent)"
    echo "  3. solana.chain_txs           交易 (TransactionEvent)"
    echo "  4. solana.chain_blocks        区块元数据 (BlockMetadataEvent)"
    echo "  5. solana.chain_program_logs  程序日志 (ProgramLogEvent)"
    echo "  6. solana.chain_events        链事件/Anchor事件 (ChainEvent)"
    echo ""
    echo "💡 Offset 说明:"
    echo "  earliest  - 从最早的消息开始（默认）"
    echo "  latest    - 从最新的消息开始"
    echo "  数字      - 从指定的 offset 开始（如：1000）"
    echo ""
    echo "💡 提示: 如果使用不同的配置文件，topic 名称可能会不同"
}

if [ -z "$1" ]; then
    show_usage
    exit 1
fi

TOPIC=$1
MAX_MESSAGES=${2:-10}
OFFSET=${3:-earliest}
DELETE_FLAG=""

# 检查是否有 --delete 参数
for arg in "$@"; do
    if [ "$arg" == "--delete" ]; then
        DELETE_FLAG="--delete"
        break
    fi
done

export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

python3 /home/ubuntu/ytest/view_kafka_data.py --raw-topic "$TOPIC" --max "$MAX_MESSAGES" --offset "$OFFSET" $DELETE_FLAG
