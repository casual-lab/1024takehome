import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { LpStaking } from "../target/types/lp_staking";
import { 
  TOKEN_PROGRAM_ID,
  createMint,
  getOrCreateAssociatedTokenAccount,
  mintTo,
} from "@solana/spl-token";
import { assert } from "chai";
import { PublicKey, SystemProgram, LAMPORTS_PER_SOL } from "@solana/web3.js";


function sleep(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

describe("lp-staking", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.LpStaking as Program<LpStaking>;
  const payer = provider.wallet as anchor.Wallet;

  let wrappedUsdcMint: anchor.web3.PublicKey;
  let lpTokenMint: anchor.web3.PublicKey;
  let poolState: anchor.web3.PublicKey;
  let rewardConfig: anchor.web3.PublicKey;
  let poolUsdcAccount: anchor.web3.PublicKey;
  let rewardVault: anchor.web3.PublicKey;
  let userPosition: anchor.web3.PublicKey;

  const POOL_STATE_SEED = Buffer.from("pool_state");
  const REWARD_CONFIG_SEED = Buffer.from("reward_config");
  const USER_POSITION_SEED = Buffer.from("user_position");
  const REWARD_VAULT_SEED = Buffer.from("reward_vault");

  before(async () => {
    console.log("\n设置测试环境...");

    // 1. 创建 wrappedUSDC mint
    wrappedUsdcMint = await createMint(
      provider.connection,
      payer.payer,
      payer.publicKey,
      null,
      6
    );
    console.log("✓ wrappedUSDC Mint:", wrappedUsdcMint.toString());

    // 2. 找到 pool_state PDA
    [poolState] = anchor.web3.PublicKey.findProgramAddressSync(
      [POOL_STATE_SEED],
      program.programId
    );
    console.log("✓ Pool State PDA:", poolState.toString());

    // 3. 创建 LP Token mint（mint authority 设置为 pool_state）
    lpTokenMint = await createMint(
      provider.connection,
      payer.payer,
      poolState,
      null,
      9
    );
    console.log("✓ LP Token Mint:", lpTokenMint.toString());

    // 4. 获取 pool 的 USDC ATA（使用 payer 临时拥有，初始化后会转移）
    const poolUsdcAta = await getOrCreateAssociatedTokenAccount(
      provider.connection,
      payer.payer,
      wrappedUsdcMint,
      poolState,
      true // allowOwnerOffCurve - 允许 PDA 作为 owner
    );
    poolUsdcAccount = poolUsdcAta.address;
    console.log("✓ Pool USDC Account:", poolUsdcAccount.toString());

    // 5. 找到其他 PDAs
    [rewardConfig] = anchor.web3.PublicKey.findProgramAddressSync(
      [REWARD_CONFIG_SEED, poolState.toBuffer()],
      program.programId
    );

    [rewardVault] = anchor.web3.PublicKey.findProgramAddressSync(
      [REWARD_VAULT_SEED, poolState.toBuffer()],
      program.programId
    );

    [userPosition] = anchor.web3.PublicKey.findProgramAddressSync(
      [USER_POSITION_SEED, payer.publicKey.toBuffer(), poolState.toBuffer()],
      program.programId
    );

    console.log("✓ 测试环境设置完成!\n");
  });

  it("初始化流动性池", async () => {
    console.log("=== 测试: 初始化流动性池 ===");

    const tx = await program.methods
      .initialize(
        { fixedRate: {} },
        new anchor.BN(1_000_000), // 0.001 SOL/slot
        new anchor.BN(0),
        new anchor.BN(0),
        new anchor.BN(0)
      )
      .accounts({
        authority: payer.publicKey,
        wrappedUsdcMint: wrappedUsdcMint,
        lpTokenMint: lpTokenMint,
        poolUsdcAccount: poolUsdcAccount,
      })
      .rpc();

    console.log("✓ 初始化交易:", tx);

    const poolStateAccount = await program.account.poolState.fetch(poolState);
    assert.equal(
      poolStateAccount.authority.toString(),
      payer.publicKey.toString()
    );
    assert.equal(poolStateAccount.totalDeposited.toNumber(), 0);
    assert.equal(poolStateAccount.totalLpSupply.toNumber(), 0);

    console.log("✓ 池子初始化成功\n");
  });

  it("首次存入 USDC（1:1 比例）", async () => {
    console.log("=== 测试: 首次存入 10,000 USDC ===");

    // 获取用户 USDC 账户
    const userUsdcAta = await getOrCreateAssociatedTokenAccount(
      provider.connection,
      payer.payer,
      wrappedUsdcMint,
      payer.publicKey
    );

    // 铸造 100,000 USDC 给用户
    await mintTo(
      provider.connection,
      payer.payer,
      wrappedUsdcMint,
      userUsdcAta.address,
      payer.publicKey,
      100_000_000_000
    );
    console.log("✓ 已铸造 100,000 USDC 给用户");

    // 获取用户 LP Token 账户
    const userLpAta = await getOrCreateAssociatedTokenAccount(
      provider.connection,
      payer.payer,
      lpTokenMint,
      payer.publicKey
    );

    const depositAmount = new anchor.BN(10_000_000_000);

    const tx = await program.methods
      .deposit(depositAmount)
      .accounts({
        user: payer.publicKey,
        userUsdcAccount: userUsdcAta.address,
        poolUsdcAccount: poolUsdcAccount,
        lpTokenMint: lpTokenMint,
        userLpAccount: userLpAta.address,
      })
      .rpc();

    console.log("✓ 存入交易:", tx);

    const poolStateAccount = await program.account.poolState.fetch(poolState);
    assert.equal(
      poolStateAccount.totalDeposited.toString(),
      depositAmount.toString()
    );
    assert.equal(
      poolStateAccount.totalLpSupply.toString(),
      depositAmount.toString()
    );

    const userLpBalance = await provider.connection.getTokenAccountBalance(userLpAta.address);
    console.log("✓ 用户获得 LP Token:", userLpBalance.value.uiAmount);
    console.log("✓ 首次存入成功（1:1 比例）\n");
  });

  it("第二次存入 USDC（按比例计算）", async () => {
    console.log("=== 测试: 第二次存入 5,000 USDC ===");

    const userUsdcAta = await getOrCreateAssociatedTokenAccount(
      provider.connection,
      payer.payer,
      wrappedUsdcMint,
      payer.publicKey
    );

    const userLpAta = await getOrCreateAssociatedTokenAccount(
      provider.connection,
      payer.payer,
      lpTokenMint,
      payer.publicKey
    );

    const depositAmount = new anchor.BN(5_000_000_000);
    const poolStateBefore = await program.account.poolState.fetch(poolState);

    const tx = await program.methods
      .deposit(depositAmount)
      .accounts({
        user: payer.publicKey,
        userUsdcAccount: userUsdcAta.address,
        poolUsdcAccount: poolUsdcAccount,
        lpTokenMint: lpTokenMint,
        userLpAccount: userLpAta.address,
      })
      .rpc();

    console.log("✓ 存入交易:", tx);

    const poolStateAfter = await program.account.poolState.fetch(poolState);
    const expectedTotalDeposited = poolStateBefore.totalDeposited.add(depositAmount);
    const expectedTotalLp = poolStateBefore.totalLpSupply.add(depositAmount);

    assert.equal(
      poolStateAfter.totalDeposited.toString(),
      expectedTotalDeposited.toString()
    );
    assert.equal(
      poolStateAfter.totalLpSupply.toString(),
      expectedTotalLp.toString()
    );

    console.log("✓ 第二次存入成功\n");
  });

  it("提取部分 LP Token", async () => {
    console.log("=== 测试: 提取 3,000 LP Token ===");

    const userUsdcAta = await getOrCreateAssociatedTokenAccount(
      provider.connection,
      payer.payer,
      wrappedUsdcMint,
      payer.publicKey
    );

    const userLpAta = await getOrCreateAssociatedTokenAccount(
      provider.connection,
      payer.payer,
      lpTokenMint,
      payer.publicKey
    );

    const withdrawAmount = new anchor.BN(3_000_000_000); // 3 LP (9位小数)
    const poolStateBefore = await program.account.poolState.fetch(poolState);

    const tx = await program.methods
      .withdraw(withdrawAmount)
      .accounts({
        user: payer.publicKey,
        userUsdcAccount: userUsdcAta.address,
        poolUsdcAccount: poolUsdcAccount,
        lpTokenMint: lpTokenMint,
        userLpAccount: userLpAta.address,
      })
      .rpc();

    console.log("✓ 提取交易:", tx);

    const poolStateAfter = await program.account.poolState.fetch(poolState);
    const userLpBalance = await provider.connection.getTokenAccountBalance(userLpAta.address);

    console.log("✓ 提取后用户 LP 余额:", userLpBalance.value.uiAmount);
    console.log("✓ 提取成功\n");
  });

  it("边界测试: 尝试存入低于最小金额", async () => {
    console.log("=== 测试: 存入低于最小金额（应失败）===");

    const userUsdcAta = await getOrCreateAssociatedTokenAccount(
      provider.connection,
      payer.payer,
      wrappedUsdcMint,
      payer.publicKey
    );

    const userLpAta = await getOrCreateAssociatedTokenAccount(
      provider.connection,
      payer.payer,
      lpTokenMint,
      payer.publicKey
    );

    const tooSmallAmount = new anchor.BN(500_000);

    try {
      await program.methods
        .deposit(tooSmallAmount)
        .accounts({
          user: payer.publicKey,
          userUsdcAccount: userUsdcAta.address,
          poolUsdcAccount: poolUsdcAccount,
          lpTokenMint: lpTokenMint,
          userLpAccount: userLpAta.address,
        })
        .rpc();
      
      assert.fail("应该抛出 InvalidAmount 错误");
    } catch (err: any) {
      assert.include(err.toString(), "InvalidAmount");
      console.log("✓ 正确拒绝了低于最小金额的存款\n");
    }
  });

  it("Phase 3 测试", async () => {
    // 2. 获取池子状态并断言已初始化
    const poolStateAccount = await program.account.poolState.fetch(poolState);
    assert.isOk(poolStateAccount, "池子未初始化，请先运行初始化测试");

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

    // 4. 检查 Reward Vault 余额，断言足够（>= 5 SOL）
    const vaultBalance = await provider.connection.getBalance(rewardVault);
    if (vaultBalance < 5 * LAMPORTS_PER_SOL) {
      console.log("⏳ 充值 Reward Vault (10 SOL)...");
      const transferIx = SystemProgram.transfer({
        fromPubkey: payer.publicKey,
        toPubkey: rewardVault,
        lamports: 10 * LAMPORTS_PER_SOL,
      });
      const transferTx = new anchor.web3.Transaction().add(transferIx);
      await provider.sendAndConfirm(transferTx);
      const newVaultBalance = await provider.connection.getBalance(rewardVault);
      console.log("✅ 充值完成，新余额:", newVaultBalance / LAMPORTS_PER_SOL, "SOL\n");
      if (newVaultBalance < 5 * LAMPORTS_PER_SOL) {
        throw new Error("Reward Vault 余额仍不足，请手动充值至少 5 SOL");
      }
    } else {
      assert.isAtLeast(
        vaultBalance,
        5 * LAMPORTS_PER_SOL,
        "Reward Vault 余额不足，请将至少 5 SOL 转入 rewardVault PDA"
      );
    }
    console.log("✅ Reward Vault 余额充足\n");

    // 5. 测试质押：记录质押前后并断言变化正确
    console.log("========================================");
    console.log("测试 1: 质押 LP tokens");
    console.log("========================================");

    const stakeAmount = new anchor.BN(5_000_000_000); // 5 LP

    const userPosBeforeStake = await program.account.userPosition.fetch(userPosition);
    try {
      const stakeTx = await program.methods.stake(stakeAmount).rpc();
      console.log("交易:", stakeTx);
    } catch (err: any) {
      assert.fail("质押交易失败: " + (err?.message ?? err));
    }

    const userPosAfterStake = await program.account.userPosition.fetch(userPosition);
    assert.isTrue(
      userPosAfterStake.stakedAmount.eq(userPosBeforeStake.stakedAmount.add(stakeAmount)),
      "质押后 stakedAmount 未按预期增加"
    );
    console.log("✅ 质押断言通过\n");

    // 6. 等待奖励累积并断言 pendingReward 增加
    console.log("========================================");
    console.log("测试 2: 等待奖励累积");
    console.log("========================================");
    
    const slotBeforeWait = await provider.connection.getSlot();
    console.log("等待前 Slot:", slotBeforeWait);
    
    await sleep(20000);

    const slotAfterWait = await provider.connection.getSlot();
    console.log("等待后 Slot:", slotAfterWait, "(Δ=" + (slotAfterWait - slotBeforeWait) + " slots)");
    
    // 需要触发一次交互来更新 pendingReward
    // 这里我们进行一次小额质押来触发奖励计算
    console.log("触发奖励更新（通过小额质押 1 LP）...");
    const smallStakeAmount = new anchor.BN(1_000_000_000); // 1 LP
    const triggerTx = await program.methods.stake(smallStakeAmount).rpc();
    console.log("✓ 触发交易:", triggerTx);

    const userPosAfterWait = await program.account.userPosition.fetch(userPosition);
    
    console.log("✓ 用户待领取奖励:", (userPosAfterWait.pendingReward.toNumber() / 1e9).toFixed(6), "SOL");

    // 断言累积的 pendingReward 增加（>0）
    assert.isTrue(
      userPosAfterWait.pendingReward.gt(new anchor.BN(0)),
      "等待后 pendingReward 未增加，请检查 emission 配置"
    );
    console.log("✅ 等待后奖励累积断言通过\n");

    // 7. 测试解除部分质押：记录前后并断言减少
    console.log("========================================");
    console.log("测试 3: 解除部分质押");
    console.log("========================================");

    const unstakeAmount = new anchor.BN(2_000_000_000); // 2 LP
    const userPosBeforeUnstake = await program.account.userPosition.fetch(userPosition);

    try {
      const unstakeTx = await program.methods.unstake(unstakeAmount).rpc();
      console.log("交易:", unstakeTx);
    } catch (err: any) {
      assert.fail("解除质押交易失败: " + (err?.message ?? err));
    }

    const userPosAfterUnstake = await program.account.userPosition.fetch(userPosition);
    assert.isTrue(
      userPosAfterUnstake.stakedAmount.eq(userPosBeforeUnstake.stakedAmount.sub(unstakeAmount)),
      "解除质押后 stakedAmount 未按预期减少"
    );
    console.log("✅ 部分解除质押断言通过\n");

    // 8. 测试领取奖励：断言有待领取奖励并且领取后 pendingReward 减少
    console.log("========================================");
    console.log("测试 4: 领取奖励");
    console.log("========================================");

    const userPosBeforeClaim = await program.account.userPosition.fetch(userPosition);
    assert.isTrue(
      userPosBeforeClaim.pendingReward.gt(new anchor.BN(0)),
      "当前没有待领取的奖励，无法执行领取测试"
    );

    const balanceBefore = await provider.connection.getBalance(payer.publicKey);
    try {
      const claimTx = await program.methods.claim().rpc();
      console.log("交易:", claimTx);
    } catch (err: any) {
      assert.fail("领取奖励交易失败: " + (err?.message ?? err));
    }
    const balanceAfter = await provider.connection.getBalance(payer.publicKey);
    const userPosAfterClaim = await program.account.userPosition.fetch(userPosition);

    assert.isTrue(
      userPosAfterClaim.pendingReward.lt(userPosBeforeClaim.pendingReward),
      "领取后 pendingReward 未减少"
    );
    assert.isAtLeast(
      balanceAfter,
      balanceBefore,
      "领取后用户账户余额未增加（注意：交易费可能影响，但余额应有净增加）"
    );
    console.log("✅ 领取奖励断言通过\n");

    // 9. 测试完全解除质押：断言之前有质押且解除后为 0
    console.log("========================================");
    console.log("测试 5: 完全解除质押");
    console.log("========================================");

    const userPosBeforeUnstakeAll = await program.account.userPosition.fetch(userPosition);
    const allStaked = userPosBeforeUnstakeAll.stakedAmount;
    assert.isTrue(allStaked.gt(new anchor.BN(0)), "当前没有质押，无法执行完全解除质押测试");

    try {
      const unstakeAllTx = await program.methods.unstake(allStaked).rpc();
      console.log("交易:", unstakeAllTx);
    } catch (err: any) {
      assert.fail("完全解除质押交易失败: " + (err?.message ?? err));
    }

    const userPosAfterUnstakeAll = await program.account.userPosition.fetch(userPosition);
    const poolStateAfter = await program.account.poolState.fetch(poolState);

    assert.isTrue(
      userPosAfterUnstakeAll.stakedAmount.eq(new anchor.BN(0)),
      "完全解除质押后 userPosition.stakedAmount 应为 0"
    );
    console.log("✅ 完全解除质押断言通过\n");


  });
});
