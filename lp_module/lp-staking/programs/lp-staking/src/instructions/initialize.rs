use anchor_lang::prelude::*;
use anchor_spl::token::{Mint, Token, TokenAccount};
use crate::constants::*;
use crate::errors::LpStakingError;
use crate::state::{EmissionType, PoolState, RewardConfig};

/// 初始化流动性池和质押系统
/// 
/// 此指令创建池子状态、奖励配置和相关账户
pub fn initialize_handler(
    ctx: Context<Initialize>,
    emission_type: EmissionType,
    emission_rate: u64,
    initial_block_rate: u64,
    decay_factor: u64,
    blocks_per_period: u64,
) -> Result<()> {
    // 验证参数
    if emission_type == EmissionType::BlockBased {
        require!(
            decay_factor <= BASIS_POINTS,
            LpStakingError::InvalidDecayFactor
        );
        require!(
            blocks_per_period > 0,
            LpStakingError::InvalidBlocksPerPeriod
        );
    }
    
    let pool_state = &mut ctx.accounts.pool_state;
    let reward_config = &mut ctx.accounts.reward_config;
    let clock = Clock::get()?;
    
    // 初始化池子状态
    pool_state.authority = ctx.accounts.authority.key();
    pool_state.wrapped_usdc_mint = ctx.accounts.wrapped_usdc_mint.key();
    pool_state.lp_token_mint = ctx.accounts.lp_token_mint.key();
    pool_state.pool_usdc_account = ctx.accounts.pool_usdc_account.key();
    pool_state.total_deposited = 0;
    pool_state.total_lp_supply = 0;
    pool_state.total_staked = 0;
    pool_state.reward_vault = ctx.accounts.reward_vault.key();
    pool_state.bump = ctx.bumps.pool_state;
    
    // 初始化奖励配置
    reward_config.pool = pool_state.key();
    reward_config.emission_type = emission_type;
    reward_config.emission_rate = emission_rate;
    reward_config.initial_block_rate = initial_block_rate;
    reward_config.decay_factor = decay_factor;
    reward_config.blocks_per_period = blocks_per_period;
    reward_config.last_update_slot = clock.slot;
    reward_config.acc_reward_per_share = 0;
    reward_config.bump = ctx.bumps.reward_config;
    
    msg!("Liquidity Pool initialized!");
    msg!("Pool State: {}", pool_state.key());
    msg!("LP Token Mint: {}", pool_state.lp_token_mint);
    msg!("Emission Type: {:?}", emission_type);
    
    Ok(())
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    /// 池子管理员（支付账户创建费用）
    #[account(mut)]
    pub authority: Signer<'info>,
    
    /// 池子状态账户（PDA）
    #[account(
        init,
        payer = authority,
        space = PoolState::LEN,
        seeds = [POOL_STATE_SEED],
        bump
    )]
    pub pool_state: Account<'info, PoolState>,
    
    /// wrappedUSDC Token Mint
    pub wrapped_usdc_mint: Account<'info, Mint>,
    
    /// LP Token Mint（需要提前创建并设置 mint authority 为 pool_state）
    #[account(
        mut,
        mint::authority = pool_state,
    )]
    pub lp_token_mint: Account<'info, Mint>,
    
    /// 池子持有的 USDC 账户
    #[account(
        mut,
        token::mint = wrapped_usdc_mint,
        token::authority = pool_state,
    )]
    pub pool_usdc_account: Account<'info, TokenAccount>,
    
    /// 奖励金库（存放 SOL 奖励）
    /// CHECK: 这是一个 SOL 账户，用于存放奖励
    #[account(
        mut,
        seeds = [REWARD_VAULT_SEED, pool_state.key().as_ref()],
        bump
    )]
    pub reward_vault: AccountInfo<'info>,
    
    /// 奖励配置账户（PDA）
    #[account(
        init,
        payer = authority,
        space = RewardConfig::LEN,
        seeds = [REWARD_CONFIG_SEED, pool_state.key().as_ref()],
        bump
    )]
    pub reward_config: Account<'info, RewardConfig>,
    
    /// Token 程序
    pub token_program: Program<'info, Token>,
    
    /// 系统程序
    pub system_program: Program<'info, System>,
}
