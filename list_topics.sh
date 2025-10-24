#!/bin/bash
# 列出 Kafka 中的所有 topics

echo "=========================================="
echo "📋 Kafka Topics 列表"
echo "=========================================="
echo ""

# 使用 kafka-topics 命令列出所有 topics
docker exec redpanda-redpanda-1 rpk topic list 2>/dev/null || \
kafka-topics.sh --bootstrap-server localhost:19092 \
    --command-config <(cat <<EOF
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="superuser" password="secretpassword";
EOF
) --list 2>/dev/null || \
echo "⚠️ 无法连接到 Kafka. 请确保 Kafka 正在运行."

echo ""
echo "=========================================="
echo "💡 使用方法:"
echo ""
echo "  查看特定 topic:"
echo "    ./view_topic.sh <topic_name>"
echo ""
echo "  交互式查看:"
echo "    ./view_kafka.sh"
echo ""
echo "=========================================="
