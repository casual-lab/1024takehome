# PDA Seeds 完整清单

## ⚠️ 重要：所有 PDA 的正确 Seeds 结构

根据 `programs/lp-staking/src/instructions/initialize.rs` 中的定义，所有 PDA 的 seeds 如下：

### 1. Pool State
```rust
seeds = [POOL_STATE_SEED]  // ✅ 1 个 seed
```

```typescript
const [poolState] = PublicKey.findProgramAddressSync(
  [Buffer.from("pool_state")],
  program.programId
);
```

**地址**: `9o1uwsufiCcELp7PjDWqJ1w6fKAGHtp9AJvuysYZbnRy`

---

### 2. Reward Config  
```rust
seeds = [REWARD_CONFIG_SEED, pool_state.key().as_ref()]  // ⚠️ 2 个 seeds!
```

```typescript
const [rewardConfig] = PublicKey.findProgramAddressSync(
  [Buffer.from("reward_config"), poolState.toBuffer()],
  program.programId
);
```

**地址**: `6hraeyiRiJDjRTNeoHPLTGVPzmiCHGJLwuG1zUJ1167b`

❌ **错误用法**: `[Buffer.from("reward_config")]` (缺少 poolState)

---

### 3. Reward Vault
```rust
seeds = [REWARD_VAULT_SEED, pool_state.key().as_ref()]  // ⚠️ 2 个 seeds!
```

```typescript
const [rewardVault] = PublicKey.findProgramAddressSync(
  [Buffer.from("reward_vault"), poolState.toBuffer()],
  program.programId
);
```

**正确地址**: 取决于 poolState

❌ **错误用法**: `[Buffer.from("reward_vault")]` (缺少 poolState)
❌ **之前使用的错误地址**: `253KaQanuVPGwt44ixarUcFWjeeBKsAeo2dtRHW9CkBt`

---

### 4. User Position
```rust
seeds = [USER_POSITION_SEED, user.key().as_ref(), pool_state.key().as_ref()]  // ⚠️ 3 个 seeds!
```

```typescript
const [userPosition] = PublicKey.findProgramAddressSync(
  [
    Buffer.from("user_position"),
    userPublicKey.toBuffer(),
    poolState.toBuffer()
  ],
  program.programId
);
```

❌ **错误用法**: `[Buffer.from("user_position"), userPublicKey.toBuffer()]` (缺少 poolState)

---

## 🐛 问题根源

### 为什么之前能部分工作？

在 stake/unstake/claim 指令中，Anchor 会根据 `#[account(...)]` 约束**自动推导**正确的 PDA 地址来验证账户。

```rust
#[account(
    seeds = [REWARD_VAULT_SEED, pool_state.key().as_ref()],
    bump
)]
pub reward_vault: AccountInfo<'info>,
```

所以即使测试脚本计算的 PDA 地址错误，**交易仍然能成功**，因为 Anchor 使用的是正确的地址。

但是测试脚本中的 `fetch()` 操作使用的是手动计算的错误地址，所以**无法读取账户数据**。

---

## ✅ 修复清单

需要修复以下文件中的 PDA 计算：

- [x] `auto-test.ts` - reward_config
- [x] `manual-test.ts` - reward_config  
- [ ] `auto-test.ts` - reward_vault
- [ ] `manual-test.ts` - reward_vault
- [ ] `scripts/test-stake.ts`
- [ ] `scripts/test-unstake.ts`
- [ ] `scripts/test-claim.ts`
- [ ] `tests/phase3-staking.ts.disabled`

---

## 📝 正确的初始化流程

```typescript
// 1. 首先计算 pool_state (不依赖其他 PDA)
const [poolState] = PublicKey.findProgramAddressSync(
  [Buffer.from("pool_state")],
  program.programId
);

// 2. 然后计算依赖 pool_state 的 PDAs
const [rewardConfig] = PublicKey.findProgramAddressSync(
  [Buffer.from("reward_config"), poolState.toBuffer()],
  program.programId
);

const [rewardVault] = PublicKey.findProgramAddressSync(
  [Buffer.from("reward_vault"), poolState.toBuffer()],
  program.programId
);

const [userPosition] = PublicKey.findProgramAddressSync(
  [Buffer.from("user_position"), userKey.toBuffer(), poolState.toBuffer()],
  program.programId
);
```

---

## 🎯 测试验证

修复后运行：

```bash
npx ts-node -e "
import * as anchor from '@coral-xyz/anchor';
import { Program } from '@coral-xyz/anchor';
import { LpStaking } from './target/types/lp_staking';
import { PublicKey } from '@solana/web3.js';

const provider = anchor.AnchorProvider.env();
anchor.setProvider(provider);
const program = anchor.workspace.LpStaking as Program<LpStaking>;

async function verify() {
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

  console.log('Pool State:', poolState.toBase58());
  console.log('Reward Config:', rewardConfig.toBase58());
  console.log('Reward Vault:', rewardVault.toBase58());

  const config = await program.account.rewardConfig.fetch(rewardConfig);
  console.log('✅ Reward Config 存在! Emission Rate:', config.emissionRate.toString());
}

verify().catch(console.error);
"
```

应该输出：
```
Pool State: 9o1uwsufiCcELp7PjDWqJ1w6fKAGHtp9AJvuysYZbnRy
Reward Config: 6hraeyiRiJDjRTNeoHPLTGVPzmiCHGJLwuG1zUJ1167b
Reward Vault: (正确地址)
✅ Reward Config 存在! Emission Rate: 1000
```
