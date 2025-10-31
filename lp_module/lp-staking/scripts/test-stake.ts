/**
 * 简单的质押测试脚本
 * 用法: npx ts-node scripts/test-stake.ts <amount>
 * 示例: npx ts-node scripts/test-stake.ts 5
 */

import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { LpStaking } from "../target/types/lp_staking";
import { PublicKey } from "@solana/web3.js";

const provider = anchor.AnchorProvider.env();
anchor.setProvider(provider);
const program = anchor.workspace.LpStaking as Program<LpStaking>;
const payer = provider.wallet as anchor.Wallet;

const USER_POSITION_SEED = "user_position";

async function main() {
  const amount = process.argv[2] || "5";
  const stakeAmount = new anchor.BN(parseFloat(amount) * 1e9);

  console.log(`\n🎯 质押 ${amount} LP tokens...`);

  // 获取 user position PDA
  const [poolState] = PublicKey.findProgramAddressSync(
    [Buffer.from("pool_state")],
    program.programId
  );

  const [userPosition] = PublicKey.findProgramAddressSync(
    [Buffer.from(USER_POSITION_SEED), payer.publicKey.toBuffer(), poolState.toBuffer()],
    program.programId
  );

  try {
    // 质押前状态
    let userPosBefore;
    try {
      userPosBefore = await program.account.userPosition.fetch(userPosition);
      console.log("📊 质押前:");
      console.log("  LP Balance:", userPosBefore.lpBalance.toNumber() / 1e9, "LP");
      console.log("  Staked:", userPosBefore.stakedAmount.toNumber() / 1e9, "LP");
      console.log("  Pending Reward:", userPosBefore.pendingReward.toNumber() / 1e9, "SOL");
    } catch (e) {
      console.log("📊 首次质押");
    }

    // 执行质押
    const tx = await program.methods.stake(stakeAmount).rpc();

    console.log("\n✅ 质押成功!");
    console.log("   交易签名:", tx);

    // 质押后状态
    const userPosAfter = await program.account.userPosition.fetch(userPosition);
    console.log("\n📊 质押后:");
    console.log("  LP Balance:", userPosAfter.lpBalance.toNumber() / 1e9, "LP");
    console.log("  Staked:", userPosAfter.stakedAmount.toNumber() / 1e9, "LP");
    console.log("  Pending Reward:", userPosAfter.pendingReward.toNumber() / 1e9, "SOL");
    console.log("  Reward Debt:", userPosAfter.rewardDebt.toString());

    // 池子总质押
    const poolStateAccount = await program.account.poolState.fetch(poolState);
    console.log("\n🏊 池子总质押:", poolStateAccount.totalStaked.toNumber() / 1e9, "LP");

  } catch (error: any) {
    console.error("\n❌ 质押失败:", error.message);
    if (error.logs) {
      console.error("日志:", error.logs);
    }
    process.exit(1);
  }
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error);
  process.exit(1);
});
