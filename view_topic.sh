#!/bin/bash
# 快速查看指定 Kafka topic 的数据

if [ -z "$1" ]; then
    echo "用法: $0 <topic_name> [max_messages]"
    echo ""
    echo "示例:"
    echo "  $0 chain_accounts"
    echo "  $0 chain_blocks_metadata 20"
    echo "  $0 solana.blocks"
    echo ""
    echo "可用的 topic:"
    echo "  - solana.accounts           (账户更新)"
    echo "  - solana.transactions       (交易)"
    echo "  - solana.slots              (区块状态)"
    echo "  - solana.blocks             (区块元数据) ⭐ NEW"
    echo "  - solana.program_logs       (程序日志) - Stage 4"
    echo "  - solana.events             (链事件) - Stage 4"
    echo ""
    echo "  或使用自定义 topic 名称 (例如: chain_blocks_metadata)"
    exit 1
fi

TOPIC=$1
MAX_MESSAGES=${2:-10}

export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

python3 /home/ubuntu/ytest/view_kafka_data.py --raw-topic "$TOPIC" --max $MAX_MESSAGES
