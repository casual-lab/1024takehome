use anchor_lang::prelude::*;

/// 用户仓位账户
/// 记录用户的 LP Token 持仓和质押信息
#[account]
pub struct UserPosition {
    /// 用户钱包地址
    pub owner: Pubkey,
    
    /// 关联的池子地址
    pub pool: Pubkey,
    
    /// 持有的 LP Token 数量（未质押）
    pub lp_balance: u64,
    
    /// 质押的 LP Token 数量
    pub staked_amount: u64,
    
    /// 奖励债务（用于 Masterchef 算法）
    /// reward_debt = user_staked * acc_reward_per_share
    pub reward_debt: u128,
    
    /// 待领取奖励
    pub pending_reward: u64,
    
    /// 上次质押时间（Unix 时间戳）
    pub last_stake_time: i64,
    
    /// 上次领取奖励时间（Unix 时间戳）
    pub last_claim_time: i64,
    
    /// PDA bump
    pub bump: u8,
}

impl UserPosition {
    /// 计算账户大小
    pub const LEN: usize = 8 + // discriminator
        32 + // owner
        32 + // pool
        8 +  // lp_balance
        8 +  // staked_amount
        16 + // reward_debt (u128)
        8 +  // pending_reward
        8 +  // last_stake_time
        8 +  // last_claim_time
        1;   // bump
}
