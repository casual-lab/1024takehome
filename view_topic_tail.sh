#!/bin/bash
# 查看 Kafka topic 中最近的 N 条消息

show_usage() {
    echo "用法: $0 <topic_name> [num_messages]"
    echo ""
    echo "功能: 查看 topic 中最近的 N 条消息"
    echo ""
    echo "参数:"
    echo "  topic_name     - Kafka topic 名称（必需）"
    echo "  num_messages   - 显示最后 N 条消息（默认: 10）"
    echo ""
    echo "示例:"
    echo "  $0 solana.chain_accounts           # 最后 10 条"
    echo "  $0 solana.chain_txs 20             # 最后 20 条"
    echo "  $0 solana.slots 5                  # 最后 5 条"
    echo ""
    echo "💡 提示: 此脚本会自动计算 offset"
}

if [ -z "$1" ]; then
    show_usage
    exit 1
fi

TOPIC=$1
NUM_MESSAGES=${2:-10}

export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

# 获取 topic 的最新 offset 使用 Python
echo "📊 正在获取 topic 信息..."
LATEST_OFFSET=$(python3 << EOF
from kafka import KafkaConsumer
from kafka.structs import TopicPartition

try:
    consumer = KafkaConsumer(
        bootstrap_servers=['localhost:19092'],
        security_protocol='SASL_PLAINTEXT',
        sasl_mechanism='SCRAM-SHA-256',
        sasl_plain_username='superuser',
        sasl_plain_password='secretpassword'
    )
    
    partition = TopicPartition('$TOPIC', 0)
    consumer.assign([partition])
    consumer.seek_to_end(partition)
    offset = consumer.position(partition)
    consumer.close()
    print(offset)
except Exception as e:
    print(f"ERROR: {e}", file=__import__('sys').stderr)
    exit(1)
EOF
)

if [ -z "$LATEST_OFFSET" ] || [ "$LATEST_OFFSET" == "ERROR:"* ]; then
    echo "❌ 无法获取 topic 信息，请确保:"
    echo "   1. Topic 存在: $TOPIC"
    echo "   2. Kafka broker 可访问 (localhost:19092)"
    echo "   3. 认证信息正确"
    exit 1
fi

echo "   最新 offset: $LATEST_OFFSET"

# 计算起始 offset（确保不小于 0）
START_OFFSET=$((LATEST_OFFSET - NUM_MESSAGES))
if [ $START_OFFSET -lt 0 ]; then
    START_OFFSET=0
fi

ACTUAL_MESSAGES=$((LATEST_OFFSET - START_OFFSET))

echo "   显示从 offset $START_OFFSET 到 $LATEST_OFFSET 的消息 ($ACTUAL_MESSAGES 条)"
echo ""

# 调用 view_kafka_data.py
python3 /home/ubuntu/ytest/view_kafka_data.py --raw-topic "$TOPIC" --max "$NUM_MESSAGES" --offset "$START_OFFSET"
