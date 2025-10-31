use anchor_lang::prelude::*;
use anchor_spl::token::{self, Burn, Mint, Token, TokenAccount, Transfer};
use crate::constants::*;
use crate::errors::LpStakingError;
use crate::state::{PoolState, UserPosition};

/// 赎回 LP Token，提取 wrappedUSDC
pub fn withdraw_handler(ctx: Context<Withdraw>, lp_amount: u64) -> Result<()> {
    // 参数验证
    require!(lp_amount > 0, LpStakingError::InvalidAmount);
    
    let pool_state = &mut ctx.accounts.pool_state;
    let user_position = &mut ctx.accounts.user_position;
    
    // 检查用户 LP Token 余额
    require!(
        user_position.lp_balance >= lp_amount,
        LpStakingError::InsufficientLpTokens
    );
    
    // 检查池子余额充足
    require!(
        pool_state.total_lp_supply >= lp_amount,
        LpStakingError::EmptyPool
    );
    
    // 计算应该返还的 USDC 数量
    let usdc_amount = calculate_withdraw_amount(
        lp_amount,
        pool_state.total_deposited,
        pool_state.total_lp_supply,
    )?;
    
    // 检查池子 USDC 余额是否充足
    require!(
        pool_state.total_deposited >= usdc_amount,
        LpStakingError::InsufficientBalance
    );
    
    // 1. 销毁用户的 LP Token
    let burn_ctx = CpiContext::new(
        ctx.accounts.token_program.to_account_info(),
        Burn {
            mint: ctx.accounts.lp_token_mint.to_account_info(),
            from: ctx.accounts.user_lp_account.to_account_info(),
            authority: ctx.accounts.user.to_account_info(),
        },
    );
    token::burn(burn_ctx, lp_amount)?;
    
    // 2. 从池子转账 USDC 给用户
    let seeds = &[
        POOL_STATE_SEED,
        &[pool_state.bump],
    ];
    let signer = &[&seeds[..]];
    
    let transfer_ctx = CpiContext::new_with_signer(
        ctx.accounts.token_program.to_account_info(),
        Transfer {
            from: ctx.accounts.pool_usdc_account.to_account_info(),
            to: ctx.accounts.user_usdc_account.to_account_info(),
            authority: pool_state.to_account_info(),
        },
        signer,
    );
    token::transfer(transfer_ctx, usdc_amount)?;
    
    // 3. 更新池子状态
    pool_state.total_deposited = pool_state.total_deposited
        .checked_sub(usdc_amount)
        .ok_or(LpStakingError::MathOverflow)?;
    pool_state.total_lp_supply = pool_state.total_lp_supply
        .checked_sub(lp_amount)
        .ok_or(LpStakingError::MathOverflow)?;
    
    // 4. 更新用户仓位
    user_position.lp_balance = user_position.lp_balance
        .checked_sub(lp_amount)
        .ok_or(LpStakingError::MathOverflow)?;
    
    msg!("Withdraw successful!");
    msg!("User: {}", ctx.accounts.user.key());
    msg!("Burned LP Token: {}", lp_amount);
    msg!("Withdrawn USDC: {}", usdc_amount);
    
    Ok(())
}

/// 计算应该返还的 USDC 数量
fn calculate_withdraw_amount(
    lp_amount: u64,
    total_deposited: u64,
    total_lp_supply: u64,
) -> Result<u64> {
    require!(total_lp_supply > 0, LpStakingError::EmptyPool);
    
    let withdraw_amount = (lp_amount as u128)
        .checked_mul(total_deposited as u128)
        .ok_or(LpStakingError::MathOverflow)?
        .checked_div(total_lp_supply as u128)
        .ok_or(LpStakingError::MathOverflow)?;
    
    Ok(withdraw_amount as u64)
}

#[derive(Accounts)]
pub struct Withdraw<'info> {
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
        token::mint = pool_state.wrapped_usdc_mint,
        token::authority = user,
    )]
    pub user_usdc_account: Account<'info, TokenAccount>,
    
    #[account(
        mut,
        address = pool_state.pool_usdc_account,
    )]
    pub pool_usdc_account: Account<'info, TokenAccount>,
    
    #[account(
        mut,
        address = pool_state.lp_token_mint,
    )]
    pub lp_token_mint: Account<'info, Mint>,
    
    #[account(
        mut,
        token::mint = lp_token_mint,
        token::authority = user,
    )]
    pub user_lp_account: Account<'info, TokenAccount>,
    
    pub token_program: Program<'info, Token>,
}
