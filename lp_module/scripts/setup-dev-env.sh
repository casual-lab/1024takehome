#!/bin/bash

echo "=========================================="
echo "  Solana & Anchor 开发环境自动安装脚本"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. 检查并安装 Solana CLI
echo -e "${YELLOW}[1/5] 检查 Solana CLI...${NC}"
if command -v solana &> /dev/null; then
    echo -e "${GREEN}✓ Solana CLI 已安装: $(solana --version)${NC}"
else
    echo "正在安装 Solana CLI（包含 Rust、Anchor 等完整工具链）..."
    curl --proto '=https' --tlsv1.2 -sSfL https://solana-install.solana.workers.dev | bash
    
    # 刷新环境变量
    export PATH="$HOME/.cargo/bin:$PATH"
    export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
    
    # 永久添加到 bashrc
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
    echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
    
    echo -e "${GREEN}✓ Solana 工具链安装完成${NC}"
fi

# 刷新环境变量
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# 2. 配置 Solana
echo -e "\n${YELLOW}[2/5] 配置 Solana CLI...${NC}"
solana config set --url localhost > /dev/null 2>&1

if [ ! -f ~/.config/solana/id.json ]; then
    echo "创建新的 Solana 密钥对..."
    solana-keygen new --no-bip39-passphrase --force > /dev/null 2>&1
    echo -e "${GREEN}✓ 密钥对创建完成${NC}"
else
    echo -e "${GREEN}✓ 密钥对已存在${NC}"
fi

# 3. 验证 Anchor CLI（已通过 solana-install 安装）
echo -e "\n${YELLOW}[3/5] 检查 Anchor CLI...${NC}"
if command -v anchor &> /dev/null; then
    echo -e "${GREEN}✓ Anchor CLI 已安装: $(anchor --version)${NC}"
else
    echo -e "${RED}✗ Anchor CLI 未安装，请检查安装日志${NC}"
fi

# 4. 启动测试验证器（可选）
echo -e "\n${YELLOW}[4/5] 检查 Solana 测试验证器...${NC}"
if pgrep -f "solana-test-validator" > /dev/null; then
    echo -e "${GREEN}✓ 测试验证器已在运行${NC}"
else
    echo "启动测试验证器（后台运行）..."
    nohup solana-test-validator > /tmp/validator.log 2>&1 &
    sleep 5
    
    if pgrep -f "solana-test-validator" > /dev/null; then
        echo -e "${GREEN}✓ 测试验证器启动成功${NC}"
    else
        echo -e "${YELLOW}⚠ 测试验证器启动失败，请手动启动: solana-test-validator${NC}"
    fi
fi

# 5. 空投测试 SOL
echo -e "\n${YELLOW}[5/5] 空投测试 SOL...${NC}"
sleep 2
if solana airdrop 10 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 空投成功${NC}"
else
    echo -e "${YELLOW}⚠ 空投失败（可能已有足够余额）${NC}"
fi

# 最终验证
echo ""
echo "=========================================="
echo "           环境验证"
echo "=========================================="
echo "Solana CLI:    $(solana --version 2>/dev/null || echo '未安装')"
echo "Anchor CLI:    $(anchor --version 2>/dev/null || echo '未安装')"
echo "RPC URL:       $(solana config get | grep 'RPC URL' | awk '{print $3}')"
echo "钱包地址:      $(solana address 2>/dev/null || echo '无')"
echo "SOL 余额:      $(solana balance 2>/dev/null || echo '0 SOL')"
echo "=========================================="
echo ""

if command -v solana &> /dev/null && command -v anchor &> /dev/null; then
    echo -e "${GREEN}✅ 开发环境安装完成！${NC}"
    echo ""
    echo "下一步："
    echo "  1. cd /workspace/lp-staking"
    echo "  2. anchor build"
    echo "  3. anchor test"
else
    echo -e "${RED}❌ 安装过程中出现错误，请检查日志${NC}"
    exit 1
fi
