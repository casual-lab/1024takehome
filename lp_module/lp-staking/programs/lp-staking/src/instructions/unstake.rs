use anchor_lang::prelude::*;
use crate::constants::*;
use crate::errors::LpStakingError;
use crate::state::{PoolState, UserPosition, RewardConfig};
use crate::utils::reward_calculator;

/// 解除质押，取回 LP Token
pub fn unstake_handler(ctx: Context<Unstake>, amount: u64) -> Result<()> {
    // 参数验证
    require!(amount > 0, LpStakingError::InvalidAmount);
    
    let user_position = &mut ctx.accounts.user_position;
    let pool_state = &mut ctx.accounts.pool_state;
    let reward_config = &mut ctx.accounts.reward_config;
    let clock = Clock::get()?;
    
    // 检查用户质押余额是否充足
    require!(
        user_position.staked_amount >= amount,
        LpStakingError::InsufficientStaked
    );
    
    // 1. 更新奖励池状态
    reward_calculator::update_pool_reward(
        pool_state,
        reward_config,
        clock.slot,
    )?;
    
    // 2. 结算待领取奖励
    let pending = reward_calculator::calculate_pending_reward(
        user_position.staked_amount,
        reward_config.acc_reward_per_share,
        user_position.reward_debt,
    )?;
    
    user_position.pending_reward = user_position.pending_reward
        .checked_add(pending)
        .ok_or(LpStakingError::MathOverflow)?;
    
    // 3. 更新用户质押数量
    user_position.staked_amount = user_position.staked_amount
        .checked_sub(amount)
        .ok_or(LpStakingError::MathOverflow)?;
    
    user_position.lp_balance = user_position.lp_balance
        .checked_add(amount)
        .ok_or(LpStakingError::MathOverflow)?;
    
    // 4. 更新池子总质押量
    pool_state.total_staked = pool_state.total_staked
        .checked_sub(amount)
        .ok_or(LpStakingError::MathOverflow)?;
    
    // 5. 更新 reward_debt（基于新的质押量）
    user_position.reward_debt = (user_position.staked_amount as u128)
        .checked_mul(reward_config.acc_reward_per_share)
        .ok_or(LpStakingError::MathOverflow)?;
    
    msg!("Unstake successful!");
    msg!("User: {}", ctx.accounts.user.key());
    msg!("Unstaked LP amount: {}", amount);
    msg!("Remaining staked: {}", user_position.staked_amount);
    msg!("Pending reward: {}", user_position.pending_reward);
    
    Ok(())
}

#[derive(Accounts)]
pub struct Unstake<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    
    #[account(
        mut,
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
}
