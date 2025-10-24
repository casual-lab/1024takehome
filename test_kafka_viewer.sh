#!/bin/bash
# 快速测试 Kafka 查看工具

echo "=========================================="
echo "🧪 测试 Kafka 查看工具"
echo "=========================================="
echo ""

# 检查 Kafka 是否运行
echo "1. 检查 Kafka 连接..."
if nc -z localhost 19092 2>/dev/null; then
    echo "   ✅ Kafka is running"
else
    echo "   ❌ Kafka is not running"
    echo "   启动命令: cd /home/ubuntu/ytest/redpanda-quickstart/docker-compose && docker-compose up -d"
    exit 1
fi

echo ""
echo "2. 列出所有 Kafka topics..."
./list_topics.sh | head -20

echo ""
echo "3. 测试查看工具..."
echo ""

# 测试各个 topic
for topic in "solana.accounts" "solana.transactions" "solana.slots" "solana.blocks"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "测试 topic: $topic"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ./view_topic.sh "$topic" 2 2>&1 | head -40
    echo ""
done

echo "=========================================="
echo "✅ 测试完成!"
echo "=========================================="
echo ""
echo "💡 使用方法:"
echo "  - 交互式: ./view_kafka.sh"
echo "  - 直接查看: ./view_topic.sh <topic_name>"
echo "  - 列出topics: ./list_topics.sh"
echo ""
echo "📚 详细文档: cat KAFKA_VIEWER_README.md"
