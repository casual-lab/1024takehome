#!/bin/bash
# 快速查看 Kafka 中的 Solana 数据

export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

echo "=========================================="
echo "🔍 Kafka 数据查看工具"
echo "=========================================="
echo ""
echo "请选择要查看的数据类型:"
echo ""
echo "  1. 📦 accounts        - 账户快照"
echo "  2. 💳 txs             - 交易明细"
echo "  3. 🔷 blocks          - 区块基础信息"
echo "  4. 📊 metadata        - 区块元数据 ⭐ NEW"
echo "  5. 📝 logs            - 程序日志 (Stage 4)"
echo "  6. 🎯 events          - 链事件 (Stage 4)"
echo "  7. 🔍 自定义 topic"
echo "  8. 📋 全部查看"
echo ""

read -p "请输入选项 (1-8): " choice

MAX_MESSAGES=10
read -p "每个 topic 显示多少条消息? [默认 10]: " input_max
if [ ! -z "$input_max" ]; then
    MAX_MESSAGES=$input_max
fi

echo ""
echo "=========================================="
echo ""

case $choice in
    1)
        python3 /home/ubuntu/ytest/view_kafka_data.py --topic accounts --max $MAX_MESSAGES
        ;;
    2)
        python3 /home/ubuntu/ytest/view_kafka_data.py --topic txs --max $MAX_MESSAGES
        ;;
    3)
        python3 /home/ubuntu/ytest/view_kafka_data.py --topic blocks --max $MAX_MESSAGES
        ;;
    4)
        python3 /home/ubuntu/ytest/view_kafka_data.py --topic metadata --max $MAX_MESSAGES
        ;;
    5)
        python3 /home/ubuntu/ytest/view_kafka_data.py --topic logs --max $MAX_MESSAGES
        ;;
    6)
        python3 /home/ubuntu/ytest/view_kafka_data.py --topic events --max $MAX_MESSAGES
        ;;
    7)
        read -p "输入完整的 topic 名称 (例如: chain_blocks_metadata): " custom_topic
        python3 /home/ubuntu/ytest/view_kafka_data.py --raw-topic "$custom_topic" --max $MAX_MESSAGES
        ;;
    8)
        python3 /home/ubuntu/ytest/view_kafka_data.py --topic all --max $MAX_MESSAGES
        ;;
    *)
        echo "❌ 无效选项"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "💡 提示："
echo ""
echo "对应的表结构字段："
echo ""
echo "chain_blocks:"
echo "  ✓ slot            - 插槽号"
echo "  ✓ parent_slot     - 父插槽"
echo "  ○ block_hash      - 区块哈希 (插件未提供)"
echo "  ○ leader          - 出块者 (插件未提供)"
echo "  ○ num_txs         - 交易数量 (需聚合)"
echo "  ✓ timestamp       - 时间戳"
echo ""
echo "chain_txs:"
echo "  ✓ tx_signature    - 交易签名"
echo "  ✓ slot            - 插槽号"
echo "  ✓ status          - 状态 (success/failed)"
echo "  ✓ fee             - 手续费"
echo "  ✓ compute_units   - 计算单元消耗"
echo "  ✓ timestamp       - 时间戳"
echo ""
echo "chain_accounts:"
echo "  ✓ pubkey          - 账户地址"
echo "  ✓ owner_program   - 所有者程序"
echo "  ✓ lamports        - 余额"
echo "  ✓ slot            - 插槽号"
echo "  ✓ write_version   - 写入版本"
echo ""
echo "=========================================="
