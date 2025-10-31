use anchor_lang::prelude::*;

/// 奖励排放类型
#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq, Debug)]
pub enum EmissionType {
    /// 固定速率排放（每秒固定数量）
    FixedRate,
    /// 按块动态排放（支持衰减）
    BlockBased,
}

/// 奖励配置账户
/// 管理奖励分配策略和参数
#[account]
pub struct RewardConfig {
    /// 关联的池子地址
    pub pool: Pubkey,
    
    /// 排放类型
    pub emission_type: EmissionType,
    
    /// 固定排放速率（每秒排放的 lamports）
    /// 仅在 FixedRate 模式下使用
    pub emission_rate: u64,
    
    /// 初始每块排放量（lamports）
    /// 仅在 BlockBased 模式下使用
    pub initial_block_rate: u64,
    
    /// 衰减因子（基点表示，10000 = 1.0 = 不衰减）
    /// 例如：9900 表示每周期衰减到 99%
    /// 仅在 BlockBased 模式下使用
    pub decay_factor: u64,
    
    /// 每个衰减周期的区块数
    /// 仅在 BlockBased 模式下使用
    pub blocks_per_period: u64,
    
    /// 上次更新的 slot（区块高度）
    pub last_update_slot: u64,
    
    /// 累计每份奖励（精度放大 1e12）
    /// acc_reward_per_share += (reward * 1e12) / total_staked
    pub acc_reward_per_share: u128,
    
    /// PDA bump
    pub bump: u8,
}

impl RewardConfig {
    /// 计算账户大小
    pub const LEN: usize = 8 + // discriminator
        32 + // pool
        1 +  // emission_type
        8 +  // emission_rate
        8 +  // initial_block_rate
        8 +  // decay_factor
        8 +  // blocks_per_period
        8 +  // last_update_slot
        16 + // acc_reward_per_share (u128)
        1;   // bump
    
    /// 精度因子（1e12）
    pub const PRECISION: u128 = 1_000_000_000_000;
}
