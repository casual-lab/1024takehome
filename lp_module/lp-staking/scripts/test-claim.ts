/**
 * 简单的领取奖励测试脚本
 * 用法: npx ts-node scripts/test-claim.ts
 */

import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { LpStaking } from "../target/types/lp_staking";
import { PublicKey, LAMPORTS_PER_SOL } from "@solana/web3.js";

const provider = anchor.AnchorProvider.env();
anchor.setProvider(provider);
const program = anchor.workspace.LpStaking as Program<LpStaking>;
const payer = provider.wallet as anchor.Wallet;

const USER_POSITION_SEED = "user_position";
const REWARD_VAULT_SEED = "reward_vault";

async function main() {
  console.log("\n🎯 领取质押奖励...");

  // 获取 PDAs
  const [poolState] = PublicKey.findProgramAddressSync(
    [Buffer.from("pool_state")],
    program.programId
  );

  const [userPosition] = PublicKey.findProgramAddressSync(
    [Buffer.from(USER_POSITION_SEED), payer.publicKey.toBuffer(), poolState.toBuffer()],
    program.programId
  );

  const [rewardVault] = PublicKey.findProgramAddressSync(
    [Buffer.from(REWARD_VAULT_SEED), poolState.toBuffer()],
    program.programId
  );

  try {
    // 领取前状态
    const userPosBefore = await program.account.userPosition.fetch(userPosition);
    const userBalanceBefore = await provider.connection.getBalance(payer.publicKey);
    const vaultBalanceBefore = await provider.connection.getBalance(rewardVault);

    console.log("📊 领取前:");
    console.log("  Pending Reward:", userPosBefore.pendingReward.toNumber() / LAMPORTS_PER_SOL, "SOL");
    console.log("  用户 SOL 余额:", userBalanceBefore / LAMPORTS_PER_SOL, "SOL");
    console.log("  Vault SOL 余额:", vaultBalanceBefore / LAMPORTS_PER_SOL, "SOL");

    if (userPosBefore.pendingReward.toNumber() === 0) {
      console.log("\n⚠️  当前没有待领取的奖励");
      console.log("   提示: 质押后需要等待一段时间才会有奖励累积");
      return;
    }

    // 执行领取
    const tx = await program.methods.claim().rpc();

    console.log("\n✅ 领取成功!");
    console.log("   交易签名:", tx);

    // 领取后状态
    const userPosAfter = await program.account.userPosition.fetch(userPosition);
    const userBalanceAfter = await provider.connection.getBalance(payer.publicKey);
    const vaultBalanceAfter = await provider.connection.getBalance(rewardVault);

    const actualReceived = (userBalanceAfter - userBalanceBefore) / LAMPORTS_PER_SOL;
    const vaultDecrease = (vaultBalanceBefore - vaultBalanceAfter) / LAMPORTS_PER_SOL;

    console.log("\n📊 领取后:");
    console.log("  Pending Reward:", userPosAfter.pendingReward.toNumber() / LAMPORTS_PER_SOL, "SOL");
    console.log("  用户 SOL 余额:", userBalanceAfter / LAMPORTS_PER_SOL, "SOL");
    console.log("  Vault SOL 余额:", vaultBalanceAfter / LAMPORTS_PER_SOL, "SOL");

    console.log("\n💰 奖励详情:");
    console.log("  Vault 减少:", vaultDecrease.toFixed(6), "SOL");
    console.log("  用户增加:", actualReceived.toFixed(6), "SOL (已扣除交易费)");
    console.log("  交易费用:", (vaultDecrease - actualReceived).toFixed(6), "SOL");

  } catch (error: any) {
    console.error("\n❌ 领取失败:", error.message);
    if (error.logs) {
      console.error("日志:", error.logs);
    }
    
    // 检查常见错误
    if (error.message.includes("NoRewardToClaim")) {
      console.log("\n💡 没有可领取的奖励，请先质押并等待一段时间");
    } else if (error.message.includes("InsufficientRewardVault")) {
      console.log("\n💡 Reward Vault 余额不足，请先充值:");
      console.log("   solana transfer 253KaQanuVPGwt44ixarUcFWjeeBKsAeo2dtRHW9CkBt 10");
    }
    
    process.exit(1);
  }
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error);
  process.exit(1);
});
