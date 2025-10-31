/**
 * 简单的解除质押测试脚本
 * 用法: npx ts-node scripts/test-unstake.ts <amount>
 * 示例: npx ts-node scripts/test-unstake.ts 2
 *       npx ts-node scripts/test-unstake.ts all
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
  const amountArg = process.argv[2] || "all";

  console.log(`\n🎯 解除质押 ${amountArg === "all" ? "全部" : amountArg + " LP"}...`);

  // 获取 PDAs
  const [poolState] = PublicKey.findProgramAddressSync(
    [Buffer.from("pool_state")],
    program.programId
  );

  const [userPosition] = PublicKey.findProgramAddressSync(
    [Buffer.from(USER_POSITION_SEED), payer.publicKey.toBuffer(), poolState.toBuffer()],
    program.programId
  );

  try {
    // 解除质押前状态
    const userPosBefore = await program.account.userPosition.fetch(userPosition);
    console.log("📊 解除质押前:");
    console.log("  LP Balance:", userPosBefore.lpBalance.toNumber() / 1e9, "LP");
    console.log("  Staked:", userPosBefore.stakedAmount.toNumber() / 1e9, "LP");
    console.log("  Pending Reward:", userPosBefore.pendingReward.toNumber() / 1e9, "SOL");

    // 计算解除质押数量
    let unstakeAmount;
    if (amountArg.toLowerCase() === "all") {
      unstakeAmount = userPosBefore.stakedAmount;
      console.log(`\n💡 将解除全部质押: ${unstakeAmount.toNumber() / 1e9} LP`);
    } else {
      unstakeAmount = new anchor.BN(parseFloat(amountArg) * 1e9);
    }

    // 执行解除质押
    const tx = await program.methods.unstake(unstakeAmount).rpc();

    console.log("\n✅ 解除质押成功!");
    console.log("   交易签名:", tx);

    // 解除质押后状态
    const userPosAfter = await program.account.userPosition.fetch(userPosition);
    console.log("\n📊 解除质押后:");
    console.log("  LP Balance:", userPosAfter.lpBalance.toNumber() / 1e9, "LP");
    console.log("  Staked:", userPosAfter.stakedAmount.toNumber() / 1e9, "LP");
    console.log("  Pending Reward:", userPosAfter.pendingReward.toNumber() / 1e9, "SOL");

    // 池子总质押
    const poolStateAccount = await program.account.poolState.fetch(poolState);
    console.log("\n🏊 池子总质押:", poolStateAccount.totalStaked.toNumber() / 1e9, "LP");

  } catch (error: any) {
    console.error("\n❌ 解除质押失败:", error.message);
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
