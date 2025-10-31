use anchor_lang::prelude::*;

declare_id!("AoQuXAg7gK5KHkeuhbLpJ5AtnziNb5M9FqjLNUaVudTx");

pub mod constants;
pub mod errors;
pub mod instructions;
pub mod state;
pub mod utils;

use instructions::*;
use state::EmissionType;

#[program]
pub mod lp_staking {
    use super::*;

    /// 初始化流动性池和质押系统
    pub fn initialize(
        ctx: Context<Initialize>,
        emission_type: EmissionType,
        emission_rate: u64,
        initial_block_rate: u64,
        decay_factor: u64,
        blocks_per_period: u64,
    ) -> Result<()> {
        instructions::initialize::initialize_handler(
            ctx,
            emission_type,
            emission_rate,
            initial_block_rate,
            decay_factor,
            blocks_per_period,
        )
    }
    
    /// 存入 wrappedUSDC，获得 LP Token
    pub fn deposit(ctx: Context<Deposit>, amount: u64) -> Result<()> {
        instructions::deposit::deposit_handler(ctx, amount)
    }

    /// 赎回 LP Token，提取 wrappedUSDC
    pub fn withdraw(ctx: Context<Withdraw>, lp_amount: u64) -> Result<()> {
        instructions::withdraw::withdraw_handler(ctx, lp_amount)
    }
    
    /// 质押 LP Token，开始赚取奖励
    pub fn stake(ctx: Context<Stake>, amount: u64) -> Result<()> {
        instructions::stake::stake_handler(ctx, amount)
    }
    
    /// 解除质押，取回 LP Token
    pub fn unstake(ctx: Context<Unstake>, amount: u64) -> Result<()> {
        instructions::unstake::unstake_handler(ctx, amount)
    }
    
    /// 领取质押奖励
    pub fn claim(ctx: Context<Claim>) -> Result<()> {
        instructions::claim::claim_handler(ctx)
    }
}
