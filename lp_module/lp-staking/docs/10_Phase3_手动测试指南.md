# Phase 3 手动测试指南

## 准备工作

### 1. 启动本地验证器

```bash
# 在终端 1 中运行
solana-test-validator
```

### 2. 部署程序并运行 Phase 2 测试

```bash
# 在终端 2 中运行
cd /workspace/lp-staking
anchor test --skip-local-validator
```

等待 Phase 2 的 5 个测试全部通过。这会创建池子并存入一些 LP tokens。

## 方法 1: 使用交互式脚本（推荐）

### 运行交互式测试脚本

```bash
cd /workspace/lp-staking
npx ts-node manual-test.ts
```

脚本会显示：
- 📍 所有 PDA 地址
- 💰 用户账户地址
- 💵 当前余额（SOL, USDC, LP）
- 📊 用户质押状态
- 🏦 Reward Vault 余额
- ⚙️ 奖励配置

然后提供交互式菜单：
```
测试选项:
1. 质押 LP tokens
2. 解除质押
3. 领取奖励
4. 充值 Reward Vault
5. 查看当前状态 (刷新)
0. 退出
```

### 典型测试流程

1. **充值 Reward Vault**
   - 选择 `4`
   - 输入 `10` (充值 10 SOL)

2. **质押 LP tokens**
   - 选择 `1`
   - 输入 `5` (质押 5 LP)
   - 查看质押成功的交易签名

3. **等待奖励累积**
   - 等待 10-30 秒
   - 选择 `5` 刷新状态
   - 观察 `Pending Reward` 是否增加

4. **解除部分质押**
   - 选择 `2`
   - 输入 `2` (解除 2 LP)
   - 观察 `Pending Reward` 累积

5. **领取奖励**
   - 选择 `3`
   - 查看实际到账的 SOL 数量

6. **完全解除质押**
   - 选择 `2`
   - 输入 `all` (解除全部)

## 方法 2: 使用 Anchor CLI

### 1. 查看账户状态

```bash
# 查看池子状态
anchor account lp-staking.PoolState 9o1uwsufiCcELp7PjDWqJ1w6fKAGHtp9AJvuysYZbnRy

# 查看奖励配置
anchor account lp-staking.RewardConfig J3Q5uHAvKnoU86Py28CCL4WmDbmDnzBuLVMLBG9uMVn6

# 查看用户位置 (需要先计算 PDA)
# 使用 anchor run 命令执行自定义脚本
```

### 2. 调用指令

```bash
# 质押 5 LP
anchor run stake -- 5000000000

# 解除质押 2 LP  
anchor run unstake -- 2000000000

# 领取奖励
anchor run claim
```

## 方法 3: 使用 Solana CLI

### 1. 充值 Reward Vault

```bash
# Reward Vault PDA: 253KaQanuVPGwt44ixarUcFWjeeBKsAeo2dtRHW9CkBt
solana transfer 253KaQanuVPGwt44ixarUcFWjeeBKsAeo2dtRHW9CkBt 10
```

### 2. 查看账户余额

```bash
# 查看 Reward Vault SOL 余额
solana balance 253KaQanuVPGwt44ixarUcFWjeeBKsAeo2dtRHW9CkBt

# 查看你的 SOL 余额
solana balance
```

## 方法 4: 编写自定义测试脚本

创建文件 `test-stake.ts`:

```typescript
import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { LpStaking } from "./target/types/lp_staking";

const provider = anchor.AnchorProvider.env();
anchor.setProvider(provider);
const program = anchor.workspace.LpStaking as Program<LpStaking>;

async function testStake() {
  const stakeAmount = new anchor.BN(5_000_000_000); // 5 LP
  
  const tx = await program.methods
    .stake(stakeAmount)
    .rpc();
  
  console.log("质押成功! 交易:", tx);
}

testStake().catch(console.error);
```

运行:
```bash
npx ts-node test-stake.ts
```

## 验证奖励计算

### 预期奖励公式

**FixedRate 模式** (当前配置):
```
每秒奖励 = 1,000,000 lamports = 0.001 SOL
用户奖励 = (用户质押 / 总质押) × 每秒奖励 × 时间(秒)
```

**示例**:
- 用户质押: 5 LP
- 总质押: 5 LP (假设只有你一个人)
- 质押时间: 10 秒
- 预期奖励: (5/5) × 0.001 × 10 = 0.01 SOL

### 手动验证步骤

1. 记录质押时间戳 T1
2. 等待 N 秒
3. 记录当前时间戳 T2
4. 查看 pending_reward
5. 计算: expected = (T2 - T1) × 0.001
6. 对比 pending_reward 是否接近 expected

## 常见问题排查

### 问题 1: "Account does not exist"
**原因**: 池子未初始化  
**解决**: 先运行 `anchor test --skip-local-validator`

### 问题 2: "Insufficient LP balance"
**原因**: 没有可用的 LP tokens  
**解决**: 先运行 deposit 存入 USDC 获取 LP

### 问题 3: "Insufficient reward vault balance"
**原因**: Reward Vault 没有 SOL  
**解决**: 使用交互脚本的选项 4 充值

### 问题 4: 奖励为 0
**原因**: 质押时间太短或池子总质押为 0  
**解决**: 等待更长时间（至少 10 秒）

### 问题 5: "This transaction has already been processed"
**原因**: 交易签名重复  
**解决**: 等待几秒再重试，或重启验证器

## 进阶测试场景

### 场景 1: 多用户质押
使用不同的钱包分别质押，验证奖励按比例分配:
```bash
# 生成新钱包
solana-keygen new -o ~/.config/solana/test-wallet-2.json

# 切换钱包
export ANCHOR_WALLET=~/.config/solana/test-wallet-2.json

# 给新钱包空投
solana airdrop 10

# 运行交互脚本
npx ts-node manual-test.ts
```

### 场景 2: 长时间质押
1. 质押 LP
2. 等待 60 秒
3. 查看累积奖励
4. 验证: 约 0.06 SOL (60 × 0.001)

### 场景 3: 部分解除质押
1. 质押 10 LP
2. 等待 10 秒
3. 解除质押 5 LP
4. 验证 pending_reward 已累积
5. 再等待 10 秒
6. 领取奖励
7. 验证收到的奖励

### 场景 4: Vault 余额不足
1. 不充值 Vault (或充值很少)
2. 质押并等待大量奖励累积
3. 尝试领取
4. 验证错误: "Insufficient reward vault balance"

## 测试清单

完成以下所有操作以验证 Phase 3 功能:

- [ ] ✅ 程序成功编译（无错误无警告）
- [ ] ✅ Phase 2 测试全部通过
- [ ] ✅ 成功充值 Reward Vault
- [ ] ✅ 成功质押 LP tokens
- [ ] ✅ 验证 total_staked 正确更新
- [ ] ✅ 验证 user_position.staked_amount 正确
- [ ] ✅ 等待 10+ 秒后奖励开始累积
- [ ] ✅ pending_reward > 0
- [ ] ✅ 成功解除部分质押
- [ ] ✅ pending_reward 继续累积
- [ ] ✅ 成功领取奖励到钱包
- [ ] ✅ pending_reward 清零
- [ ] ✅ 成功完全解除质押
- [ ] ✅ total_staked 正确减少

## 下一步

完成手动测试后，你可以:

1. **记录测试结果** - 创建测试报告文档
2. **优化代码** - 根据测试发现改进
3. **添加更多功能** - 如管理员功能、紧急暂停等
4. **准备部署** - devnet/mainnet 部署准备

---

**提示**: 使用交互式脚本是最简单的方式！只需运行 `npx ts-node manual-test.ts` 即可开始。
