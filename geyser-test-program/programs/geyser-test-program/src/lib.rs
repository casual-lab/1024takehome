use anchor_lang::prelude::*;
use base64::{Engine as _, engine::general_purpose};

declare_id!("3hschqcggfCGdwA4iHzWa747To1DppsoX5BfKr4DgN6s");

#[program]
pub mod geyser_test_program {
    use super::*;

    /// 初始化计数器账户
    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let counter = &mut ctx.accounts.counter;
        counter.count = 0;
        counter.authority = ctx.accounts.authority.key();
        
        msg!("Counter initialized with authority: {}", counter.authority);
        msg!("Program data: AAAAAAAAAAAAAAAA"); // 模拟事件数据
        
        Ok(())
    }

    /// 增加计数器
    pub fn increment(ctx: Context<Increment>) -> Result<()> {
        let counter = &mut ctx.accounts.counter;
        counter.count += 1;
        
        msg!("Counter incremented to: {}", counter.count);
        msg!("Program log: Increment operation successful");
        msg!("Program data: {}", general_purpose::STANDARD.encode(&counter.count.to_le_bytes()));
        
        Ok(())
    }

    /// 复杂操作 - 触发多个日志
    pub fn complex_operation(ctx: Context<ComplexOperation>, amount: u64) -> Result<()> {
        let counter = &mut ctx.accounts.counter;
        
        msg!("Starting complex operation");
        msg!("Program log: Processing amount: {}", amount);
        
        // 模拟多层调用
        for i in 0..3 {
            msg!("Program log: Iteration {} processing", i);
        }
        
        counter.count += amount;
        
        // 模拟事件发出
        let event_data = format!("{{\"type\":\"ComplexOp\",\"amount\":{},\"new_count\":{}}}", amount, counter.count);
        msg!("Program data: {}", general_purpose::STANDARD.encode(event_data.as_bytes()));
        
        msg!("Complex operation completed");
        
        Ok(())
    }

    /// 转账操作 - 测试账户更新
    pub fn transfer_sol(ctx: Context<TransferSol>, amount: u64) -> Result<()> {
        let from = &mut ctx.accounts.from;
        let to = &mut ctx.accounts.to;
        
        msg!("Transferring {} lamports", amount);
        
        **from.to_account_info().try_borrow_mut_lamports()? -= amount;
        **to.to_account_info().try_borrow_mut_lamports()? += amount;
        
        msg!("Program log: Transfer successful");
        msg!("Program data: {}", general_purpose::STANDARD.encode(&amount.to_le_bytes()));
        
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init,
        payer = authority,
        space = 8 + 8 + 32,
    )]
    pub counter: Account<'info, Counter>,
    #[account(mut)]
    pub authority: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Increment<'info> {
    #[account(mut)]
    pub counter: Account<'info, Counter>,
    pub authority: Signer<'info>,
}

#[derive(Accounts)]
pub struct ComplexOperation<'info> {
    #[account(mut, has_one = authority)]
    pub counter: Account<'info, Counter>,
    pub authority: Signer<'info>,
}

#[derive(Accounts)]
pub struct TransferSol<'info> {
    #[account(mut)]
    pub from: Signer<'info>,
    #[account(mut)]
    /// CHECK: This is safe because we're just transferring lamports
    pub to: AccountInfo<'info>,
}

#[account]
pub struct Counter {
    pub count: u64,
    pub authority: Pubkey,
}
