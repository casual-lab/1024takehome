#!/bin/bash
# 快速测试 Phase 3 - 质押流程

set -e

echo "🚀 开始 Phase 3 质押测试..."
echo ""

# 1. 检查验证器
if ! pgrep -x "solana-test-validator" > /dev/null; then
    echo "⚠️  测试验证器未运行，正在启动..."
    solana-test-validator > /dev/null 2>&1 &
    sleep 5
    echo "✅ 验证器已启动"
fi

# 2. 构建和部署
echo "📦 构建程序..."
cd /workspace/lp-staking
anchor build

echo "🚀 部署程序..."
anchor deploy

# 3. 运行 Phase 2 测试初始化池子
echo "🧪 运行 Phase 2 测试 (初始化池子)..."
anchor test --skip-local-validator 2>&1 | grep -E "(✔|passing|failing)"

# 4. 获取关键地址
echo ""
echo "📍 关键地址:"
echo "  Program ID: AoQuXAg7gK5KHkeuhbLpJ5AtnziNb5M9FqjLNUaVudTx"
echo "  Pool State: 9o1uwsufiCcELp7PjDWqJ1w6fKAGHtp9AJvuysYZbnRy"
echo "  Reward Vault: 253KaQanuVPGwt44ixarUcFWjeeBKsAeo2dtRHW9CkBt"

# 5. 充值 Reward Vault
echo ""
echo "💰 充值 Reward Vault (10 SOL)..."
solana transfer 253KaQanuVPGwt44ixarUcFWjeeBKsAeo2dtRHW9CkBt 10 --allow-unfunded-recipient

# 6. 检查余额
VAULT_BALANCE=$(solana balance 253KaQanuVPGwt44ixarUcFWjeeBKsAeo2dtRHW9CkBt)
echo "✅ Reward Vault 余额: $VAULT_BALANCE"

echo ""
echo "=========================================="
echo "✅ 准备完成! 现在可以运行交互式测试:"
echo "   npx ts-node manual-test.ts"
echo "=========================================="
