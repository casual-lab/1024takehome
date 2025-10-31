use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer, MintTo};
use crate::constants::*;
use crate::errors::LpStakingError;
use crate::state::{PoolState, UserPosition};

/// 存入 wrappedUSDC，获得 LP Token
pub fn deposit_handler(ctx: Context<Deposit>, amount: u64) -> Result<()> {
    // 初始化用户仓位（如果是首次）
    let user_position = &mut ctx.accounts.user_position;
    
    // 只在首次创建时初始化
    if user_position.owner == Pubkey::default() {
        user_position.owner = ctx.accounts.user.key();
        user_position.pool = ctx.accounts.pool_state.key();
        user_position.lp_balance = 0;
        user_position.staked_amount = 0;
        user_position.reward_debt = 0;
        user_position.pending_reward = 0;
        user_position.last_stake_time = 0;
        user_position.last_claim_time = 0;
        user_position.bump = ctx.bumps.user_position;
    }
    
    // 参数验证
    require!(amount >= MIN_DEPOSIT_AMOUNT, LpStakingError::InvalidAmount);
    
    let pool_state = &mut ctx.accounts.pool_state;
    
    // 计算应该铸造的 LP Token 数量
    let lp_amount = calculate_lp_amount(
        amount,
        pool_state.total_deposited,
        pool_state.total_lp_supply,
    )?;
    
    // 1. 将用户的 wrappedUSDC 转入池子账户
    let transfer_ctx = CpiContext::new(
        ctx.accounts.token_program.to_account_info(),
        Transfer {
            from: ctx.accounts.user_usdc_account.to_account_info(),
            to: ctx.accounts.pool_usdc_account.to_account_info(),
            authority: ctx.accounts.user.to_account_info(),
        },
    );
    token::transfer(transfer_ctx, amount)?;
    
    // 2. 铸造 LP Token 给用户
    let seeds = &[
        POOL_STATE_SEED,
        &[pool_state.bump],
    ];
    let signer = &[&seeds[..]];
    
    let mint_ctx = CpiContext::new_with_signer(
        ctx.accounts.token_program.to_account_info(),
        MintTo {
            mint: ctx.accounts.lp_token_mint.to_account_info(),
            to: ctx.accounts.user_lp_account.to_account_info(),
            authority: pool_state.to_account_info(),
        },
        signer,
    );
    token::mint_to(mint_ctx, lp_amount)?;
    
    // 3. 更新池子状态
    pool_state.total_deposited = pool_state.total_deposited
        .checked_add(amount)
        .ok_or(LpStakingError::MathOverflow)?;
    pool_state.total_lp_supply = pool_state.total_lp_supply
        .checked_add(lp_amount)
        .ok_or(LpStakingError::MathOverflow)?;
    
    // 4. 更新用户仓位
    user_position.lp_balance = user_position.lp_balance
        .checked_add(lp_amount)
        .ok_or(LpStakingError::MathOverflow)?;
    
    msg!("Deposit successful!");
    msg!("User: {}", ctx.accounts.user.key());
    msg!("Deposited USDC: {}", amount);
    msg!("Minted LP Token: {}", lp_amount);
    
    Ok(())
}

/// 计算应该铸造的 LP Token 数量
fn calculate_lp_amount(
    deposit_amount: u64,
    total_deposited: u64,
    total_lp_supply: u64,
) -> Result<u64> {
    if total_deposited == 0 || total_lp_supply == 0 {
        // 首次存入，1:1 比例
        Ok(deposit_amount)
    } else {
        // 后续存入，按比例计算
        let lp_amount = (deposit_amount as u128)
            .checked_mul(total_lp_supply as u128)
            .ok_or(LpStakingError::MathOverflow)?
            .checked_div(total_deposited as u128)
            .ok_or(LpStakingError::EmptyPool)?;
        
        Ok(lp_amount as u64)
    }
}

#[derive(Accounts)]
pub struct Deposit<'info> {
    #[account(mut)]
    pub user: Signer<'info>,
    
    #[account(
        mut,
        seeds = [POOL_STATE_SEED],
        bump = pool_state.bump,
    )]
    pub pool_state: Account<'info, PoolState>,
    
    #[account(
        init_if_needed,
        payer = user,
        space = UserPosition::LEN,
        seeds = [
            USER_POSITION_SEED,
            user.key().as_ref(),
            pool_state.key().as_ref()
        ],
        bump
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
    
    pub system_program: Program<'info, System>,
}
