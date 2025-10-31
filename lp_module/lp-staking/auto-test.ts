/**
 * 自动化测试脚本 - 完整的 Phase 3 测试流程
 * 用法: npx ts-node auto-test.ts
 */

import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { LpStaking } from "./target/types/lp_staking";
import { PublicKey, SystemProgram, LAMPORTS_PER_SOL } from "@solana/web3.js";
import {
  TOKEN_PROGRAM_ID,
  getOrCreateAssociatedTokenAccount,
} from "@solana/spl-token";

const provider = anchor.AnchorProvider.env();
anchor.setProvider(provider);
const program = anchor.workspace.LpStaking as Program<LpStaking>;
const payer = provider.wallet as anchor.Wallet;

const POOL_STATE_SEED = "pool_state";
const REWARD_VAULT_SEED = "reward_vault";
const USER_POSITION_SEED = "user_position";
const REWARD_CONFIG_SEED = "reward_config";

function sleep(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
  console.log("\n🚀 开始 Phase 3 自动化测试\n");

  // 1. 获取 PDAs
  const [poolState] = PublicKey.findProgramAddressSync(
    [Buffer.from(POOL_STATE_SEED)],
    program.programId
  );

  const [rewardVault] = PublicKey.findProgramAddressSync(
    [Buffer.from(REWARD_VAULT_SEED), poolState.toBuffer()],
    program.programId
  );

  const [userPosition] = PublicKey.findProgramAddressSync(
    [Buffer.from(USER_POSITION_SEED), payer.publicKey.toBuffer(), poolState.toBuffer()],
    program.programId
  );

  const [rewardConfig] = PublicKey.findProgramAddressSync(
    [Buffer.from(REWARD_CONFIG_SEED), poolState.toBuffer()],
    program.programId
  );

  // 2. 获取池子状态
  let poolStateAccount;
  try {
    poolStateAccount = await program.account.poolState.fetch(poolState);
    console.log("✅ 池子已初始化");
  } catch (error) {
    console.log("❌ 池子未初始化，请先运行: anchor test --skip-local-validator");
    process.exit(1);
  }

  // 3. 获取用户 LP 账户
  const userLpAccount = (
    await getOrCreateAssociatedTokenAccount(
      provider.connection,
      payer.payer,
      poolStateAccount.lpTokenMint,
      payer.publicKey,
      true
    )
  ).address;

  const lpBalance = await provider.connection.getTokenAccountBalance(userLpAccount);
  console.log("💰 当前 LP 余额:", lpBalance.value.uiAmount, "LP\n");

  // 4. 检查并充值 Reward Vault
  let vaultBalance = await provider.connection.getBalance(rewardVault);
  console.log("🏦 Reward Vault 余额:", vaultBalance / LAMPORTS_PER_SOL, "SOL");
  
  if (vaultBalance < 5 * LAMPORTS_PER_SOL) {
    console.log("⏳ 充值 Reward Vault (10 SOL)...");
    const transferIx = SystemProgram.transfer({
      fromPubkey: payer.publicKey,
      toPubkey: rewardVault,
      lamports: 10 * LAMPORTS_PER_SOL,
    });
    const transferTx = new anchor.web3.Transaction().add(transferIx);
    await provider.sendAndConfirm(transferTx);
    vaultBalance = await provider.connection.getBalance(rewardVault);
    console.log("✅ 充值完成，新余额:", vaultBalance / LAMPORTS_PER_SOL, "SOL\n");
  } else {
    console.log("✅ Reward Vault 余额充足\n");
  }

  // 5. 测试质押
  console.log("========================================");
  console.log("测试 1: 质押 LP tokens");
  console.log("========================================");
  
  const stakeAmount = new anchor.BN(5_000_000_000); // 5 LP
  console.log("⏳ 质押 5 LP...");
  
  try {
    const stakeTx = await program.methods.stake(stakeAmount).rpc();
    console.log("✅ 质押成功! 交易:", stakeTx);
    
    const userPos = await program.account.userPosition.fetch(userPosition);
    console.log("📊 质押后状态:");
    console.log("  - LP Balance:", userPos.lpBalance.toNumber() / 1e9, "LP");
    console.log("  - Staked:", userPos.stakedAmount.toNumber() / 1e9, "LP");
    console.log("  - Pending Reward:", userPos.pendingReward.toNumber() / LAMPORTS_PER_SOL, "SOL");
    console.log();
  } catch (error: any) {
    console.log("❌ 质押失败:", error.message);
    console.log("提示: 确保你有足够的 LP tokens (至少 5 LP)\n");
  }

  // 6. 等待奖励累积
  console.log("========================================");
  console.log("测试 2: 等待奖励累积");
  console.log("========================================");
  console.log("⏳ 等待 20 秒让奖励累积...");
  
  await sleep(20000);
  
  try {
    const userPos = await program.account.userPosition.fetch(userPosition);
    const rewardConfigAccount = await program.account.rewardConfig.fetch(rewardConfig);
    
    console.log("✅ 20 秒后状态:");
    console.log("📊 用户:");
    console.log("  - Staked:", userPos.stakedAmount.toNumber() / 1e9, "LP");
    console.log("  - Pending Reward:", userPos.pendingReward.toNumber() / LAMPORTS_PER_SOL, "SOL");
    console.log("  - Reward Debt:", userPos.rewardDebt.toString());
    
    console.log("⚙️  奖励配置:");
    console.log("  - 排放速率:", rewardConfigAccount.emissionRate.toString(), "lamports/秒");
    console.log("  - 累计每股奖励:", rewardConfigAccount.accRewardPerShare.toString());
    
    const poolState2 = await program.account.poolState.fetch(poolState);
    console.log("🏊 池子:");
    console.log("  - 总质押:", poolState2.totalStaked.toNumber() / 1e9, "LP");
    
    // 预期奖励计算
    const expectedReward = 20 * 0.001; // 20秒 × 0.001 SOL/秒
    console.log("\n💡 预期奖励: 约", expectedReward, "SOL (假设你是唯一质押者)");
    console.log();
  } catch (error: any) {
    console.log("❌ 获取状态失败:", error.message, "\n");
  }

  // 7. 测试解除部分质押
  console.log("========================================");
  console.log("测试 3: 解除部分质押");
  console.log("========================================");
  
  const unstakeAmount = new anchor.BN(2_000_000_000); // 2 LP
  console.log("⏳ 解除质押 2 LP...");
  
  try {
    const unstakeTx = await program.methods.unstake(unstakeAmount).rpc();
    console.log("✅ 解除质押成功! 交易:", unstakeTx);
    
    const userPos = await program.account.userPosition.fetch(userPosition);
    console.log("📊 解除质押后:");
    console.log("  - LP Balance:", userPos.lpBalance.toNumber() / 1e9, "LP");
    console.log("  - Staked:", userPos.stakedAmount.toNumber() / 1e9, "LP");
    console.log("  - Pending Reward:", userPos.pendingReward.toNumber() / LAMPORTS_PER_SOL, "SOL");
    console.log();
  } catch (error: any) {
    console.log("❌ 解除质押失败:", error.message, "\n");
  }

  // 8. 测试领取奖励
  console.log("========================================");
  console.log("测试 4: 领取奖励");
  console.log("========================================");
  
  try {
    const userBalanceBefore = await provider.connection.getBalance(payer.publicKey);
    const userPosBefore = await program.account.userPosition.fetch(userPosition);
    
    console.log("⏳ 领取奖励...");
    console.log("  - 待领取:", userPosBefore.pendingReward.toNumber() / LAMPORTS_PER_SOL, "SOL");
    
    if (userPosBefore.pendingReward.toNumber() === 0) {
      console.log("⚠️  当前没有待领取的奖励，跳过领取测试\n");
    } else {
      const claimTx = await program.methods.claim().rpc();
      console.log("✅ 领取成功! 交易:", claimTx);
      
      const userBalanceAfter = await provider.connection.getBalance(payer.publicKey);
      const received = (userBalanceAfter - userBalanceBefore) / LAMPORTS_PER_SOL;
      
      console.log("💰 实际到账 (扣除交易费):", received.toFixed(6), "SOL");
      
      const userPosAfter = await program.account.userPosition.fetch(userPosition);
      console.log("📊 领取后 Pending Reward:", userPosAfter.pendingReward.toNumber() / LAMPORTS_PER_SOL, "SOL");
      console.log();
    }
  } catch (error: any) {
    console.log("❌ 领取失败:", error.message, "\n");
  }

  // 9. 测试完全解除质押
  console.log("========================================");
  console.log("测试 5: 完全解除质押");
  console.log("========================================");
  
  try {
    const userPosBefore = await program.account.userPosition.fetch(userPosition);
    const allStaked = userPosBefore.stakedAmount;
    
    if (allStaked.toNumber() === 0) {
      console.log("⚠️  当前没有质押，跳过解除质押测试\n");
    } else {
      console.log("⏳ 解除全部质押 (", allStaked.toNumber() / 1e9, "LP)...");
      
      const unstakeAllTx = await program.methods.unstake(allStaked).rpc();
      console.log("✅ 完全解除质押成功! 交易:", unstakeAllTx);
      
      const userPosAfter = await program.account.userPosition.fetch(userPosition);
      const poolStateAfter = await program.account.poolState.fetch(poolState);
      
      console.log("📊 最终状态:");
      console.log("  - LP Balance:", userPosAfter.lpBalance.toNumber() / 1e9, "LP");
      console.log("  - Staked:", userPosAfter.stakedAmount.toNumber() / 1e9, "LP");
      console.log("  - Pending Reward:", userPosAfter.pendingReward.toNumber() / LAMPORTS_PER_SOL, "SOL");
      console.log("  - 池子总质押:", poolStateAfter.totalStaked.toNumber() / 1e9, "LP");
      console.log();
    }
  } catch (error: any) {
    console.log("❌ 完全解除质押失败:", error.message, "\n");
  }

  // 10. 测试总结
  console.log("========================================");
  console.log("✅ 测试完成!");
  console.log("========================================");
  console.log("\n建议：");
  console.log("1. 如果要进行交互式测试，运行: npx ts-node manual-test.ts");
  console.log("2. 查看详细测试指南: cat docs/10_Phase3_手动测试指南.md");
  console.log("3. 查看快速开始: cat MANUAL_TEST.md");
  console.log();
}

main().then(() => process.exit(0)).catch((error) => {
  console.error("\n❌ 测试失败:", error.message);
  if (error.logs) {
    console.error("日志:", error.logs);
  }
  process.exit(1);
});
