use anchor_lang::prelude::*;
use anchor_lang::system_program::System;
use crate::constants::*;
use crate::errors::LpStakingError;
use crate::state::{PoolState, UserPosition, RewardConfig};
use crate::utils::reward_calculator;

/// 领取质押奖励（SOL）
pub fn claim_handler(ctx: Context<Claim>) -> Result<()> {
    let user_position = &mut ctx.accounts.user_position;
    let pool_state = &ctx.accounts.pool_state;
    let reward_config = &mut ctx.accounts.reward_config;
    let clock = Clock::get()?;
    
    // 1. 更新奖励池状态
    reward_calculator::update_pool_reward(
        &pool_state,
        reward_config,
        clock.slot,
    )?;
    
    // 2. 计算当前质押的待领取奖励
    let pending_from_staked = if user_position.staked_amount > 0 {
        reward_calculator::calculate_pending_reward(
            user_position.staked_amount,
            reward_config.acc_reward_per_share,
            user_position.reward_debt,
        )?
    } else {
        0
    };
    
    // 3. 计算总待领取奖励（历史累积 + 当前质押）
    let total_pending = user_position.pending_reward
        .checked_add(pending_from_staked)
        .ok_or(LpStakingError::MathOverflow)?;
    
    require!(total_pending > 0, LpStakingError::NoRewardToClaim);
    
    // 4. 检查奖励金库余额
    let reward_vault_balance = ctx.accounts.reward_vault.lamports();
    require!(
        reward_vault_balance >= total_pending,
        LpStakingError::InsufficientRewardVault
    );
    
    // 5. 从奖励金库转账 SOL 给用户
    // 使用 PDA seeds 签名从 reward_vault 转账到用户
    let pool_state_key = ctx.accounts.pool_state.key();
    let seeds = &[
        REWARD_VAULT_SEED,
        pool_state_key.as_ref(),
        &[ctx.bumps.reward_vault],
    ];
    let signer_seeds = &[&seeds[..]];
    
    let transfer_ix = anchor_lang::solana_program::system_instruction::transfer(
        &ctx.accounts.reward_vault.key(),
        &ctx.accounts.user.key(),
        total_pending,
    );
    
    anchor_lang::solana_program::program::invoke_signed(
        &transfer_ix,
        &[
            ctx.accounts.reward_vault.to_account_info(),
            ctx.accounts.user.to_account_info(),
            ctx.accounts.system_program.to_account_info(),
        ],
        signer_seeds,
    )?;
    
    // 6. 清零待领取奖励
    user_position.pending_reward = 0;
    
    // 7. 更新 reward_debt（如果还有质押）
    if user_position.staked_amount > 0 {
        user_position.reward_debt = (user_position.staked_amount as u128)
            .checked_mul(reward_config.acc_reward_per_share)
            .ok_or(LpStakingError::MathOverflow)?;
    }
    
    // 8. 更新领取时间
    user_position.last_claim_time = clock.unix_timestamp;
    
    msg!("Claim successful!");
    msg!("User: {}", ctx.accounts.user.key());
    msg!("Reward claimed: {} lamports", total_pending);
    msg!("Reward vault remaining: {} lamports", reward_vault_balance - total_pending);
    
    Ok(())
}

#[derive(Accounts)]
pub struct Claim<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    
    #[account(
        seeds = [POOL_STATE_SEED],
        bump = pool_state.bump,
    )]
    pub pool_state: Account<'info, PoolState>,
    
    #[account(
        mut,
        seeds = [
            USER_POSITION_SEED,
            user.key().as_ref(),
            pool_state.key().as_ref()
        ],
        bump = user_position.bump,
        constraint = user_position.owner == user.key() @ LpStakingError::Unauthorized,
    )]
    pub user_position: Account<'info, UserPosition>,
    
    #[account(
        mut,
        seeds = [REWARD_CONFIG_SEED, pool_state.key().as_ref()],
        bump = reward_config.bump,
    )]
    pub reward_config: Account<'info, RewardConfig>,
    
    /// 奖励金库（PDA，存放 SOL 奖励）
    /// CHECK: 这是一个 PDA，用于存放奖励 SOL
    #[account(
        mut,
        seeds = [REWARD_VAULT_SEED, pool_state.key().as_ref()],
        bump,
    )]
    pub reward_vault: AccountInfo<'info>,
    
    pub system_program: Program<'info, System>,
}
