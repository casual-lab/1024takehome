# Anchor 项目结构与代码说明

## 文档信息
- **文档编号**: 04
- **创建日期**: 2025-10-31
- **状态**: Phase 1 完成 - 项目结构搭建

---

## 1. 项目结构概览

```
lp-staking/
├── programs/
│   └── lp-staking/              # 主智能合约程序
│       ├── src/
│       │   ├── lib.rs           # 程序入口
│       │   ├── constants.rs     # 常量定义
│       │   ├── errors.rs        # 错误类型定义
│       │   ├── state/           # 状态账户定义
│       │   │   ├── mod.rs
│       │   │   ├── pool_state.rs       # 池子状态
│       │   │   ├── user_position.rs    # 用户仓位
│       │   │   └── reward_config.rs    # 奖励配置
│       │   ├── instructions/    # 指令实现
│       │   │   ├── mod.rs
│       │   │   └── initialize.rs       # 初始化指令
│       │   └── utils/           # 工具函数
│       │       ├── mod.rs
│       │       └── reward_calculator.rs # 奖励计算器
│       └── Cargo.toml
├── tests/
│   └── lp-staking.ts            # 集成测试
├── app/                         # 客户端应用
├── migrations/                  # 部署脚本
├── Anchor.toml                  # Anchor 配置
└── package.json
```

---

## 2. 核心模块说明

### 2.1 状态账户 (State)

#### 2.1.1 PoolState (池子状态)
**文件**: `src/state/pool_state.rs`

**功能**: 存储流动性池的核心信息

**字段说明**:
```rust
pub struct PoolState {
    pub authority: Pubkey,              // 管理员地址
    pub wrapped_usdc_mint: Pubkey,      // wrappedUSDC Mint 地址
    pub lp_token_mint: Pubkey,          // LP Token Mint 地址
    pub pool_usdc_account: Pubkey,      // 池子的 USDC 账户
    pub total_deposited: u64,           // 总存入的 USDC 数量
    pub total_lp_supply: u64,           // LP Token 总供应量
    pub total_staked: u64,              // 总质押的 LP Token 数量
    pub reward_vault: Pubkey,           // 奖励金库地址
    pub bump: u8,                       // PDA bump seed
}
```

**账户大小**: 193 字节（8 + 32×5 + 8×3 + 1）

**PDA 派生**: 
```
seeds = [b"pool_state"]
```

#### 2.1.2 UserPosition (用户仓位)
**文件**: `src/state/user_position.rs`

**功能**: 记录每个用户的 LP Token 持仓和质押信息

**字段说明**:
```rust
pub struct UserPosition {
    pub owner: Pubkey,                  // 用户钱包地址
    pub pool: Pubkey,                   // 关联的池子地址
    pub lp_balance: u64,                // 持有的 LP Token（未质押）
    pub staked_amount: u64,             // 质押的 LP Token 数量
    pub reward_debt: u128,              // 奖励债务（Masterchef 算法）
    pub pending_reward: u64,            // 待领取奖励
    pub last_stake_time: i64,           // 上次质押时间
    pub last_claim_time: i64,           // 上次领取时间
    pub bump: u8,                       // PDA bump seed
}
```

**账户大小**: 129 字节（8 + 32×2 + 8×2 + 16 + 8×3 + 1）

**PDA 派生**: 
```
seeds = [b"user_position", user.key().as_ref(), pool.key().as_ref()]
```

**重要概念 - Reward Debt（奖励债务）**:

Masterchef 算法的核心概念，用于准确计算用户应得奖励：

```
用户应得奖励 = (用户质押量 × 累计每份奖励) - 奖励债务

当用户质押时：
  reward_debt = user_staked × acc_reward_per_share

当用户领取奖励时：
  pending_reward = (user_staked × acc_reward_per_share) - reward_debt
  reward_debt = user_staked × acc_reward_per_share
```

这确保了用户只能领取质押期间产生的奖励，而不是历史累积的奖励。

#### 2.1.3 RewardConfig (奖励配置)
**文件**: `src/state/reward_config.rs`

**功能**: 管理奖励分配策略和参数

**字段说明**:
```rust
pub struct RewardConfig {
    pub pool: Pubkey,                   // 关联的池子
    pub emission_type: EmissionType,    // 排放类型（固定/动态）
    pub emission_rate: u64,             // 每秒排放量（固定模式）
    pub initial_block_rate: u64,        // 初始每块排放量（动态模式）
    pub decay_factor: u64,              // 衰减因子（基点表示）
    pub blocks_per_period: u64,         // 每周期的区块数
    pub last_update_slot: u64,          // 上次更新的区块高度
    pub acc_reward_per_share: u128,     // 累计每份奖励（精度 1e12）
    pub bump: u8,                       // PDA bump seed
}
```

**账户大小**: 106 字节（8 + 32 + 1 + 8×6 + 16 + 1）

**PDA 派生**: 
```
seeds = [b"reward_config", pool_state.key().as_ref()]
```

**排放类型**:
```rust
pub enum EmissionType {
    FixedRate,      // 固定速率（每秒固定奖励）
    BlockBased,     // 按块动态（支持衰减）
}
```

---

### 2.2 指令实现 (Instructions)

#### 2.2.1 Initialize (初始化)
**文件**: `src/instructions/initialize.rs`

**功能**: 创建流动性池和奖励配置

**参数**:
```rust
pub fn initialize(
    ctx: Context<Initialize>,
    emission_type: EmissionType,     // 奖励排放类型
    emission_rate: u64,               // 每秒排放量（固定模式）
    initial_block_rate: u64,          // 初始每块排放量（动态模式）
    decay_factor: u64,                // 衰减因子（0-10000）
    blocks_per_period: u64,           // 衰减周期（区块数）
) -> Result<()>
```

**账户结构**:
```rust
#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,                    // 管理员（付费者）
    
    #[account(init, payer = authority, ...)]
    pub pool_state: Account<'info, PoolState>,       // 池子状态（新建）
    
    pub wrapped_usdc_mint: Account<'info, Mint>,     // wrappedUSDC Mint
    
    #[account(mut, mint::authority = pool_state)]
    pub lp_token_mint: Account<'info, Mint>,         // LP Token Mint
    
    #[account(mut, token::mint = wrapped_usdc_mint, token::authority = pool_state)]
    pub pool_usdc_account: Account<'info, TokenAccount>, // 池子 USDC 账户
    
    pub reward_vault: AccountInfo<'info>,            // 奖励金库（SOL）
    
    #[account(init, payer = authority, ...)]
    pub reward_config: Account<'info, RewardConfig>, // 奖励配置（新建）
    
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
}
```

**执行流程**:
1. 验证参数（衰减因子 ≤ 10000，周期 > 0）
2. 初始化池子状态账户
3. 初始化奖励配置账户
4. 记录初始区块高度
5. 发出初始化日志

**安全检查**:
- ✅ 只有管理员可以调用
- ✅ LP Token Mint authority 必须是 pool_state
- ✅ Pool USDC 账户 authority 必须是 pool_state
- ✅ 参数范围验证

---

### 2.3 工具模块 (Utils)

#### 2.3.1 RewardCalculator (奖励计算器)
**文件**: `src/utils/reward_calculator.rs`

**功能**: 实现两种奖励分配机制的计算逻辑

**核心方法**:

##### 1. calculate_pending_reward
计算用户待领取的奖励

```rust
pub fn calculate_pending_reward(
    user_staked: u64,
    reward_debt: u128,
    acc_reward_per_share: u128,
) -> Result<u64>
```

**算法**:
```
pending = (user_staked × acc_reward_per_share - reward_debt) / PRECISION
```

##### 2. update_fixed_rate_reward
更新累计每份奖励（固定速率模式）

```rust
pub fn update_fixed_rate_reward(
    acc_reward_per_share: u128,
    total_staked: u64,
    emission_rate: u64,
    time_elapsed: i64,
) -> Result<u128>
```

**算法**:
```
total_reward = emission_rate × time_elapsed
reward_per_share = (total_reward × PRECISION) / total_staked
new_acc = acc_reward_per_share + reward_per_share
```

##### 3. calculate_block_rate
计算按块动态排放的当前速率

```rust
pub fn calculate_block_rate(
    initial_rate: u64,
    decay_factor: u64,
    blocks_per_period: u64,
    current_slot: u64,
) -> Result<u64>
```

**算法**:
```
period = current_slot / blocks_per_period
rate = initial_rate × (decay_factor / 10000) ^ period
```

**示例**:
```
初始速率: 100 SOL/块
衰减因子: 9900 (99%)
周期长度: 1000 块

周期 0 (块 0-999):   rate = 100 × (0.99)^0 = 100 SOL/块
周期 1 (块 1000-1999): rate = 100 × (0.99)^1 = 99 SOL/块
周期 2 (块 2000-2999): rate = 100 × (0.99)^2 = 98.01 SOL/块
```

##### 4. update_block_based_reward
更新累计每份奖励（按块动态模式）

```rust
pub fn update_block_based_reward(
    acc_reward_per_share: u128,
    total_staked: u64,
    config: &RewardConfig,
    current_slot: u64,
) -> Result<u128>
```

**算法**:
```
blocks_elapsed = current_slot - last_update_slot
current_rate = calculate_block_rate(...)
total_reward = current_rate × blocks_elapsed
reward_per_share = (total_reward × PRECISION) / total_staked
new_acc = acc_reward_per_share + reward_per_share
```

**精度处理**:
- 所有奖励计算使用 `PRECISION = 1e12` 放大
- 中间计算使用 `u128` 防止溢出
- 最终结果缩小回 `u64`

---

### 2.4 错误定义 (Errors)

**文件**: `src/errors.rs`

```rust
#[error_code]
pub enum LpStakingError {
    InvalidAmount,              // 金额无效（≤ 0）
    InsufficientBalance,        // 余额不足
    InsufficientLpTokens,       // LP Token 不足
    InsufficientStaked,         // 质押量不足
    EmptyPool,                  // 池子为空（无法计算比例）
    MathOverflow,               // 数学运算溢出
    InvalidEmissionType,        // 无效的排放类型
    Unauthorized,               // 权限不足
    InsufficientRewardVault,    // 奖励金库余额不足
    InvalidDecayFactor,         // 衰减因子无效（> 10000）
    InvalidBlocksPerPeriod,     // 周期长度无效（≤ 0）
}
```

---

### 2.5 常量定义 (Constants)

**文件**: `src/constants.rs`

```rust
// PDA Seeds
pub const POOL_STATE_SEED: &[u8] = b"pool_state";
pub const USER_POSITION_SEED: &[u8] = b"user_position";
pub const REWARD_CONFIG_SEED: &[u8] = b"reward_config";
pub const REWARD_VAULT_SEED: &[u8] = b"reward_vault";

// 限制
pub const MIN_DEPOSIT_AMOUNT: u64 = 1_000_000;  // 1 USDC (6 decimals)
pub const MIN_STAKE_AMOUNT: u64 = 100_000;      // 0.1 LP Token

// 基点
pub const BASIS_POINTS: u64 = 10_000;            // 100% = 10000
```

---

## 3. 当前进度

### ✅ 已完成
- [x] 项目脚手架创建
- [x] 目录结构搭建
- [x] 状态账户定义（PoolState, UserPosition, RewardConfig）
- [x] 错误类型定义
- [x] 常量定义
- [x] 奖励计算器实现（含单元测试）
- [x] Initialize 指令实现
- [x] 主程序入口配置

### 🔄 进行中
- [ ] 安装 Solana CLI 工具链
- [ ] 编译和测试项目

### 📋 待完成（按优先级）
1. Deposit/Withdraw 指令实现
2. Stake/Unstake 指令实现
3. Claim 指令实现
4. Update Reward Config 指令实现
5. 集成测试编写
6. 创建测试代币（wrappedUSDC）
7. 部署脚本编写

---

## 4. 下一步计划

### 4.1 立即执行
1. **安装 Solana 工具链**
   ```bash
   sh -c "$(curl -sSfL https://release.solana.com/v1.18.0/install)"
   export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
   ```

2. **验证安装**
   ```bash
   solana --version
   anchor --version
   ```

3. **编译项目**
   ```bash
   cd /workspace/lp-staking
   anchor build
   ```

### 4.2 本周目标
- [x] 完成项目结构搭建 ✅
- [ ] 完成 Initialize 指令测试
- [ ] 实现 Deposit 和 Withdraw 指令
- [ ] 编写基础集成测试

---

## 5. 技术要点总结

### 5.1 PDA（程序派生地址）使用
本项目所有状态账户都使用 PDA，确保：
- 账户地址可预测和验证
- 程序拥有账户的签名权限
- 避免地址冲突

### 5.2 奖励计算精度
- 使用 `u128` 进行中间计算
- `PRECISION = 1e12` 放大因子
- 所有乘法先执行，除法最后执行
- 使用 `checked_*` 方法防止溢出

### 5.3 安全考虑
- 所有数学运算使用 `checked_add/mul/sub/div`
- 参数验证在指令开始时执行
- 使用 Anchor 的约束系统验证账户
- 状态更新在转账前完成（防重入）

---

**文档状态**: 进行中  
**下次更新**: 完成编译测试后更新  
**维护者**: LP Module Dev Team
