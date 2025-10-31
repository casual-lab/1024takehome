use anchor_lang::prelude::*;

#[error_code]
pub enum LpStakingError {
    #[msg("Invalid amount: must be greater than zero")]
    InvalidAmount,
    
    #[msg("Insufficient balance")]
    InsufficientBalance,
    
    #[msg("Insufficient LP tokens")]
    InsufficientLpTokens,
    
    #[msg("Insufficient staked amount")]
    InsufficientStaked,
    
    #[msg("Pool is empty, cannot calculate LP ratio")]
    EmptyPool,
    
    #[msg("Math overflow occurred")]
    MathOverflow,
    
    #[msg("Invalid emission type")]
    InvalidEmissionType,
    
    #[msg("Unauthorized: only pool authority can perform this action")]
    Unauthorized,
    
    #[msg("Reward vault has insufficient balance")]
    InsufficientRewardVault,
    
    #[msg("Invalid decay factor: must be <= 10000")]
    InvalidDecayFactor,
    
    #[msg("Invalid blocks per period (must be > 0)")]
    InvalidBlocksPerPeriod,
    
    #[msg("No reward to claim")]
    NoRewardToClaim,
}
