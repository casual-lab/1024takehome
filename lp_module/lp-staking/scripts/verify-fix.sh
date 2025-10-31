#!/bin/bash

echo "🔧 Phase 3 问题修复 - 完整测试流程"
echo "======================================="
echo ""

# 1. 清理旧进程
echo "1️⃣ 清理旧的测试验证器..."
pkill -9 -f "solana-test-validator" 2>/dev/null
sleep 2
echo "✅ 清理完成"
echo ""

# 2. 运行测试
echo "2️⃣ 运行 anchor test (重新初始化环境)..."
cd /workspace/lp-staking
anchor test --skip-build > /tmp/test-output.log 2>&1 &
TEST_PID=$!

# 等待测试完成
echo "⏳ 等待测试完成..."
wait $TEST_PID

# 显示测试结果
echo ""
echo "📋 测试结果:"
tail -20 /tmp/test-output.log
echo ""

# 3. 验证 reward_config
echo "3️⃣ 验证 Reward Config 初始化..."
npx ts-node -e "
import * as anchor from '@coral-xyz/anchor';
import { Program } from '@coral-xyz/anchor';
import { LpStaking } from './target/types/lp_staking';
import { PublicKey, LAMPORTS_PER_SOL } from '@solana/web3.js';

const provider = anchor.AnchorProvider.env();
anchor.setProvider(provider);
const program = anchor.workspace.LpStaking as Program<LpStaking>;

async function check() {
  const [poolState] = PublicKey.findProgramAddressSync(
    [Buffer.from('pool_state')],
    program.programId
  );

  const [rewardConfig] = PublicKey.findProgramAddressSync(
    [Buffer.from('reward_config'), poolState.toBuffer()],
    program.programId
  );

  const [rewardVault] = PublicKey.findProgramAddressSync(
    [Buffer.from('reward_vault'), poolState.toBuffer()],
    program.programId
  );

  console.log('📍 PDA 地址:');
  console.log('  Pool State:', poolState.toBase58());
  console.log('  Reward Config:', rewardConfig.toBase58());
  console.log('  Reward Vault:', rewardVault.toBase58());
  console.log('');

  try {
    const config = await program.account.rewardConfig.fetch(rewardConfig);
    console.log('✅ Reward Config 已正确初始化!');
    console.log('  Emission Rate:', config.emissionRate.toString(), '=', config.emissionRate.toNumber() / 1000000, 'SOL/sec (÷1e6)');
    console.log('  Last Update Slot:', config.lastUpdateSlot.toString());
    console.log('  Acc Reward Per Share:', config.accRewardPerShare.toString());
    
    const vaultBalance = await provider.connection.getBalance(rewardVault);
    console.log('');
    console.log('💰 Reward Vault 余额:', vaultBalance / LAMPORTS_PER_SOL, 'SOL');
  } catch (e) {
    console.log('❌ Reward Config 不存在:', e.message);
    process.exit(1);
  }
}

check().catch(console.error);
"

echo ""
echo "======================================="
echo "✅ 验证完成！现在可以运行:"
echo "   npx ts-node auto-test.ts"
echo "======================================="
