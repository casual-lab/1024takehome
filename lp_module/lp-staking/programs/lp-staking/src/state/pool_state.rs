use anchor_lang::prelude::*;

/// 流动性池状态账户
/// 存储池子的核心信息和配置
#[account]
pub struct PoolState {
    /// 管理员权限
    pub authority: Pubkey,
    
    /// wrappedUSDC Token Mint 地址
    pub wrapped_usdc_mint: Pubkey,
    
    /// LP Token Mint 地址
    pub lp_token_mint: Pubkey,
    
    /// 池子持有的 USDC 账户
    pub pool_usdc_account: Pubkey,
    
    /// 总存入量（wrappedUSDC）
    pub total_deposited: u64,
    
    /// LP Token 总供应量
    pub total_lp_supply: u64,
    
    /// 总质押的 LP Token 数量
    pub total_staked: u64,
    
    /// 奖励金库账户（存放 SOL 奖励）
    pub reward_vault: Pubkey,
    
    /// PDA bump
    pub bump: u8,
}

impl PoolState {
    /// 计算账户大小
    pub const LEN: usize = 8 + // discriminator
        32 + // authority
        32 + // wrapped_usdc_mint
        32 + // lp_token_mint
        32 + // pool_usdc_account
        8 +  // total_deposited
        8 +  // total_lp_supply
        8 +  // total_staked
        32 + // reward_vault
        1;   // bump
}
